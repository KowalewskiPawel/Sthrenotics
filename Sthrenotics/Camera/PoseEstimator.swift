//
//  PoseEstimator.swift
//  FormForgeV2
//
//  Created by Pawel Kowalewski on 09/05/2025.
//

import Foundation
import AVFoundation
import Combine
import CoreGraphics
import SwiftUI
import Vision // Still needed for some types during transition

class PoseEstimator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, ObservableObject {
    // Published properties for body joints
    @Published var bodyParts = [HumanBodyPoseObservation.PoseJointName: Joint]()
    @Published var currentFrameImage: CGImage?
    
    // Form feedback properties - generic for all exercise types
    @Published var isGoodPosture = true // Overall posture, based on body straightness
    @Published var WristisGoodPosture = true // Alignment of wrists
    @Published var ElbowisGoodPosture = true // Alignment of elbows
    @Published var ShoulderisGoodPosture = true // Alignment of shoulders
    @Published var HipisGoodPosture = true // Alignment of hips
    @Published var KneeisGoodPosture = true // Alignment of knees
    @Published var AnkleisGoodPosture = true // Alignment of ankles
    @Published var CoreisGoodPosture = true // Straightness of the body (shoulder-hip-ankle)

    // Frame stability and buffering system - useful for all exercise types
    private var lastValidBodyParts: [HumanBodyPoseObservation.PoseJointName: Joint] = [:]
    private var noBodyDetectionStartTime: Date? = nil
    private let bodyDetectionTimeoutThreshold: TimeInterval = 2.0 // 2 seconds threshold
    
    // Frame processing properties
    var frameCounter: Int = 0 // Counts total processed frames
    private var isAnalyzingFrame: Bool = false // Flag to prevent multiple analysis tasks concurrently
    private var currentTask: Task<Void, Never>? = nil // The current asynchronous analysis task
    
    // Averaging arrays for stable measurements
    private var xShouldersDiffs: [Float] = [] // Difference in x-coordinates of shoulders
    private var yShouldersDiffs: [Float] = [] // Difference in y-coordinates of shoulders
    let maxFrameCount = 10 // Increased for smoother averaging
    
    // Thresholds for posture analysis (normalized differences)
    private var shouldersXThreshold: Float = 0.05
    private var shouldersYThreshold: Float = 0.02

    // Multipliers for sensitivity adjustment (can be adjusted via UI)
    private var shouldersXMultiplier: Float = 1.0
    private var shouldersYMultiplier: Float = 1.0
    private var toleranceMultiplier: Float = 0.0 {
        didSet {
            updateMultipliers()
        }
    }

    // MARK: - Debug Controls
    // Set these flags to control which debug info is printed
    struct DebugFlags {
        static var printJointConfidences = false
        static var printShoulderPositions = false
        static var printElbowAngles = false
        static var printBodyAngles = false
        static var printErrors = true // Keep errors visible by default
        static var enableVisionDetection = true // Set to true to see Vision detection success/failure
    }
    
    // Categories for debug messages
    enum DebugCategory {
        case jointConfidences
        case shoulderPositions
        case elbowAngles
        case bodyAngles
        case pushUpDetection
        case kneeDetection
        case errors
        case visionDetection
    }
    
    var subscriptions = Set<AnyCancellable>() // For Combine subscriptions

    override init() {
        super.init()

        // Set up observations for body parts - keep this generic for the base class
        $bodyParts
            .dropFirst() // Ignore the initial empty value
            .sink { [weak self] bodyParts in
                guard let self = self else { return }
                // Analyze posture for general errors
                self.analyzePoseForErrors()
                // Subclasses will add their own observations for specific exercises
            }
            .store(in: &subscriptions)
    }

    // Update sensitivity multipliers based on tolerance setting
    func updateMultipliers() {
        // Adjust multipliers based on the toleranceMultiplier
        shouldersXMultiplier = 1.0 + toleranceMultiplier * 0.5
        shouldersYMultiplier = 1.0 + toleranceMultiplier * 0.5
    }

    // MARK: - Camera Frame Processing
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        self.frameCounter += 1

        // Add a print on every 30th frame to track capture activity without flooding the console
        if frameCounter % 30 == 0 {
            print("CAPTURE OUTPUT FRAME #\(frameCounter)")
        }

        // Process every Nth frame for performance (e.g., every 3rd frame)
        if frameCounter % 3 == 0 && !self.isAnalyzingFrame {
            print("PROCESSING FRAME #\(frameCounter)")
            self.isAnalyzingFrame = true // Mark that a frame is being analyzed
            self.currentTask?.cancel() // Cancel any previous analysis task

            // Create a new asynchronous task for frame analysis
            self.currentTask = Task { [weak self] in
                guard let self = self else { return }

                // Perform the frame analysis (pose detection and feature extraction)
                await self.analyzeFrame(frame: sampleBuffer)

                // Check if the task was cancelled while analyzing
                if Task.isCancelled {
                    print("TASK CANCELLED")
                    return // Exit the task if cancelled
                }

                self.isAnalyzingFrame = false // Mark analysis as complete
                self.currentTask = nil // Clear the current task reference
            }
        } else {
            // If the frame is not processed, invalidate the buffer to avoid memory leaks
            CMSampleBufferInvalidate(sampleBuffer)
        }
    }

    // Analyze a single frame for pose information using Vision
    func analyzeFrame(frame: CMSampleBuffer) async {
        // Add a print statement at the very beginning
        print("FRAME ANALYSIS STARTED")
        
        // Check for task cancellation early
        if Task.isCancelled {
            CMSampleBufferInvalidate(frame)
            print("PoseEstimator: analyzeFrame task cancelled.") // Log cancellation
            return
        }

        // Get pixel buffer from sample buffer
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(frame) else {
            CMSampleBufferInvalidate(frame)
            print("PoseEstimator: Could not get CVPixelBuffer from sample buffer.") // Log failure to get pixel buffer
            return
        }
        
        print("PIXEL BUFFER OBTAINED")
        
        // Invalidate the original buffer early to release memory
        CMSampleBufferInvalidate(frame)
        
        // Get CGImage from pixel buffer for display on the UI
        if let cgImage = CIImage(cvPixelBuffer: pixelBuffer).cgImage {
            await MainActor.run {
                self.currentFrameImage = cgImage // Update the published image on the main thread
            }

            // Notify observers of a new frame image (e.g., for drawing overlays in SwiftUI)
            NotificationCenter.default.post(
                name: .newCameraFrame,
                object: cgImage
            )
            print("FRAME IMAGE POSTED")
        } else {
            print("PoseEstimator: Could not create CGImage from CVPixelBuffer.") // Log CGImage creation failure
        }

        do {
            // Create a new human body pose detection request
            var humanBodyPoseRequest = DetectHumanBodyPoseRequest()
            
            // Disable hand detection to improve performance
            humanBodyPoseRequest.detectsHands = false
            
            // Add a clear print statement that will always show up regardless of debug flags
            print("STARTING VISION REQUEST")
            
            // Perform the Vision request asynchronously on the pixel buffer
            let results = try await humanBodyPoseRequest.perform(on: pixelBuffer)
            
            // Add a clear print statement that will always show up regardless of debug flags
            print("VISION REQUEST COMPLETED")

            // Check for task cancellation after the Vision request
            if Task.isCancelled {
                print("PoseEstimator: analyzeFrame task cancelled after Vision request.")
                return // Exit if the task was cancelled
            }

            // Log observation results - make this always print
            if let observation = results.first {
                print("OBS: ", observation)
                self.debugPrint("PoseEstimator: Human body pose observation detected with confidence: \(observation.confidence)", category: .visionDetection)
            } else {
                print("NO BODY DETECTED IN FRAME")
                self.debugPrint("PoseEstimator: No human body pose observation detected by Vision.", category: .visionDetection)
            }

            // Get joints from observation if available
            let joints = results.first?.allJoints() ?? [:]
            
            // Always update the published body parts on the main thread
            await MainActor.run {
                // Body detection stabilization
                if joints.isEmpty {
                    // Start tracking time when body detection is lost
                    if noBodyDetectionStartTime == nil {
                        noBodyDetectionStartTime = Date()
                    }
                    
                    // Only update UI if body has been missing for threshold duration
                    let currentTime = Date()
                    if let startTime = noBodyDetectionStartTime,
                       currentTime.timeIntervalSince(startTime) >= bodyDetectionTimeoutThreshold {
                        // After 2 seconds of no detection, notify subclasses
                        self.handleBodyDetectionLost()
                    } else {
                        // Continue using the last valid body parts during brief detection gaps
                        if !self.lastValidBodyParts.isEmpty {
                            self.bodyParts = self.lastValidBodyParts
                        }
                    }
                } else {
                    // Reset the timer when body is detected
                    noBodyDetectionStartTime = nil
                    
                    // Update with current joints and store as last valid
                    self.bodyParts = joints
                    self.lastValidBodyParts = joints
                    
                    // Notify subclasses that we have fresh body parts
                    self.handleBodyDetectionUpdated()
                }
            }
            
            // Always extract pose information even with empty joints
            await extractPoseInformation(joints: joints)

        } catch {
            // Handle errors during frame analysis
            print("PoseEstimator: Error analyzing frame: \(error)") // Log the error
            
            // Update UI with error state but continue processing
            await MainActor.run {
                // Notify subclasses about the error
                self.handlePoseDetectionError(error)
            }
            
            // Continue processing with existing data
            await extractPoseInformation(joints: self.bodyParts)
        }
    }
    
    // Called when body detection is lost for more than the threshold time
    // Subclasses can override this
    func handleBodyDetectionLost() {
        // Base implementation does nothing - subclasses will override
    }
    
    // Called when body detection is updated with new joints
    // Subclasses can override this
    func handleBodyDetectionUpdated() {
        // Base implementation does nothing - subclasses will override
    }
    
    // Called when pose detection encounters an error
    // Subclasses can override this
    func handlePoseDetectionError(_ error: Error) {
        // Base implementation does nothing - subclasses will override
    }

    // Extract position information from joints and update posture properties
    func extractPoseInformation(joints: [HumanBodyPoseObservation.PoseJointName: Joint]) async {
        // Helper function to extract points with a basic confidence check for raw data
        func extractPoint(_ joint: Joint?, index: String?) -> CGFloat {
            guard let joint = joint else { return CGFloat(0.0) }
            // Use any joint with non-zero confidence
            if joint.confidence <= 0.2 {
                return CGFloat(0.0)
            }
            if (index == "x") {
                return joint.location.x
            }
            if (index == "y") {
                return joint.location.y
            }
            return CGFloat(0.0)
        }

        // Extract key points - always attempt extraction regardless of confidence
        let leftShoulderX = extractPoint(joints[.leftShoulder], index: "x")
        let rightShoulderX = extractPoint(joints[.rightShoulder], index: "x")
        let leftShoulderY = extractPoint(joints[.leftShoulder], index: "y")
        let rightShoulderY = extractPoint(joints[.rightShoulder], index: "y")
        
        // Log extracted shoulder points for debugging
        self.debugPrint("Extracted Shoulder Points - LS:(\(leftShoulderX), \(leftShoulderY)), RS:(\(rightShoulderX), \(rightShoulderY))", category: .shoulderPositions)

        // Calculate differences without requiring both points to be valid
        // Just use what we have - if one point is missing, we'll still calculate and use zero
        var xShouldersDiff: Float = 0
        var yShouldersDiff: Float = 0

        // Use any non-zero values we can get
        xShouldersDiff = Float(abs(leftShoulderX - rightShoulderX))
        yShouldersDiff = Float(abs(leftShoulderY - rightShoulderY))

        // Update moving averages on the main thread
        await MainActor.run {
            // Shoulders X diff
            self.xShouldersDiffs.append(xShouldersDiff)
            if self.xShouldersDiffs.count > self.maxFrameCount {
                self.xShouldersDiffs.removeFirst()
            }

            // Shoulders Y diff
            self.yShouldersDiffs.append(yShouldersDiff)
            if self.yShouldersDiffs.count > self.maxFrameCount {
                self.yShouldersDiffs.removeFirst()
            }
        }
    }

    // Analyze pose for general form errors - simplified for base class
    // Subclasses can override for exercise-specific form analysis
    func analyzePoseForErrors() {
        // Basic joint detection check - checks if we have at least one complete arm
        let rightShoulder = bodyParts[.rightShoulder]
        let rightElbow = bodyParts[.rightElbow]
        let rightWrist = bodyParts[.rightWrist]
        let leftShoulder = bodyParts[.leftShoulder]
        let leftElbow = bodyParts[.leftElbow]
        let leftWrist = bodyParts[.leftWrist]
        
        // Check if we have at least one complete arm
        let haveRightArm = rightShoulder != nil && rightElbow != nil && rightWrist != nil
        let haveLeftArm = leftShoulder != nil && leftElbow != nil && leftWrist != nil
        
        // Basic posture assessments
        WristisGoodPosture = haveRightArm || haveLeftArm
        ElbowisGoodPosture = haveRightArm || haveLeftArm
        ShoulderisGoodPosture = haveRightArm || haveLeftArm
        
        // For base class, these are simplified
        HipisGoodPosture = true
        KneeisGoodPosture = true
        AnkleisGoodPosture = true
        
        // Core straightness is simplified
        CoreisGoodPosture = haveRightArm || haveLeftArm
        
        // Overall posture assessment - if we can see at least one arm, consider it good
        isGoodPosture = haveRightArm || haveLeftArm
    }

    // Helper to check horizontal alignment (mostly y-coordinate similarity)
    func checkAlignment(joint1: Joint?, joint2: Joint?, threshold: Float, confidenceThreshold: Float) -> Bool {
        // If joints are missing, return true rather than false to avoid failing
        guard let j1 = joint1, let j2 = joint2 else { return true }
        if j1.confidence < confidenceThreshold || j2.confidence < confidenceThreshold {
            return true
        }

        let yDifference = abs(j1.location.y - j2.location.y)
        // Normalize the difference by a rough estimate of person height
        if let shoulder = bodyParts[.rightShoulder], let hip = bodyParts[.rightHip],
           shoulder.confidence > confidenceThreshold, hip.confidence > confidenceThreshold {
            let personHeightProxy = abs(shoulder.location.y - hip.location.y)
             if personHeightProxy > 1e-6 { // Avoid division by zero
                 let normalizedYDifference = yDifference / personHeightProxy
                 return normalizedYDifference < CGFloat(threshold)
             }
        }
        // Fallback to normalizing by screen height
        let normalizedYDifference = yDifference / UIScreen.main.bounds.height
        return normalizedYDifference < CGFloat(threshold)
    }

    // Helper to check vertical alignment (x-coordinate similarity)
    func checkVerticalAlignment(joint1: Joint?, joint2: Joint?, threshold: Float, confidenceThreshold: Float) -> Bool {
        // If joints are missing, return true rather than false to avoid failing
        guard let j1 = joint1, let j2 = joint2 else { return true }
        if j1.confidence < confidenceThreshold || j2.confidence < confidenceThreshold {
            return true
        }

        let xDifference = abs(j1.location.x - j2.location.x)
        // Normalize the difference by a rough estimate of person width
        if let leftShoulder = bodyParts[.leftShoulder], let rightShoulder = bodyParts[.rightShoulder],
           leftShoulder.confidence > confidenceThreshold, rightShoulder.confidence > confidenceThreshold {
            let personWidthProxy = abs(leftShoulder.location.x - rightShoulder.location.x)
            if personWidthProxy > 1e-6 { // Avoid division by zero
                let normalizedXDifference = xDifference / personWidthProxy
                return normalizedXDifference < CGFloat(threshold)
            }
        }
        // Fallback to normalizing by screen width
        let normalizedXDifference = xDifference / UIScreen.main.bounds.width
        return normalizedXDifference < CGFloat(threshold)
    }

    // Helper to check if the joints required for core straightness assessment are available
    func canAssessCoreStraightness() -> Bool {
        // Don't use confidence threshold - just check if joints exist
        let rightSideAvailable = bodyParts[.rightShoulder] != nil &&
                                 bodyParts[.rightHip] != nil &&
                                 bodyParts[.rightAnkle] != nil
        
        let leftSideAvailable = bodyParts[.leftShoulder] != nil &&
                                bodyParts[.leftHip] != nil &&
                                bodyParts[.leftAnkle] != nil
        
        // We only need one side to assess core straightness
        return rightSideAvailable || leftSideAvailable
    }

    // Calculate angle between three points - useful for all exercise types
    func calculateAngle(p1: CGPoint, p2: CGPoint, p3: CGPoint) -> CGFloat {
        let v1 = CGVector(dx: p1.x - p2.x, dy: p1.y - p2.y)
        let v2 = CGVector(dx: p3.x - p2.x, dy: p3.y - p2.y)

        // Calculate dot product and magnitudes
        let dotProduct = v1.dx * v2.dx + v1.dy * v2.dy
        let magnitude1 = sqrt(v1.dx * v1.dx + v1.dy * v1.dy)
        let magnitude2 = sqrt(v2.dx * v2.dx + v2.dy * v2.dy)

        // Avoid division by zero if points are the same or magnitudes are zero
        guard magnitude1 > 1e-6 && magnitude2 > 1e-6 else { return 0.0 }

        // Calculate angle in radians and convert to degrees
        let cosAngle = dotProduct / (magnitude1 * magnitude2)
        // Clamp the cosine value to the valid range [-1, 1] to avoid issues with acos
        let angle = acos(min(max(cosAngle, -1.0), 1.0)) * (180 / .pi)

        return angle
    }

    // Calibrate thresholds based on current measurements
    func calibrateThresholds() {
        // Ensure there are measurements to calibrate from
        guard !xShouldersDiffs.isEmpty && !yShouldersDiffs.isEmpty else {
            print("Cannot calibrate thresholds: Not enough data points.")
            return
        }

        // Calculate averages from current measurements
        let avgXShouldersDiff = xShouldersDiffs.reduce(0, +) / Float(xShouldersDiffs.count)
        let avgYShouldersDiff = yShouldersDiffs.reduce(0, +) / Float(yShouldersDiffs.count)

        // Set thresholds based on current posture
        // You might want to add a small buffer or multiplier here
        shouldersXThreshold = avgXShouldersDiff * 1.1 // Example: 10% buffer
        shouldersYThreshold = avgYShouldersDiff * 1.1

        print("Calibrated thresholds:")
        print("Shoulders X: \(shouldersXThreshold)")
        print("Shoulders Y: \(shouldersYThreshold)")
    }
    
    // Utility function for debug printing - used by subclasses too
    func debugPrint(_ message: String, category: DebugCategory) {
        switch category {
            case .jointConfidences:
                if DebugFlags.printJointConfidences { print(message) }
            case .shoulderPositions:
                if DebugFlags.printShoulderPositions { print(message) }
            case .elbowAngles:
                if DebugFlags.printElbowAngles { print(message) }
            case .bodyAngles:
                if DebugFlags.printBodyAngles { print(message) }
            case .pushUpDetection:
            if DebugFlags.printErrors { print(message) }
            case .kneeDetection:
            if DebugFlags.printErrors { print(message) }
            case .errors:
                if DebugFlags.printErrors { print(message) }
            case .visionDetection:
                if DebugFlags.enableVisionDetection { print(message) }
        }
    }
}

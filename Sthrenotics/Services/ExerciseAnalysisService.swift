//
//  ExerciseAnalysisService.swift
//  Sthrenotics
//
//  Fixed version with proper async/await handling
//

import Foundation
import Vision

class ExerciseAnalysisService: ObservableObject {
    @Published var isAnalyzing = false
    @Published var lastResult: ExerciseAnalysisResult?
    @Published var currentRepCount = 0
    @Published var liveFormScore: Double = 10.0
    @Published var liveFormFeedback = ""
    
    private var recordedFrames: [CoordinateFrame] = []
    private let openAIService = OpenAIService()
    private var lastAnalysisTime = Date()
    private let analysisInterval: TimeInterval = 3.0 // Analyze every 3 seconds for live feedback
    
    // Real-time analysis
    private var recentFrames: [CoordinateFrame] = []
    private let maxRecentFrames = 15 // Keep last 15 frames for live analysis
    
    func startNewSession() {
        recordedFrames.removeAll()
        recentFrames.removeAll()
        lastResult = nil
        currentRepCount = 0
        liveFormScore = 10.0
        liveFormFeedback = ""
        lastAnalysisTime = Date()
        print("🔍 DEBUG: Started new analysis session")
    }
    
    func addFrame(from poseEstimator: PoseEstimator) {
        let timestamp = Date().timeIntervalSinceReferenceDate
        
        // Debug: Print how many body parts we're getting
        print("🔍 DEBUG: Adding frame with \(poseEstimator.bodyParts.count) body parts")
        
        // Check if we actually have body parts
        if poseEstimator.bodyParts.isEmpty {
            print("⚠️ DEBUG: PoseEstimator has no body parts - skipping frame")
            return
        }
        
        // Convert HumanBodyPoseObservation.PoseJointName to String with detailed logging
        var bodyPartsStringDict: [String: CoordinateData] = [:]
        var validJointsCount = 0
        
        for (jointName, joint) in poseEstimator.bodyParts {
            let coordinateData = CoordinateData(
                x: Float(joint.location.x),
                y: Float(joint.location.y),
                confidence: joint.confidence
            )
            
            bodyPartsStringDict[jointName.rawValue] = coordinateData
            
            // Debug: Print each joint being added
            if joint.confidence > 0.1 {  // Lower threshold for debugging
                print("  ✅ Joint \(jointName.rawValue): conf=\(String(format: "%.2f", joint.confidence)) pos=(\(String(format: "%.3f", joint.location.x)), \(String(format: "%.3f", joint.location.y)))")
                validJointsCount += 1
            } else {
                print("  ❌ Joint \(jointName.rawValue): conf=\(String(format: "%.2f", joint.confidence)) - too low confidence")
            }
        }
        
        print("🔍 DEBUG: Total joints: \(poseEstimator.bodyParts.count), Valid joints (>0.1 conf): \(validJointsCount)")
        
        let frame = CoordinateFrame(
            timestamp: timestamp,
            bodyParts: bodyPartsStringDict
        )
        
        recordedFrames.append(frame)
        recentFrames.append(frame)
        
        print("🔍 DEBUG: Total recorded frames: \(recordedFrames.count), Recent frames: \(recentFrames.count)")
        
        // Keep only recent frames for live analysis
        if recentFrames.count > maxRecentFrames {
            recentFrames.removeFirst()
        }
        
        // Debug: Show what's in the most recent frame
        if let lastFrame = recentFrames.last {
            let validJoints = lastFrame.bodyParts.filter { $0.value.confidence > 0.3 }
            print("🔍 DEBUG: Last frame has \(validJoints.count) joints with confidence > 0.3")
            for (joint, data) in validJoints.prefix(5) {  // Show first 5 for brevity
                print("    \(joint): \(String(format: "%.3f", data.x)), \(String(format: "%.3f", data.y)) (conf: \(String(format: "%.2f", data.confidence)))")
            }
        }
        
        // Perform live analysis periodically
        let now = Date()
        if now.timeIntervalSince(lastAnalysisTime) >= analysisInterval && recentFrames.count >= 5 {
            lastAnalysisTime = now
            print("🔍 DEBUG: Triggering live analysis with \(recentFrames.count) frames")
            Task {
                await performLiveAnalysis()
            }
        } else {
            print("🔍 DEBUG: Not triggering analysis - time since last: \(String(format: "%.1f", now.timeIntervalSince(lastAnalysisTime)))s, frames: \(recentFrames.count)")
        }
    }
    
    // Live analysis for real-time feedback
    func performLiveAnalysis() async {
        guard !recentFrames.isEmpty else {
            print("🔍 DEBUG: No recent frames for live analysis")
            return
        }
        
        print("🔍 DEBUG: Starting live analysis with \(recentFrames.count) frames")
        
        let coordinateText = formatCoordinatesForAPI(frames: recentFrames, isLiveAnalysis: true)
        print("🔍 DEBUG: Performing live analysis with \(coordinateText.count) characters of data")
        print("🔍 DEBUG: Sample coordinate data: \(String(coordinateText.prefix(200)))")
        
        // Set analyzing state
        Task { @MainActor in
            print("🔍 DEBUG: Setting analyzing state to true")
        }
        
        do {
            print("🔍 DEBUG: About to call OpenAI service...")
            let result = await openAIService.analyzeLiveExercise(coordinateData: coordinateText)
            print("🔍 DEBUG: OpenAI service returned: \(result)")
            
            Task { @MainActor in
                print("🔍 DEBUG: Updating UI with live analysis results")
                print("🔍 DEBUG: New form score: \(result.formScore)")
                print("🔍 DEBUG: New feedback: \(result.feedback)")
                
                self.liveFormScore = result.formScore
                self.liveFormFeedback = result.feedback
                
                print("🔍 DEBUG: UI properties updated successfully")
            }
        } catch {
            print("❌ DEBUG: Error in live analysis: \(error)")
            Task { @MainActor in
                self.liveFormFeedback = "Analysis error: \(error.localizedDescription)"
            }
        }
    }
    
    // Full session analysis
    func analyzeExercise(exercise: String) async {
        guard !recordedFrames.isEmpty else {
            print("🔍 DEBUG: No recorded frames for analysis")
            return
        }
        
        print("🔍 DEBUG: Starting full analysis for \(exercise) with \(recordedFrames.count) frames")
        
        Task { @MainActor in
            self.isAnalyzing = true
        }
        
        let coordinateText = formatCoordinatesForAPI(frames: recordedFrames, isLiveAnalysis: false)
        print("🔍 DEBUG: Coordinate text length: \(coordinateText.count)")
        print("🔍 DEBUG: Sample coordinate text: \(String(coordinateText.prefix(200)))")
        
        let result = await openAIService.analyzeExercise(
            exercise: exercise,
            coordinateData: coordinateText
        )
        
        print("🔍 DEBUG: Full analysis result - Reps: \(result.repCount), Score: \(result.formScore), Feedback: \(result.feedback)")
        
        Task { @MainActor in
            self.isAnalyzing = false
            self.lastResult = result
            self.currentRepCount = result.repCount
        }
    }
    
    private func formatCoordinatesForAPI(frames: [CoordinateFrame], isLiveAnalysis: Bool) -> String {
        // For live analysis, use all recent frames
        // For full analysis, use intelligent sampling
        let framesToProcess = isLiveAnalysis ? frames : intelligentSample(frames: frames)
        
        print("🔍 DEBUG: Formatting coordinates - Input frames: \(frames.count), Processing: \(framesToProcess.count)")
        
        let result = framesToProcess.compactMap { frame in
            // Only include joints with reasonable confidence
            let validJoints = frame.bodyParts.compactMap { (joint, data) -> String? in
                guard data.confidence > 0.3 else {
                    return nil
                }
                return "\(abbreviateJoint(joint)):\(String(format: "%.3f", data.x)),\(String(format: "%.3f", data.y))"
            }
            
            guard !validJoints.isEmpty else {
                print("🔍 DEBUG: No valid joints in frame at timestamp \(frame.timestamp)")
                return nil
            }
            
            let timestamp = frame.timestamp - frames.first!.timestamp
            let frameString = "t:\(String(format: "%.1f", timestamp))|\(validJoints.joined(separator: "|"))"
            print("🔍 DEBUG: Frame string: \(frameString)")
            return frameString
        }.joined(separator: "\n")
        
        print("🔍 DEBUG: Final formatted result length: \(result.count) characters")
        if result.isEmpty {
            print("🚨 DEBUG: WARNING - Empty coordinate data! No frames had valid joints!")
        }
        
        return result
    }
    
    private func intelligentSample(frames: [CoordinateFrame]) -> [CoordinateFrame] {
        guard frames.count > 50 else { return frames }
        
        var sampledFrames: [CoordinateFrame] = []
        
        // Sample every 3rd frame to reduce data size while maintaining movement patterns
        for (index, frame) in frames.enumerated() {
            if index % 3 == 0 {
                sampledFrames.append(frame)
            }
        }
        
        // Always include last frame
        if let lastFrame = frames.last, sampledFrames.last?.timestamp != lastFrame.timestamp {
            sampledFrames.append(lastFrame)
        }
        
        return sampledFrames
    }
    
    private func abbreviateJoint(_ joint: String) -> String {
        let abbreviations: [String: String] = [
            "leftWrist": "lw", "rightWrist": "rw",
            "leftElbow": "le", "rightElbow": "re",
            "leftShoulder": "ls", "rightShoulder": "rs",
            "neck": "n", "leftHip": "lh", "rightHip": "rh",
            "leftKnee": "lk", "rightKnee": "rk",
            "leftAnkle": "la", "rightAnkle": "ra",
            "root": "rt", "nose": "ns"
        ]
        return abbreviations[joint] ?? joint
    }
}

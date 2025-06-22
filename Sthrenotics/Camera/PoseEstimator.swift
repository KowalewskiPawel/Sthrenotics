//
//  PoseEstimator.swift
//  Sthrenotics
//
//  Fixed version with proper threading and simplified logic
//

import Foundation
import AVFoundation
import Combine
import CoreGraphics
import SwiftUI
import Vision

class PoseEstimator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, ObservableObject {
    // Published properties - these will update the UI
    @Published var bodyParts = [HumanBodyPoseObservation.PoseJointName: Joint]()
    @Published var currentFrameImage: CGImage?
    
    // Simple form feedback properties
    @Published var isGoodPosture = true
    @Published var jointCount = 0  // Simple count for debugging
    
    // Frame processing properties
    var frameCounter: Int = 0
    private var isAnalyzingFrame: Bool = false
    private var currentTask: Task<Void, Never>? = nil
    
    var subscriptions = Set<AnyCancellable>()

    override init() {
        super.init()
        print("🔍 PoseEstimator: Initializing...")
        
        // Simple subscription to update joint count
        $bodyParts
            .receive(on: DispatchQueue.main)  // Ensure UI updates on main thread
            .sink { [weak self] bodyParts in
                self?.jointCount = bodyParts.count
                self?.isGoodPosture = bodyParts.count > 5  // Simple check
                print("🔔 Published bodyParts updated: \(bodyParts.count) joints")
            }
            .store(in: &subscriptions)
    }

    // MARK: - Camera Frame Processing (Simplified)
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        self.frameCounter += 1

        // Print every 30th frame to track activity
        if frameCounter % 30 == 0 {
            print("📹 FRAME #\(frameCounter)")
        }

        // Process every 3rd frame for performance
        if frameCounter % 3 == 0 && !self.isAnalyzingFrame {
            print("🔄 PROCESSING FRAME #\(frameCounter)")
            self.isAnalyzingFrame = true
            self.currentTask?.cancel()

            self.currentTask = Task { [weak self] in
                guard let self = self else { return }
                await self.analyzeFrame(frame: sampleBuffer)
                self.isAnalyzingFrame = false
                self.currentTask = nil
            }
        } else {
            CMSampleBufferInvalidate(sampleBuffer)
        }
    }

    // Simplified frame analysis
    func analyzeFrame(frame: CMSampleBuffer) async {
        print("🎯 Starting frame analysis...")
        
        if Task.isCancelled {
            CMSampleBufferInvalidate(frame)
            return
        }

        // Get pixel buffer
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(frame) else {
            CMSampleBufferInvalidate(frame)
            print("❌ Could not get pixel buffer")
            return
        }
        
        CMSampleBufferInvalidate(frame)

        do {
            // Create pose detection request
            var humanBodyPoseRequest = DetectHumanBodyPoseRequest()
            humanBodyPoseRequest.detectsHands = false
            
            print("🤖 Starting Vision request...")
            let results = try await humanBodyPoseRequest.perform(on: pixelBuffer)
            print("✅ Vision completed - found \(results.count) observations")

            if Task.isCancelled { return }

            // Process results and update UI on main thread
            if let observation = results.first {
                let joints = observation.allJoints()
                print("👤 Detected \(joints.count) joints with confidence \(observation.confidence)")
                
                // Print a few joints for debugging
                let sampleJoints = Array(joints.prefix(3))
                for (jointName, joint) in sampleJoints {
                    print("  📍 \(jointName.rawValue): \(String(format: "%.2f", joint.confidence)) at (\(String(format: "%.3f", joint.location.x)), \(String(format: "%.3f", joint.location.y)))")
                }
                
                // CRITICAL: Update on main thread using Task with @MainActor
                Task { @MainActor in
                    print("📢 Updating @Published bodyParts with \(joints.count) joints")
                    self.bodyParts = joints
                    print("✅ bodyParts updated successfully")
                }
                
            } else {
                print("❌ No body detected")
                Task { @MainActor in
                    self.bodyParts = [:]  // Clear joints when no body detected
                }
            }

        } catch {
            print("❌ Vision error: \(error)")
            Task { @MainActor in
                self.bodyParts = [:]  // Clear on error
            }
        }
    }
    
    // Simplified helper functions (keeping only what's needed)
    func debugPrint(_ message: String) {
        print(message)
    }
}

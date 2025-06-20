//
//  ExerciseAnalysisService.swift
//  Sthrenotics
//
//  Created by Pawel Kowalewski on 19/06/2025.
//


import Foundation

class ExerciseAnalysisService: ObservableObject {
    @Published var isAnalyzing = false
    @Published var lastResult: ExerciseAnalysisResult?
    
    private var recordedFrames: [CoordinateFrame] = []
    private let openAIService = OpenAIService()
    
    func startNewSession() {
        recordedFrames.removeAll()
        lastResult = nil
    }
    
    func addFrame(from poseEstimator: PoseEstimator) {
//        let timestamp = Date().timeIntervalSinceReferenceDate
//        let frame = CoordinateFrame(
//            timestamp: timestamp,
//            bodyParts: poseEstimator.bodyParts.mapValues { bodyPart in
//                CoordinateData(
//                    x: Float(bodyPart.location.x),
//                    y: Float(bodyPart.location.y),
//                    confidence: bodyPart.confidence
//                )
//            }
//        )
//        recordedFrames.append(frame)
    }
    
    func analyzeExercise(exercise: String) async {
        guard !recordedFrames.isEmpty else { return }
        
        DispatchQueue.main.async {
            self.isAnalyzing = true
        }
        
        let coordinateText = formatCoordinatesForAPI(frames: recordedFrames)
        let result = await openAIService.analyzeExercise(
            exercise: exercise,
            coordinateData: coordinateText
        )
        
        DispatchQueue.main.async {
            self.isAnalyzing = false
            self.lastResult = result
        }
    }
    
    private func formatCoordinatesForAPI(frames: [CoordinateFrame]) -> String {
        // Intelligent sampling: more frames during movement, fewer during static holds
        let sampledFrames = intelligentSample(frames: frames)
        
        return sampledFrames.compactMap { frame in
            // Only include joints with reasonable confidence (like your original code)
            let validJoints = frame.bodyParts.compactMap { (joint, data) -> String? in
                guard data.confidence > 0.3 else { return nil }
                return "\(abbreviateJoint(joint)):\(String(format: "%.3f", data.x)),\(String(format: "%.3f", data.y)),\(String(format: "%.2f", data.confidence))"
            }
            
            guard !validJoints.isEmpty else { return nil }
            
            let timestamp = frame.timestamp - frames.first!.timestamp // Relative timestamp
            return "t:\(String(format: "%.1f", timestamp))|\(validJoints.joined(separator: "|"))"
        }.joined(separator: "\n")
    }
    
    private func intelligentSample(frames: [CoordinateFrame]) -> [CoordinateFrame] {
        guard frames.count > 30 else { return frames } // Return all if short sequence
        
        var sampledFrames: [CoordinateFrame] = []
        var lastSampledFrame: CoordinateFrame?
        
        for frame in frames {
            if let lastFrame = lastSampledFrame {
                // Calculate movement between frames
                let movement = calculateMovement(from: lastFrame, to: frame)
                
                // Sample more frequently during high movement, less during static holds
                let shouldSample = movement > 0.05 ? // High movement threshold
                    sampledFrames.count % 2 == 0 : // Every 2nd frame
                    sampledFrames.count % 5 == 0   // Every 5th frame
                
                if shouldSample {
                    sampledFrames.append(frame)
                    lastSampledFrame = frame
                }
            } else {
                // Always include first frame
                sampledFrames.append(frame)
                lastSampledFrame = frame
            }
        }
        
        // Always include last frame
        if let lastFrame = frames.last, lastFrame.timestamp != lastSampledFrame?.timestamp {
            sampledFrames.append(lastFrame)
        }
        
        return sampledFrames
    }
    
    private func calculateMovement(from frame1: CoordinateFrame, to frame2: CoordinateFrame) -> Float {
        // Calculate average movement of key joints
        let keyJoints = ["leftWrist", "rightWrist", "leftShoulder", "rightShoulder"]
        var totalMovement: Float = 0
        var jointCount = 0
        
        for joint in keyJoints {
            if let point1 = frame1.bodyParts[joint],
               let point2 = frame2.bodyParts[joint],
               point1.confidence > 0.3 && point2.confidence > 0.3 {
                
                let dx = point1.x - point2.x
                let dy = point1.y - point2.y
                totalMovement += sqrt(dx * dx + dy * dy)
                jointCount += 1
            }
        }
        
        return jointCount > 0 ? totalMovement / Float(jointCount) : 0
    }
    
    private func abbreviateJoint(_ joint: String) -> String {
        // Abbreviate joint names to save tokens (like your original efficient approach)
        let abbreviations: [String: String] = [
            "leftWrist": "lw", "rightWrist": "rw",
            "leftElbow": "le", "rightElbow": "re",
            "leftShoulder": "ls", "rightShoulder": "rs",
            "neck": "n", "leftHip": "lh", "rightHip": "rh",
            "leftKnee": "lk", "rightKnee": "rk",
            "leftAnkle": "la", "rightAnkle": "ra", 
            "root": "rt"
        ]
        return abbreviations[joint] ?? joint
    }
}

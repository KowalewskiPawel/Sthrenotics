//
//  ExerciseAnalysisService.swift
//  Sthrenotics
//
//  Created by Pawel Kowalewski on 19/06/2025.
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
    private let analysisInterval: TimeInterval = 2.0 // Analyze every 2 seconds for live feedback
    
    // Real-time analysis
    private var recentFrames: [CoordinateFrame] = []
    private let maxRecentFrames = 20 // Keep last 20 frames for live analysis
    
    func startNewSession() {
        recordedFrames.removeAll()
        recentFrames.removeAll()
        lastResult = nil
        currentRepCount = 0
        liveFormScore = 10.0
        liveFormFeedback = ""
        lastAnalysisTime = Date()
    }
    
    func addFrame(from poseEstimator: PoseEstimator) {
        let timestamp = Date().timeIntervalSinceReferenceDate
        
        // Convert HumanBodyPoseObservation.PoseJointName to String
        let bodyPartsStringDict = poseEstimator.bodyParts.reduce(into: [String: CoordinateData]()) { result, item in
            result[item.key.rawValue] = CoordinateData(
                x: Float(item.value.location.x),
                y: Float(item.value.location.y),
                confidence: item.value.confidence
            )
        }
        
        let frame = CoordinateFrame(
            timestamp: timestamp,
            bodyParts: bodyPartsStringDict
        )
        
        recordedFrames.append(frame)
        recentFrames.append(frame)
        
        // Keep only recent frames for live analysis
        if recentFrames.count > maxRecentFrames {
            recentFrames.removeFirst()
        }
        
        // Perform live analysis periodically
        let now = Date()
        if now.timeIntervalSince(lastAnalysisTime) >= analysisInterval && recentFrames.count >= 10 {
            lastAnalysisTime = now
            Task {
                await performLiveAnalysis()
            }
        }
    }
    
    // Live analysis for real-time feedback
    private func performLiveAnalysis() async {
        guard !recentFrames.isEmpty else { return }
        
        let coordinateText = formatCoordinatesForAPI(frames: recentFrames, isLiveAnalysis: true)
        let result = await openAIService.analyzeLiveExercise(coordinateData: coordinateText)
        
        DispatchQueue.main.async {
            self.liveFormScore = result.formScore
            self.liveFormFeedback = result.feedback
        }
    }
    
    // Full session analysis
    func analyzeExercise(exercise: String) async {
        guard !recordedFrames.isEmpty else { return }
        
        DispatchQueue.main.async {
            self.isAnalyzing = true
        }
        
        let coordinateText = formatCoordinatesForAPI(frames: recordedFrames, isLiveAnalysis: false)
        let result = await openAIService.analyzeExercise(
            exercise: exercise,
            coordinateData: coordinateText
        )
        
        DispatchQueue.main.async {
            self.isAnalyzing = false
            self.lastResult = result
            self.currentRepCount = result.repCount
        }
    }
    
    private func formatCoordinatesForAPI(frames: [CoordinateFrame], isLiveAnalysis: Bool) -> String {
        // For live analysis, use all recent frames
        // For full analysis, use intelligent sampling
        let framesToProcess = isLiveAnalysis ? frames : intelligentSample(frames: frames)
        
        return framesToProcess.compactMap { frame in
            // Only include joints with reasonable confidence
            let validJoints = frame.bodyParts.compactMap { (joint, data) -> String? in
                guard data.confidence > 0.3 else { return nil }
                return "\(abbreviateJoint(joint)):\(String(format: "%.3f", data.x)),\(String(format: "%.3f", data.y))"
            }
            
            guard !validJoints.isEmpty else { return nil }
            
            let timestamp = frame.timestamp - frames.first!.timestamp
            return "t:\(String(format: "%.1f", timestamp))|\(validJoints.joined(separator: "|"))"
        }.joined(separator: "\n")
    }
    
    private func intelligentSample(frames: [CoordinateFrame]) -> [CoordinateFrame] {
        guard frames.count > 50 else { return frames }
        
        var sampledFrames: [CoordinateFrame] = []
        var lastSampledFrame: CoordinateFrame?
        
        for (index, frame) in frames.enumerated() {
            if let lastFrame = lastSampledFrame {
                let movement = calculateMovement(from: lastFrame, to: frame)
                
                // Sample more during movement, less during static holds
                let shouldSample = movement > 0.03 ?
                    index % 2 == 0 :  // Every 2nd frame during movement
                    index % 6 == 0    // Every 6th frame during static holds
                
                if shouldSample {
                    sampledFrames.append(frame)
                    lastSampledFrame = frame
                }
            } else {
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
        let keyJoints = ["leftWrist", "rightWrist", "leftShoulder", "rightShoulder", "leftHip", "rightHip"]
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

//
//  DebugAnalysisView.swift
//  Sthrenotics
//
//  Created by Pawel Kowalewski on 21/06/2025.
//


//
//  DebugAnalysisView.swift
//  Sthrenotics
//
//  Debug view to troubleshoot OpenAI integration
//

import SwiftUI

struct DebugAnalysisView: View {
    @ObservedObject var analysisService: ExerciseAnalysisService
    @ObservedObject var poseEstimator: PoseEstimator
    @State private var showingDebugInfo = false
    
    var body: some View {
        VStack {
            // Debug toggle button
            Button("🔍 Debug Info") {
                showingDebugInfo.toggle()
            }
            .padding()
            .background(Color.blue.opacity(0.7))
            .foregroundColor(.white)
            .cornerRadius(8)
            
            if showingDebugInfo {
                debugInfoView
            }
        }
    }
    
    private var debugInfoView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // API Key Status
                debugSection("API Configuration") {
                    let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? "Not Set"
                    Text("API Key: \(apiKey == "Not Set" ? "❌ Not configured" : "✅ Configured (\(apiKey.count) chars)")")
                        .foregroundColor(apiKey == "Not Set" ? .red : .green)
                }
                
                // Pose Detection Status
                debugSection("Pose Detection") {
                    Text("Detected joints: \(poseEstimator.bodyParts.count)")
                    Text("Body parts detected: \(poseEstimator.bodyParts.isEmpty ? "❌ None" : "✅ Active")")
                        .foregroundColor(poseEstimator.bodyParts.isEmpty ? .red : .green)
                    
                    // Show some joint details
                    ForEach(Array(poseEstimator.bodyParts.prefix(3)), id: \.key) { joint, bodyPart in
                        Text("\(joint.rawValue): confidence \(String(format: "%.2f", bodyPart.confidence))")
                            .font(.caption)
                    }
                }
                
                // Analysis Service Status
                debugSection("Analysis Service") {
                    Text("Is analyzing: \(analysisService.isAnalyzing ? "✅ Yes" : "❌ No")")
                    Text("Live form score: \(String(format: "%.1f", analysisService.liveFormScore))")
                    Text("Live feedback: \(analysisService.liveFormFeedback.isEmpty ? "None" : analysisService.liveFormFeedback)")
                    Text("Last result: \(analysisService.lastResult?.feedback ?? "None")")
                }
                
                // Test OpenAI Button
                Button("🧪 Test OpenAI Connection") {
                    testOpenAIConnection()
                }
                .padding()
                .background(Color.orange.opacity(0.7))
                .foregroundColor(.white)
                .cornerRadius(8)
                
                // Sample coordinate data
                debugSection("Sample Data") {
                    let sampleData = generateSampleCoordinateData()
                    Text("Sample coordinate data:")
                        .font(.headline)
                    Text(sampleData)
                        .font(.caption)
                        .background(Color.gray.opacity(0.2))
                        .padding(4)
                }
            }
            .padding()
        }
        .frame(maxHeight: 400)
        .background(Color.black.opacity(0.8))
        .cornerRadius(12)
        .foregroundColor(.white)
    }
    
    private func debugSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundColor(.yellow)
            content()
        }
        .padding(.vertical, 4)
    }
    
    private func testOpenAIConnection() {
        Task {
            let testData = generateSampleCoordinateData()
            let openAIService = OpenAIService()
            
            print("🧪 Testing OpenAI connection with sample data...")
            let result = await openAIService.analyzeExercise(exercise: "sitting", coordinateData: testData)
            
            print("🧪 Test result: \(result)")
            
            // You could also update the UI with the test result
            DispatchQueue.main.async {
                // Update some state to show the test result
            }
        }
    }
    
    private func generateSampleCoordinateData() -> String {
        return """
        t:0.0|ls:0.3,0.4|rs:0.7,0.4|le:0.2,0.6|re:0.8,0.6|lw:0.1,0.8|rw:0.9,0.8
        t:1.0|ls:0.3,0.4|rs:0.7,0.4|le:0.2,0.6|re:0.8,0.6|lw:0.1,0.8|rw:0.9,0.8
        t:2.0|ls:0.3,0.4|rs:0.7,0.4|le:0.2,0.6|re:0.8,0.6|lw:0.1,0.8|rw:0.9,0.8
        """
    }
}

// Add this to your main ContentView
extension ContentView {
    var debugButton: some View {
        Button("🔧") {
            // Toggle debug view
        }
        .padding()
        .background(Color.gray.opacity(0.7))
        .foregroundColor(.white)
        .cornerRadius(8)
    }
}

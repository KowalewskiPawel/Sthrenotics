//
//  ContentView.swift
//  Sthrenotics
//
//  Simplified working version with proper threading
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var poseEstimator = PoseEstimator()
    @StateObject private var analysisService = ExerciseAnalysisService()
    @State private var isRecording = false
    @State private var selectedExercise = "Sitting Posture"
    @State private var showingDebugInfo = false
    
    let exercises = ["Push-ups", "Squats", "Sitting Posture", "Plank"]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Camera View - PASS THE SAME POSE ESTIMATOR INSTANCE
                CameraViewWrapper(poseEstimator: poseEstimator)
                    .ignoresSafeArea()
                
                // Skeleton overlay using the SAME pose estimator
                FreePostureStickFigureView(poseEstimator: poseEstimator, size: geometry.size)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                
                // UI Overlay
                VStack {
                    // Top Controls
                    topControlsView
                    
                    Spacer()
                    
                    // Live Analysis Display
                    if isRecording {
                        liveAnalysisView
                    }
                    
                    // Debug Info
                    if showingDebugInfo {
                        debugInfoView
                    }
                    
                    // Final Results
                    if let result = analysisService.lastResult {
                        AnalysisResultView(result: result)
                            .padding()
                    }
                    
                    // Control Buttons
                    controlButtonsView
                }
            }
        }
        .onReceive(poseEstimator.$bodyParts) { bodyParts in
            print("🔔 ContentView: Received \(bodyParts.count) body parts")
            
            if isRecording && !bodyParts.isEmpty {
                print("🎯 Adding frame to analysis service")
                analysisService.addFrame(from: poseEstimator)
            }
        }
        .onAppear {
            print("🔔 ContentView appeared")
        }
    }
    
    // MARK: - View Components
    
    private var topControlsView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Sthrenotics")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("AI Exercise Coach")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            // Exercise Picker
            Picker("Exercise", selection: $selectedExercise) {
                ForEach(exercises, id: \.self) { exercise in
                    Text(exercise).tag(exercise)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.7))
            .foregroundColor(.white)
            .cornerRadius(8)
            
            // Debug Toggle
            Button(action: { showingDebugInfo.toggle() }) {
                Image(systemName: "ladybug")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.purple.opacity(0.7))
                    .cornerRadius(8)
            }
        }
        .padding()
    }
    
    private var liveAnalysisView: some View {
        VStack(spacing: 12) {
            // Recording indicator
            HStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                    .blinking(duration: 0.8)
                Text("Analyzing \(selectedExercise)")
                    .foregroundColor(.white)
                    .font(.headline)
                    .fontWeight(.medium)
            }
            
            // Live metrics
            HStack(spacing: 20) {
                // Rep counter
                VStack {
                    Text("\(analysisService.currentRepCount)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("REPS")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                // Live form score
                VStack {
                    Text("\(analysisService.liveFormScore, specifier: "%.1f")")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(liveScoreColor)
                    Text("FORM")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                // Joint detection (using the new simplified property)
                VStack {
                    Text("\(poseEstimator.jointCount)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("JOINTS")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            // Live feedback - make it more prominent
            VStack {
                if !analysisService.liveFormFeedback.isEmpty {
                    Text("💡 \(analysisService.liveFormFeedback)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                } else {
                    Text("Waiting for analysis...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.8))
                .shadow(radius: 8)
        )
        .padding()
    }
    
    private var controlButtonsView: some View {
        HStack(spacing: 20) {
            Button(action: toggleRecording) {
                HStack {
                    Image(systemName: isRecording ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title2)
                    Text(isRecording ? "Stop & Analyze" : "Start Analysis")
                        .font(.headline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .frame(minWidth: 180)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isRecording ? Color.red.opacity(0.8) : Color.green.opacity(0.8))
                        .shadow(radius: 4)
                )
            }
            .disabled(analysisService.isAnalyzing)
            
            if analysisService.isAnalyzing {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                    Text("AI Processing...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .padding(.bottom, 40)
    }
    
    // MARK: - Debug Info (Simplified)
    
    private var debugInfoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("🔍 Debug Information")
                .font(.headline)
                .foregroundColor(.yellow)
            
            VStack(alignment: .leading, spacing: 4) {
                // API Key Status
                let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? "Not Set"
                Text("API Key: \(apiKey == "Not Set" ? "❌ Missing" : "✅ Set")")
                    .foregroundColor(apiKey == "Not Set" ? .red : .green)
                
                // Joint Detection Status
                Text("Detected Joints: \(poseEstimator.jointCount)")
                    .foregroundColor(poseEstimator.jointCount > 0 ? .green : .red)
                
                Text("Recording: \(isRecording ? "✅ Yes" : "❌ No")")
                
                Text("Analysis Service: \(analysisService.isAnalyzing ? "🔄 Active" : "⏸️ Idle")")
                
                Text("Live Score: \(String(format: "%.1f", analysisService.liveFormScore))")
                
                Text("Live Feedback: '\(analysisService.liveFormFeedback)'")
                    .font(.caption)
                    .foregroundColor(analysisService.liveFormFeedback.isEmpty ? .red : .green)
                
                // Test Buttons
                HStack(spacing: 8) {
                    Button("🧪 Test") { testSimple() }
                        .buttonStyle(DebugButtonStyle(color: .orange))
                    
                    Button("🔴 Live") { forceLiveAnalysis() }
                        .buttonStyle(DebugButtonStyle(color: .red))
                        
                    Button("📊 Full") { forceFullAnalysis() }
                        .buttonStyle(DebugButtonStyle(color: .blue))
                }
            }
            .font(.caption)
            .foregroundColor(.white)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.9))
                .shadow(radius: 4)
        )
        .padding()
    }
    
    // MARK: - Helper Functions
    
    private func testSimple() {
        Task {
            print("🧪 Simple Test - Current joints: \(poseEstimator.jointCount)")
            
            // Test with current data if available
            if poseEstimator.jointCount > 0 {
                print("🧪 Testing with real pose data")
                analysisService.addFrame(from: poseEstimator)
                await analysisService.performLiveAnalysis()
            } else {
                print("🧪 No joints detected - testing with sample data")
                let openAIService = OpenAIService()
                let testData = "t:0.0|ls:0.3,0.4|rs:0.7,0.4|n:0.5,0.2"
                let result = await openAIService.analyzeExercise(exercise: "Test", coordinateData: testData)
                print("🧪 Result: \(result)")
            }
        }
    }
    
    private func forceLiveAnalysis() {
        print("🔴 Force LIVE analysis - joints: \(poseEstimator.jointCount)")
        if poseEstimator.jointCount > 0 {
            analysisService.addFrame(from: poseEstimator)
            Task {
                print("🔴 Starting immediate live analysis...")
                await analysisService.performLiveAnalysis()
                print("🔴 Live analysis completed")
            }
        } else {
            print("🔴 No joints detected for live analysis")
        }
    }
    
    private func forceFullAnalysis() {
        print("📊 Force FULL analysis - joints: \(poseEstimator.jointCount)")
        if poseEstimator.jointCount > 0 {
            // Add a few frames for full analysis
            for _ in 0..<3 {
                analysisService.addFrame(from: poseEstimator)
            }
            Task {
                print("📊 Starting full exercise analysis...")
                await analysisService.analyzeExercise(exercise: selectedExercise)
                print("📊 Full analysis completed")
            }
        } else {
            print("📊 No joints detected for full analysis")
        }
    }
    
    private func forceAnalysis() {
        forceLiveAnalysis() // Just call the live analysis for backward compatibility
    }
    
    // MARK: - Computed Properties
    
    private var liveScoreColor: Color {
        switch analysisService.liveFormScore {
        case 8...10: return .green
        case 6..<8: return .yellow
        case 4..<6: return .orange
        default: return .red
        }
    }
    
    // MARK: - Actions
    
    private func toggleRecording() {
        if isRecording {
            isRecording = false
            Task {
                await analysisService.analyzeExercise(exercise: selectedExercise)
            }
        } else {
            analysisService.startNewSession()
            isRecording = true
        }
    }
}

struct DebugButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.8))
            .foregroundColor(.white)
            .cornerRadius(4)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

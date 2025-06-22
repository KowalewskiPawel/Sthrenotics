//
//  ContentView.swift
//  Sthrenotics
//
//  Simple working version using existing PoseEstimator
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var poseEstimator = PoseEstimator()
    @StateObject private var analysisService = ExerciseAnalysisService()
    @State private var isRecording = false
    @State private var selectedExercise = "Push-ups"
    @State private var showingDebugInfo = false
    @State private var cameraPosition: AVCaptureDevice.Position = .front
    
    let exercises = [
        "Push-ups", "Squats", "Burpees", "Lunges", "Plank",
        "Jumping Jacks", "Mountain Climbers", "Sit-ups", "Sitting Posture"
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Camera View with pose analysis
                PoseAnalysisView()
                    .ignoresSafeArea()
                
                // UI Overlay
                VStack {
                    // Top Controls
                    topControlsView
                    
                    Spacer()
                    
                    // Live Analysis Display
                    if isRecording {
                        liveAnalysisView
                    }
                    
                    // Debug Info Overlay
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
            if isRecording {
                print("🔍 DEBUG: ContentView received \(bodyParts.count) body parts, passing to analysis service")
                analysisService.addFrame(from: poseEstimator)
            } else {
                print("🔍 DEBUG: ContentView received body parts but not recording")
            }
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
            
            // Camera Toggle
            Button(action: toggleCamera) {
                Image(systemName: "camera.rotate")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(8)
            }
            
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
                
                // Joint detection
                VStack {
                    Text("\(poseEstimator.bodyParts.count)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("JOINTS")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            // Live feedback
            if !analysisService.liveFormFeedback.isEmpty {
                Text(analysisService.liveFormFeedback)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
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
    
    // MARK: - Debug Info View (Simplified)
    
    private var debugInfoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("🔍 Debug Information")
                .font(.headline)
                .foregroundColor(.yellow)
            
            VStack(alignment: .leading, spacing: 4) {
                // API Key Status
                apiKeyStatusView
                
                // Basic Pose Detection
                Text("Detected Joints: \(poseEstimator.bodyParts.count)")
                    .foregroundColor(poseEstimator.bodyParts.isEmpty ? .red : .green)
                
                // Show some detected joints if any
                if !poseEstimator.bodyParts.isEmpty {
                    Text("Sample Joints:")
                        .foregroundColor(.green)
                    let sampleJoints = Array(poseEstimator.bodyParts.prefix(3))
                    ForEach(sampleJoints, id: \.key) { joint, bodyPart in
                        Text("  \(joint.rawValue): \(String(format: "%.2f", bodyPart.confidence))")
                            .font(.caption2)
                    }
                }
                
                // Analysis Status
                Text("Analysis Service: \(analysisService.isAnalyzing ? "🔄 Active" : "⏸️ Idle")")
                
                Text("Live Score: \(String(format: "%.1f", analysisService.liveFormScore))")
                
                if !analysisService.liveFormFeedback.isEmpty {
                    Text("Live Feedback: \(analysisService.liveFormFeedback)")
                        .font(.caption)
                }
                
                // Action Buttons
                VStack(spacing: 6) {
                    Button("🧪 Test OpenAI") {
                        testOpenAIConnection()
                    }
                    .buttonStyle(DebugButtonStyle(color: .orange))
                    
                    Button("🔴 Force Analysis") {
                        forceLiveAnalysis()
                    }
                    .buttonStyle(DebugButtonStyle(color: .red))
                    
                    Button("📷 Check Camera") {
                        checkCameraPermissions()
                    }
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
    
    private var apiKeyStatusView: some View {
        let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? "Not Set"
        return Text("API Key: \(apiKey == "Not Set" ? "❌ Missing" : "✅ Set (\(apiKey.count) chars)")")
            .foregroundColor(apiKey == "Not Set" ? .red : .green)
    }
    
    // MARK: - Helper Functions
    
    private func forceLiveAnalysis() {
        print("🔴 DEBUG: Force live analysis button pressed")
        print("🔴 DEBUG: Current body parts count: \(poseEstimator.bodyParts.count)")
        
        // Manually add current frame to analysis service
        analysisService.addFrame(from: poseEstimator)
        
        // Force immediate analysis
        Task {
            await analysisService.performLiveAnalysis()
        }
    }
    
    private func testOpenAIConnection() {
        Task {
            let testData = "t:0.0|ls:0.3,0.4|rs:0.7,0.4|n:0.5,0.2"
            let openAIService = OpenAIService()
            
            print("🧪 Testing OpenAI with sample data...")
            let result = await openAIService.analyzeExercise(exercise: "Test", coordinateData: testData)
            print("🧪 Test result: \(result)")
        }
    }
    
    private func checkCameraPermissions() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        print("🎥 Camera permission status: \(status.rawValue)")
        
        switch status {
        case .authorized:
            print("✅ Camera access authorized")
        case .denied:
            print("❌ Camera access denied")
        case .restricted:
            print("⚠️ Camera access restricted")
        case .notDetermined:
            print("❓ Camera access not determined")
            AVCaptureDevice.requestAccess(for: .video) { granted in
                print("🎥 Camera access granted: \(granted)")
            }
        @unknown default:
            print("❓ Unknown camera status")
        }
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
    
    private func toggleCamera() {
        let newPosition: AVCaptureDevice.Position = cameraPosition == .front ? .back : .front
        cameraPosition = newPosition
        
        // Post notification for camera switch
        NotificationCenter.default.post(name: .switchCamera, object: newPosition)
        print("Sthrenotics: Camera toggle requested - \(newPosition == .front ? "front" : "back")")
    }
}

// MARK: - Custom Button Style for Debug Buttons

struct DebugButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.8))
            .foregroundColor(.white)
            .cornerRadius(6)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

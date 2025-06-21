//
//  ContentView.swift
//  Sthrenotics
//
//  Created by Pawel Kowalewski on 19/06/2025.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var poseEstimator = PoseEstimator()
    @StateObject private var analysisService = ExerciseAnalysisService()
    @State private var isRecording = false
    @State private var selectedExercise = "Push-ups"
    @State private var showCustomExercise = false
    @State private var customExerciseName = ""
    @State private var customExerciseDescription = ""
    
    // Expanded exercise list
    let exercises = [
        "Push-ups", "Squats", "Burpees", "Lunges", "Plank",
        "Jumping Jacks", "Mountain Climbers", "Sit-ups",
        "Deadlifts", "Pull-ups", "Custom Exercise..."
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
        .onReceive(poseEstimator.$bodyParts) { _ in
            if isRecording {
                analysisService.addFrame(from: poseEstimator)
            }
        }
        .sheet(isPresented: $showCustomExercise) {
            customExerciseSheet
        }
        .onChange(of: selectedExercise) { newValue in
            if newValue == "Custom Exercise..." {
                showCustomExercise = true
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
                Text("Analyzing \(displayExerciseName)")
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
    
    private var customExerciseSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Define Custom Exercise")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Exercise Name")
                        .font(.headline)
                    TextField("e.g., Diamond Push-ups", text: $customExerciseName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Exercise Description")
                        .font(.headline)
                    TextField("Describe the movement pattern and key form points", text: $customExerciseDescription, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                }
                
                Text("Example: 'Push-up variation with hands forming diamond shape, focuses on triceps, requires close hand position'")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .italic()
                
                Spacer()
                
                HStack {
                    Button("Cancel") {
                        showCustomExercise = false
                        selectedExercise = "Push-ups"
                    }
                    .foregroundColor(.red)
                    
                    Spacer()
                    
                    Button("Start Analysis") {
                        selectedExercise = customExerciseName.isEmpty ? "Custom Exercise" : customExerciseName
                        showCustomExercise = false
                    }
                    .disabled(customExerciseName.isEmpty || customExerciseDescription.isEmpty)
                    .foregroundColor(.blue)
                }
                .padding()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Computed Properties
    
    private var displayExerciseName: String {
        selectedExercise == "Custom Exercise..." ? "Custom Exercise" : selectedExercise
    }
    
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
                if selectedExercise.contains("Custom") && !customExerciseDescription.isEmpty {
                    // Use custom exercise analysis
                    await performCustomExerciseAnalysis()
                } else {
                    // Use standard exercise analysis
                    await analysisService.analyzeExercise(exercise: selectedExercise)
                }
            }
        } else {
            analysisService.startNewSession()
            isRecording = true
        }
    }
    
    private func performCustomExerciseAnalysis() async {
        let exerciseName = customExerciseName.isEmpty ? "Custom Exercise" : customExerciseName
        
        // Since we need to modify OpenAIService to support custom analysis,
        // for now we'll use the standard analysis with the custom exercise name
        await analysisService.analyzeExercise(exercise: "\(exerciseName): \(customExerciseDescription)")
    }
}

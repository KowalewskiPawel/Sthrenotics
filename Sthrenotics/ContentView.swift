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
    @State private var cameraPosition: AVCaptureDevice.Position = .front
    
    let exercises = ["Push-ups", "Squats", "Burpees", "Plank", "Jumping Jacks", "Lunges", "Mountain Climbers"]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Camera View with built-in skeleton overlay
                PoseAnalysisView()
                    .ignoresSafeArea()
                
                // UI Controls
                VStack {
                    // Top Controls
                    HStack {
                        // App Title
                        VStack(alignment: .leading) {
                            Text("Sthrenotics")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Text("Strength Through Vision")
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
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Recording Status
                    if isRecording {
                        HStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 12, height: 12)
                                .blinking(duration: 0.8)
                            Text("Analyzing \(selectedExercise)")
                                .foregroundColor(.white)
                                .font(.headline)
                                .fontWeight(.medium)
                            Text("• \(poseEstimator.bodyParts.count) joints detected")
                                .foregroundColor(.white.opacity(0.7))
                                .font(.caption)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(12)
                    }
                    
                    // Analysis Results
                    if let result = analysisService.lastResult {
                        AnalysisResultView(result: result)
                            .padding()
                    }
                    
                    // Control Buttons
                    HStack(spacing: 20) {
                        Button(action: toggleRecording) {
                            HStack {
                                Image(systemName: isRecording ? "stop.circle.fill" : "play.circle.fill")
                                    .font(.title2)
                                Text(isRecording ? "Stop Analysis" : "Start Analysis")
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
                                Text("Analyzing with AI...")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .onReceive(poseEstimator.$bodyParts) { _ in
            if isRecording {
                analysisService.addFrame(from: poseEstimator)
            }
        }
    }
    
    private func toggleRecording() {
        if isRecording {
            // Stop recording and analyze
            isRecording = false
            Task {
                await analysisService.analyzeExercise(exercise: selectedExercise)
            }
        } else {
            // Start recording
            analysisService.startNewSession()
            isRecording = true
        }
    }
    
    private func toggleCamera() {
//        cameraPosition = cameraPosition == .front ? .back : .front
//        // Post notification for camera switch
//        NotificationCenter.default.post(name: .switchCamera, object: cameraPosition)
//        print("Sthrenotics: Camera toggle requested - \(cameraPosition)")
    }
}

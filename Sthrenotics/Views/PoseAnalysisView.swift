//
//  PoseAnalysisView.swift
//  Sthrenotics
//
//  Created by Pawel Kowalewski on 20/06/2025.
//


import SwiftUI
import CoreGraphics // Required for CGPoint

// A SwiftUI view for analyzing pose data on top of the camera feed.
struct PoseAnalysisView: View {
    // Observe the PoseEstimator to react to changes in body parts and frame image.
    // This view receives the PoseEstimator from a parent view, likely as a StateObject.
    @StateObject var poseEstimator = PoseEstimator()

    // State variables for managing placeholder settings views
    @State private var showAnalysisSettings = false
    @State private var showCoordinateSettings = false

    var body: some View {
        // Use GeometryReader to get the size of the view for scaling and positioning.
        GeometryReader { geometry in
            // ZStack to layer the camera feed, skeleton, coordinates, and overlays.
            ZStack {
                // Call the helper function to build the main content layers.
                mainContentView(geometry: geometry)

                // Placeholder Settings buttons overlay (similar structure to PushUpTestView)
                VStack {
                    HStack {
                        Spacer() // Pushes buttons to the right

                        // Example Analysis Settings button
                        Button(action: {
                            showAnalysisSettings.toggle()
                        }) {
                            Label("Analysis", systemImage: "chart.bar.doc.horizontal")
                        }
                        .padding()
                        .background(Color.black.opacity(0.5)) // Add background for visibility
                        .foregroundColor(.white)
                        .cornerRadius(8)

                        // Example Coordinate Settings button
                        Button(action: {
                            showCoordinateSettings.toggle()
                        }) {
                            Label("Coordinates", systemImage: "number.circle")
                        }
                        .padding()
                         .background(Color.black.opacity(0.5)) // Add background for visibility
                         .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    Spacer() // Pushes buttons to the top
                }
                 .padding(.top, 10) // Add some padding from the top edge
                 .padding(.trailing, 10) // Add some padding from the trailing edge
            }
        }
        // Add placeholder sheets for settings
        .sheet(isPresented: $showAnalysisSettings) {
            // Analysis settings view content
            NavigationView {
                VStack {
                    Text("Analysis Settings")
                        .font(.title)
                        .padding()
                    Text("Configure thresholds, multipliers, etc.")
                        .foregroundColor(.gray)
                    // Add actual settings controls here
                    Spacer()
                }
                .navigationTitle("Analysis Settings")
            }
        }
        .sheet(isPresented: $showCoordinateSettings) {
            // Coordinate display settings view content
             NavigationView {
                 VStack {
                     Text("Coordinate Display Settings")
                         .font(.title)
                         .padding()
                     Text("Choose which joints to display, format, etc.")
                         .foregroundColor(.gray)
                     // Add actual settings controls here
                     Spacer()
                 }
                 .navigationTitle("Coordinate Settings")
             }
        }
    }

    // Helper function to build the main layered content (camera, skeleton, coordinates).
    private func mainContentView(geometry: GeometryProxy) -> some View {
        ZStack {
            // 1. Display the camera feed.
            // Uses CameraViewWrapper which should handle the live feed display.
            CameraViewWrapper(poseEstimator: poseEstimator)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped() // Ensure the video feed is clipped to the view bounds.

            // 2. Draw the skeleton on top of the video feed.
            // Uses PushUpStickFigureView to draw the skeleton based on pose data.
            FreePostureStickFigureView(poseEstimator: poseEstimator, size: geometry.size)
                .frame(width: geometry.size.width, height: geometry.size.height)


            // 3. Display CGPoint values for each detected joint.
            // Iterate through the detected body parts. Sorting by key makes the order consistent.
            ForEach(poseEstimator.bodyParts.sorted(by: { $0.key.rawValue < $1.key.rawValue }), id: \.key) { jointName, joint in
                // Only display coordinates for joints with sufficient confidence.
                if joint.confidence > 0.1 { // Use the same confidence threshold as in PoseEstimator

                    // Scale the normalized joint location (0 to 1) to the view size (points).
                    // Apply a vertical flip (1.0 - y) because Vision coordinates have (0,0) top-left
                    // and Y increases downwards, while SwiftUI's default positioning might
                    // implicitly assume (0,0) bottom-left or you might need to match a flipped video.
                    // This vertical flip should align the text with the potentially vertically
                    // flipped camera feed and skeleton drawing.
                    let scaledPoint = CGPoint(
                        x: joint.location.x * geometry.size.width,
                        y: (1.0 - joint.location.y) * geometry.size.height // Apply vertical flip
                    )

                    // Create the text label showing the joint name and its scaled coordinates.
                    Text("\(jointName.rawValue):\n(\(String(format: "%.2f", scaledPoint.x)), \(String(format: "%.2f", scaledPoint.y)))")
                        .font(.caption) // Use a small font size.
                        .foregroundColor(.white) // White text for visibility on video.
                        .padding(4) // Add some padding around the text.
                        .background(Color.black.opacity(0.7)) // Semi-transparent black background.
                        .cornerRadius(5) // Rounded corners for the background.
                        // Position the text label at the calculated scaled point.
                        .position(scaledPoint)
                        // Add a small circle or dot at the joint location for better visual correlation.
                        .overlay(
                            Circle()
                                .frame(width: 8, height: 8) // Size of the dot.
                                .foregroundColor(.blue) // Color of the dot.
                                .position(scaledPoint) // Position the dot at the same scaled point.
                        )
                }
            }
        }
    }
}

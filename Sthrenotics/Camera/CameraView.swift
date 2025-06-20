//
//  CameraView.swift
//  FormForgeV2
//
//  Created by Pawel Kowalewski on 09/05/2025.
//

import SwiftUI
import AVFoundation // Import AVFoundation for AVCaptureSession type

struct CameraView: View {
    @ObservedObject var viewModel: CameraViewModel

    var body: some View {
        GeometryReader { geometry in
            ZStack { // Use ZStack to layer the preview and the processed frame/overlays
                // Display the live camera preview
                if let captureSession = viewModel.captureSession {
                    CameraPreviewView(session: captureSession)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                } else {
                    // Handle the case where the session is not available
                    ContentUnavailableView(
                        "Camera Setup Failed",
                        systemImage: "video.slash.fill",
                        description: Text("The camera session could not be set up.")
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }

                // Optionally, display the processed frame or draw overlays on top
                // For now, let's keep displaying the processed image for demonstration
                // You might remove this if you prefer drawing directly on the preview
                if let processedImage = viewModel.currentFrame {
                     Image(decorative: processedImage, scale: 1)
                         .resizable()
                         .aspectRatio(contentMode: .fill)
                         .frame(width: geometry.size.width, height: geometry.size.height)
                         .clipped()
                         .scaleEffect(x: -1, y: 1) // Mirror horizontally if needed
                         .opacity(0.5) // Example: make it semi-transparent to see the live feed behind
                }

                // You would add drawing logic here based on viewModel.bodyParts
                // For example, using a Canvas or a custom Shape view to draw keypoints.
            }
        }
    }
}

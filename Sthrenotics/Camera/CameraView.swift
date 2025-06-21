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
            ZStack { // Use ZStack to layer the preview and overlays
                // Display ONLY the live camera preview
                if let captureSession = viewModel.captureSession {
                    CameraPreviewView(session: captureSession)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    // Handle the case where the session is not available
                    ContentUnavailableView(
                        "Camera Setup Failed",
                        systemImage: "video.slash.fill",
                        description: Text("The camera session could not be set up.")
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }

                // REMOVED: The duplicate processed frame overlay that was causing the double vision
                // The pose estimation overlays (skeleton, coordinates) should be drawn on top
                // via the parent view (PoseAnalysisView) rather than duplicating the camera feed
            }
        }
    }
}

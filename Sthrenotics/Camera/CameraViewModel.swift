//
//  CameraViewModel.swift
//  FormForgeV2
//
//  Created by Pawel Kowalewski on 09/05/2025.
//

import Foundation
import SwiftUI
import AVFoundation
import Combine

class CameraViewModel: ObservableObject {
    @Published var currentFrame: CGImage?
    private let poseEstimator: PoseEstimator
    
    var captureSession: AVCaptureSession?
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue", qos: .userInteractive)
    private let processingQueue = DispatchQueue(label: "camera.processing.queue", qos: .userInteractive)
    
    private var isConfigured = false
    private var cancellables = Set<AnyCancellable>()
    
    init(poseEstimator: PoseEstimator) {
        self.poseEstimator = poseEstimator
        setupSession()
    }
    
    deinit {
        stopSession()
    }
    
    func setupSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.configureSession()
            self.startSession()
        }
    }
    
    private func configureSession() {
        guard !isConfigured else { return }
        
        let session = AVCaptureSession()
        
        // Begin configuration
        session.beginConfiguration()
        
        // Set quality level
        session.sessionPreset = .high
        
        // Camera Input
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            print("Failed to get front camera")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            
            if session.canAddInput(input) {
                session.addInput(input)
            } else {
                print("Could not add camera input")
                return
            }
        } catch {
            print("Failed to create camera input: \(error.localizedDescription)")
            return
        }
        
        // Video Output
        videoOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as String): Int(kCVPixelFormatType_32BGRA)]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self.poseEstimator, queue: processingQueue)
        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        } else {
            print("Could not add video output")
            return
        }
        
        // Get connection and set orientation
        if let connection = videoOutput.connection(with: .video) {
            connection.videoOrientation = .portrait
            connection.isVideoMirrored = true
        }
        
        session.commitConfiguration()
        
        captureSession = session
        isConfigured = true
        
        // Set up frame callback from pose estimator
        setupFrameCallback()
    }
    
    private func setupFrameCallback() {
        // This assumes you have a way to get frames from the pose estimator
        // You might need to modify PoseEstimator to expose frames
        NotificationCenter.default.publisher(for: .newCameraFrame)
            .compactMap { notification -> CGImage? in
                // Explicitly check if the object is a CGImage using CFGetTypeID
                guard let imageObject = notification.object else { return nil }

                // Use the modern CGImage.typeID property
                let imageTypeID = CGImage.typeID

                guard CFGetTypeID(imageObject as CFTypeRef) == imageTypeID else {
                    // Optional: Log a warning if the object is not the expected type
                    print("Received unexpected object type for .newCameraFrame notification.")
                    return nil
                }

                // Now that we've confirmed the type using CFGetTypeID,
                // we can confidently force cast. The compiler no longer
                // warns about the conditional downcast always succeeding
                // because the type is verified by the guard statement.
                return imageObject as! CGImage
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] image in
                self?.currentFrame = image
            }
            .store(in: &cancellables)
    }
    
    func startSession() {
        guard let session = captureSession, !session.isRunning else { return }
        
        sessionQueue.async {
            session.startRunning()
        }
    }
    
    func stopSession() {
        guard let session = captureSession, session.isRunning else { return }
        
        sessionQueue.async {
            session.stopRunning()
        }
    }
}

// Notification name for new camera frames
extension Notification.Name {
    static let newCameraFrame = Notification.Name("newCameraFrame")
}

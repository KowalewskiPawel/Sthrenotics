//
//  CameraViewModel.swift
//  Sthrenotics
//
//  Enhanced with camera switching functionality
//

import Foundation
import SwiftUI
import AVFoundation
import Combine

class CameraViewModel: ObservableObject {
    @Published var currentFrame: CGImage?
    @Published var currentCameraPosition: AVCaptureDevice.Position = .front
    
    private let poseEstimator: PoseEstimator
    
    var captureSession: AVCaptureSession?
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue", qos: .userInteractive)
    private let processingQueue = DispatchQueue(label: "camera.processing.queue", qos: .userInteractive)
    
    private var isConfigured = false
    private var cancellables = Set<AnyCancellable>()
    private var currentCameraInput: AVCaptureDeviceInput?
    
    init(poseEstimator: PoseEstimator) {
        self.poseEstimator = poseEstimator
        setupSession()
        
        // Listen for camera switch notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(switchCameraNotification(_:)),
            name: .switchCamera,
            object: nil
        )
    }
    
    deinit {
        stopSession()
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func switchCameraNotification(_ notification: Notification) {
        if let position = notification.object as? AVCaptureDevice.Position {
            switchCamera(to: position)
        }
    }
    
    func switchCamera(to position: AVCaptureDevice.Position) {
        sessionQueue.async { [weak self] in
            self?.performCameraSwitch(to: position)
        }
    }
    
    private func performCameraSwitch(to position: AVCaptureDevice.Position) {
        guard let session = captureSession else { return }
        
        session.beginConfiguration()
        
        // Remove current input
        if let currentInput = currentCameraInput {
            session.removeInput(currentInput)
        }
        
        // Add new camera input
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            print("Failed to get camera for position: \(position)")
            session.commitConfiguration()
            return
        }
        
        do {
            let newInput = try AVCaptureDeviceInput(device: camera)
            
            if session.canAddInput(newInput) {
                session.addInput(newInput)
                currentCameraInput = newInput
                
                // Update connection settings
                if let connection = videoOutput.connection(with: .video) {
                    connection.videoOrientation = .portrait
                    connection.isVideoMirrored = (position == .front)
                }
                
                // Update published property on main thread
                DispatchQueue.main.async {
                    self.currentCameraPosition = position
                }
                
                print("Successfully switched to \(position == .front ? "front" : "back") camera")
            } else {
                print("Could not add new camera input")
            }
        } catch {
            print("Failed to create camera input: \(error.localizedDescription)")
        }
        
        session.commitConfiguration()
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
        
        // Camera Input (start with front camera)
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            print("Failed to get front camera")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            
            if session.canAddInput(input) {
                session.addInput(input)
                currentCameraInput = input
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
            connection.isVideoMirrored = true // Start with front camera mirrored
        }
        
        session.commitConfiguration()
        
        captureSession = session
        isConfigured = true
        
        // Set up frame callback from pose estimator
        setupFrameCallback()
    }
    
    private func setupFrameCallback() {
        NotificationCenter.default.publisher(for: .newCameraFrame)
            .compactMap { notification -> CGImage? in
                guard let imageObject = notification.object else { return nil }
                let imageTypeID = CGImage.typeID
                guard CFGetTypeID(imageObject as CFTypeRef) == imageTypeID else {
                    print("Received unexpected object type for .newCameraFrame notification.")
                    return nil
                }
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

// Add notification for camera switching
extension Notification.Name {
    static let newCameraFrame = Notification.Name("newCameraFrame")
    static let switchCamera = Notification.Name("switchCamera")
}

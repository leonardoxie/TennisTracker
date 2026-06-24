import AVFoundation
import UIKit
import Combine

/// Manages camera capture session and provides video frames
class CameraManager: NSObject, ObservableObject {
    @Published var isRunning = false
    @Published var authorizationStatus: AVAuthorizationStatus = .notDetermined
    
    let captureSession = AVCaptureSession()
    private var videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let videoOutputQueue = DispatchQueue(label: "camera.video.output.queue")
    
    var onFrameCaptured: ((CMSampleBuffer) -> Void)?
    
    override init() {
        super.init()
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }
    
    func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.authorizationStatus = granted ? .authorized : .denied
            }
        }
    }
    
    func startSession() {
        guard !captureSession.isRunning else { return }
        
        sessionQueue.async { [weak self] in
            self?.setupCaptureSession()
            self?.captureSession.startRunning()
            DispatchQueue.main.async {
                self?.isRunning = true
            }
        }
    }
    
    func stopSession() {
        guard captureSession.isRunning else { return }
        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
            DispatchQueue.main.async {
                self?.isRunning = false
            }
        }
    }
    
    private func setupCaptureSession() {
        guard captureSession.inputs.isEmpty else { return }
        
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high // 1920x1080
        
        // Add camera input
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            captureSession.commitConfiguration()
            return
        }
        
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }
        
        // Configure camera for best quality
        try? camera.lockForConfiguration()
        if camera.isFocusModeSupported(.continuousAutoFocus) {
            camera.focusMode = .continuousAutoFocus
        }
        if camera.isExposureModeSupported(.continuousAutoExposure) {
            camera.exposureMode = .continuousAutoExposure
        }
        if camera.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
            camera.whiteBalanceMode = .continuousAutoWhiteBalance
        }
        camera.unlockForConfiguration()
        
        // Add video output
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        // Set video orientation
        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
        }
        
        captureSession.commitConfiguration()
    }
    
    func switchCamera() {
        guard let currentInput = captureSession.inputs.first as? AVCaptureDeviceInput else { return }
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            let newPosition: AVCaptureDevice.Position = currentInput.device.position == .back ? .front : .back
            guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
                  let newInput = try? AVCaptureDeviceInput(device: newCamera) else { return }
            
            self.captureSession.beginConfiguration()
            self.captureSession.removeInput(currentInput)
            
            if self.captureSession.canAddInput(newInput) {
                self.captureSession.addInput(newInput)
            }
            
            self.captureSession.commitConfiguration()
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        onFrameCaptured?(sampleBuffer)
    }
}

//
//  CameraView.swift
//  PoseDetectionApp
//
//  Created by Syeda Arisha Shamim on 22/09/2024.
//

import SwiftUI
import AVFoundation
import Photos
import Combine

struct CameraView: UIViewControllerRepresentable {
    @ObservedObject var viewModel: PoseDetectionViewModel
    var onPoseDetected: ((String) -> Void)?

    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController(viewModel: viewModel)
        controller.onPoseDetected = onPoseDetected
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
}

class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    private var captureSession: AVCaptureSession!
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    var viewModel: PoseDetectionViewModel
    var onPoseDetected: ((String) -> Void)?
    private var videoOutput: AVCaptureMovieFileOutput!
    private var timer: Timer?
    private var anyCancellable = Set<AnyCancellable>()
    private var shouldSaveVideo = true

    init(viewModel: PoseDetectionViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        checkCameraPermissions()
    }

    private func checkCameraPermissions() {
        AVCaptureDevice.requestAccess(for: .video) { response in
            if response {
                DispatchQueue.main.async {
                    self.setupCaptureSession()
                    self.setupObserver()
                }
            } else {
                print("Camera access denied")
            }
        }
    }
    
    private func setupObserver() {
        viewModel.$detectedPose.first(where: { string in
            string == "Golf Pose Detected"
        }).sink { string in
            print("CompletionBlock:", string)
            self.startRecording()
        }
        .store(in: &anyCancellable)
        
        viewModel.$detectedPose.filter { $0 == "Golf Pose Detected" && self.shouldSaveVideo }
            .sink { string in
                self.startRecording()
            }
            .store(in: &anyCancellable)
    }

    private func setupCameraSession() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .high

        guard let videoCaptureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else { return }

        captureSession.addInput(videoInput)

        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer.frame = view.layer.bounds
        videoPreviewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(videoPreviewLayer)

        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        captureSession.addOutput(videoDataOutput)

        DispatchQueue.global(qos: .background).async {
            self.captureSession.startRunning()
        }
    }
    
    func setupCaptureSession() {
        captureSession = AVCaptureSession()
        captureSession.beginConfiguration()
        
        // Set up the camera input
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .high

        guard let videoCaptureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else { return }

        captureSession.addInput(videoInput)
        
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer.frame = view.layer.bounds
        videoPreviewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(videoPreviewLayer)
        
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        captureSession.addOutput(videoDataOutput)
        
        //Set up the audio input
        guard let audioDevice = AVCaptureDevice.default(for: .audio),
              let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
              captureSession.canAddInput(audioInput) else { return }
        captureSession.addInput(audioInput)
        
        // Set up the video output
        videoOutput = AVCaptureMovieFileOutput()
        guard captureSession.canAddOutput(videoOutput) else { return }
        captureSession.addOutput(videoOutput)
        
        captureSession.commitConfiguration()
        DispatchQueue.global(qos: .background).async {
            self.captureSession.startRunning()
        }
        
    }
    
    @objc func startRecording() {
        // Create a temporary file path to save the video
        let outputFilePath = NSTemporaryDirectory() + "\(UUID().uuidString).mov"
        let outputURL = URL(fileURLWithPath: outputFilePath)
        
        // Start recording
        videoOutput.startRecording(to: outputURL, recordingDelegate: self)
        
        // Set up a timer to stop recording after 5 seconds
        self.shouldSaveVideo = false
        timer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(stopRecording), userInfo: nil, repeats: false)
        showToast(message: "Recording Began")
    }
    
    @objc func stopRecording() {
        if videoOutput.isRecording {
            videoOutput.stopRecording()
            timer?.invalidate()  // Invalidate the timer to prevent automatic stopping if manually stopped
        }
    }
    
    func saveVideoToCameraRoll(outputFileURL: URL) {
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputFileURL)
            }) { (saved, error) in
                if saved {
                    print("Video saved to camera roll!")
                    DispatchQueue.main.async {
                        self.showToast(message: "Video Saved")
                        self.shouldSaveVideo = true
                    }
                } else if let error = error {
                    print("Error saving video: \(error.localizedDescription)")
                }
            }
        }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            print("Pose detection failed: Unable to convert image.")
            return
        }

        let uiImage = UIImage(cgImage: cgImage)

        if let landmarks = viewModel.detectPose(in: uiImage) {
            viewModel.processLandmarks(landmarks)
        }
    }
}

extension CameraViewController: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if error != nil {
            print("Error recording video: \(error!.localizedDescription)")
        } else {
            // Save the recorded video to the Camera Roll
            saveVideoToCameraRoll(outputFileURL: outputFileURL)
        }
    }
}


extension UIViewController {
    
    func showToast(message: String, duration: Double = 2.0) {
        // Create a label to act as the toast
        let toastLabel = UILabel(frame: CGRect(x: self.view.frame.size.width / 2 - 150,
                                               y: self.view.frame.size.height - 100,
                                               width: 300, height: 35))
        toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        toastLabel.textColor = UIColor.white
        toastLabel.textAlignment = .center
        toastLabel.font = UIFont(name: "Helvetica-Bold", size: 14.0)
        toastLabel.text = message
        toastLabel.alpha = 0.0
        toastLabel.layer.cornerRadius = 10
        toastLabel.clipsToBounds = true
        
        // Add the toast label to the view controller's view
        self.view.addSubview(toastLabel)
        
        // Animate the toast appearing and then disappearing
        UIView.animate(withDuration: 0.5, delay: 0.0, options: .curveEaseIn, animations: {
            toastLabel.alpha = 1.0
        }) { _ in
            UIView.animate(withDuration: 0.5, delay: duration, options: .curveEaseOut, animations: {
                toastLabel.alpha = 0.0
            }) { _ in
                // Remove the label from the view once it is fully transparent
                toastLabel.removeFromSuperview()
            }
        }
    }
}

//
//  VideoRecordingManager.swift
//  PoseDetectionApp
//
//  Created by Syeda Arisha Shamim on 22/09/2024.
//

import Foundation
import AVFoundation

class VideoRecordingManager: NSObject, AVCaptureFileOutputRecordingDelegate{
    var outputFileURL: URL?// = URL.init(filePath: "")
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: (any Error)?) {
        self.outputFileURL = outputFileURL
    }
    
    private let videoOutput = AVCaptureMovieFileOutput()
    private var isRecording = false

    func startRecording() {
        if !isRecording {
            // Set up the video file output and start recording
            guard let outputFileURL else { return }
            videoOutput.startRecording(to: outputFileURL, recordingDelegate: self)
            isRecording = true
        }
    }

    func stopRecording() {
        if isRecording {
            videoOutput.stopRecording()
            isRecording = false
        }
    }
}

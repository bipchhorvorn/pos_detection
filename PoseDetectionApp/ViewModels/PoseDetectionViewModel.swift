//
//  PoseDetectionViewModel.swift
//  PoseDetectionApp
//
//  Created by Syeda Arisha Shamim on 22/09/2024.
//
import Foundation
import MediaPipeTasksVision
import UIKit

class PoseDetectionViewModel: ObservableObject {
    @Published var detectedPose: String = ""

    private var poseLandmarker: PoseLandmarker?

    init() {
        setupPoseLandmarker()
    }

    func setupPoseLandmarker() {
        guard let modelPath = Bundle.main.path(forResource: "pose_landmarker_full.task", ofType: nil) else {
            fatalError("Failed to load pose detection model.")
        }

        do {
            let options = PoseLandmarkerOptions()
            options.baseOptions.modelAssetPath = modelPath
            poseLandmarker = try PoseLandmarker(options: options)
        } catch {
            fatalError("Failed to initialize PoseLandmarker: \(error.localizedDescription)")
        }
    }

    func detectPose(in image: UIImage) -> [[NormalizedLandmark]]? {
        guard let poseLandmarker = poseLandmarker else { return nil }

        do {
            let mpImage = try MPImage(uiImage: image)
            let detectionResult = try poseLandmarker.detect(image: mpImage)
            return detectionResult.landmarks
        } catch {
            print("Pose detection failed: \(error.localizedDescription)")
            return nil
        }
    }

    private var lastDetectedPose: String = ""
    private let poseDetectionCooldown: TimeInterval = 1.0
    private var lastDetectionTime: Date = Date()

    func processLandmarks(_ landmarks: [[NormalizedLandmark]]) {
        for poseLandmarks in landmarks {
            if let poseType = identifyGolfPose(landmarks: poseLandmarks) {
                let now = Date()
//                if lastDetectedPose != poseType  now.timeIntervalSince(lastDetectionTime) > poseDetectionCooldown {
                    DispatchQueue.main.async {
                        self.detectedPose = poseType
                        self.lastDetectedPose = poseType
                        self.lastDetectionTime = now
                        print("Detected Pose: \(poseType)")
                    }
            } else {
                DispatchQueue.main.async {
                    self.detectedPose = "No Pose Detected"
                }
            }
        }
    }
    
    private func identifyGolfPose(landmarks: [NormalizedLandmark]) -> String? {
        // Ensure we have the correct number of landmarks
        guard landmarks.count >= 33 else {
            print("Not enough landmarks for pose detection")
            return nil
        }

        // Extract relevant landmark indices (you might need to adjust these based on your landmarks)
        let shoulderLeft = landmarks[11]
        let shoulderRight = landmarks[12]
        let hipLeft = landmarks[23]
        let hipRight = landmarks[24]
        let elbowLeft = landmarks[13]
        let elbowRight = landmarks[14]
        
        // Calculate angles between relevant landmarks
        let shoulderAngle = calculateAngle(pointA: shoulderLeft, pointB: elbowLeft, pointC: shoulderRight)
        let hipAngle = calculateAngle(pointA: hipLeft, pointB: shoulderLeft, pointC: hipRight)

        // Define angle thresholds for golf pose
        let shoulderThreshold: (CGFloat, CGFloat) = (150.0, 180.0) // Example range for shoulder angle
        let hipThreshold: (CGFloat, CGFloat) = (150.0, 180.0) // Example range for hip angle

        // Log the calculated angles for debugging
        print("Shoulder Angle: \(shoulderAngle), Hip Angle: \(hipAngle)")

        // Check if angles are within the thresholds
        if shoulderThreshold.0 <= shoulderAngle && shoulderAngle <= shoulderThreshold.1 &&
           hipThreshold.0 <= hipAngle && hipAngle <= hipThreshold.1 {
            print("Golf Pose Detected") // Log for detection
            return "Golf Pose Detected"
        }

        print("No golf pose detected") // Log for no detection
        return nil
    }

    // Helper function to calculate angle between three points
    private func calculateAngle(pointA: NormalizedLandmark, pointB: NormalizedLandmark, pointC: NormalizedLandmark) -> CGFloat {
        let vectorAB = CGPoint(x: CGFloat(pointB.x - pointA.x), y: CGFloat(pointB.y - pointA.y))
        let vectorBC = CGPoint(x: CGFloat(pointC.x - pointB.x), y: CGFloat(pointC.y - pointB.y))

        let dotProduct = vectorAB.x * vectorBC.x + vectorAB.y * vectorBC.y
        let magnitudeAB = sqrt(vectorAB.x * vectorAB.x + vectorAB.y * vectorAB.y)
        let magnitudeBC = sqrt(vectorBC.x * vectorBC.x + vectorBC.y * vectorBC.y)

        guard magnitudeAB > 0 && magnitudeBC > 0 else {
            return 0
        }

        let cosTheta = dotProduct / (magnitudeAB * magnitudeBC)
        return acos(cosTheta) * (180.0 / .pi) // Convert radians to degrees
    }

    private func isHumanPoseValid(landmarks: [NormalizedLandmark]) -> Bool {
        // Simple checks for human pose validity
        let shoulderLeft = landmarks[11].y
        let shoulderRight = landmarks[12].y
        let hipLeft = landmarks[23].y // Adjust index based on your model
        let hipRight = landmarks[24].y // Adjust index based on your model

        // Check if shoulder and hip positions are within expected ranges
        return shoulderLeft > 0 && shoulderRight > 0 && hipLeft > 0 && hipRight > 0
    }


    private func calculateShoulderAngle(landmarks: [NormalizedLandmark]) -> Float {
        let shoulderLeft = CGPoint(x: CGFloat(landmarks[11].x), y: CGFloat(landmarks[11].y))
        let shoulderRight = CGPoint(x: CGFloat(landmarks[12].x), y: CGFloat(landmarks[12].y))
        let elbowLeft = CGPoint(x: CGFloat(landmarks[13].x), y: CGFloat(landmarks[13].y))

        return calculateAngle(pointA: shoulderLeft, pointB: elbowLeft, pointC: shoulderRight)
    }

    private func calculateAngle(pointA: CGPoint, pointB: CGPoint, pointC: CGPoint) -> Float {
        let ab = CGPoint(x: pointB.x - pointA.x, y: pointB.y - pointA.y)
        let bc = CGPoint(x: pointB.x - pointC.x, y: pointB.y - pointC.y)

        let dotProduct = ab.x * bc.x + ab.y * bc.y
        let magnitudeAB = sqrt(ab.x * ab.x + ab.y * ab.y)
        let magnitudeBC = sqrt(bc.x * bc.x + bc.y * bc.y)

        let angle = acos(dotProduct / (magnitudeAB * magnitudeBC))
        return Float(angle * (180.0 / .pi)) // Convert radians to degrees
    }
}


//class PoseDetectionViewModel: ObservableObject {
//    @Published var detectedPose: String = ""
//
//    private var poseLandmarker: PoseLandmarker?
//
//    init() {
//        setupPoseLandmarker()
//    }
//
//    func setupPoseLandmarker() {
//        guard let modelPath = Bundle.main.path(forResource: "pose_landmarker_full.task", ofType: nil) else {
//            fatalError("Failed to load pose detection model.")
//        }
//
//        do {
//            let options = PoseLandmarkerOptions()
//            options.baseOptions.modelAssetPath = modelPath
//            poseLandmarker = try PoseLandmarker(options: options)
//        } catch {
//            fatalError("Failed to initialize PoseLandmarker: \(error.localizedDescription)")
//        }
//    }
//
//    func detectPose(in image: UIImage) -> [[NormalizedLandmark]]? {
//        guard let poseLandmarker = poseLandmarker else { return nil }
//
//        do {
//            let mpImage = try MPImage(uiImage: image)
//            let detectionResult = try poseLandmarker.detect(image: mpImage)
//            return detectionResult.landmarks
//        } catch {
//            print("Pose detection failed: \(error.localizedDescription)")
//            return nil
//        }
//    }
//
//    private var lastDetectedPose: String = ""
//    private let poseDetectionCooldown: TimeInterval = 1.0
//    private var lastDetectionTime: Date = Date()
//
//    func processLandmarks(_ landmarks: [[NormalizedLandmark]]) {
//        for poseLandmarks in landmarks {
//            if let poseType = identifyGolfPose(landmarks: poseLandmarks) {
//                let now = Date()
//                if lastDetectedPose != poseType && now.timeIntervalSince(lastDetectionTime) > poseDetectionCooldown {
//                    DispatchQueue.main.async {
//                        self.detectedPose = poseType
//                        self.lastDetectedPose = poseType
//                        self.lastDetectionTime = now
//                    }
//                }
//            } else {
//                DispatchQueue.main.async {
//                    self.detectedPose = ""
//                }
//            }
//        }
//    }
//
//    private func identifyGolfPose(landmarks: [NormalizedLandmark]) -> String? {
//        guard landmarks.count > 10 else { return nil }
//
//        let shoulderAngleThreshold: Float = 45.0
//        let hipPositionThreshold: Float = 0.5
//
//        let shoulderAngle = calculateShoulderAngle(landmarks: landmarks)
//        let hipPosition = landmarks[11].y
//
//        if shoulderAngle < shoulderAngleThreshold && hipPosition < hipPositionThreshold {
//            return "Golf Pose Detected"
//        }
//
//        return nil
//    }
//
//    private func calculateShoulderAngle(landmarks: [NormalizedLandmark]) -> Float {
//        let shoulderLeft = CGPoint(x: CGFloat(landmarks[11].x), y: CGFloat(landmarks[11].y))
//        let shoulderRight = CGPoint(x: CGFloat(landmarks[12].x), y: CGFloat(landmarks[12].y))
//        let elbowLeft = CGPoint(x: CGFloat(landmarks[13].x), y: CGFloat(landmarks[13].y))
//
//        return calculateAngle(pointA: shoulderLeft, pointB: elbowLeft, pointC: shoulderRight)
//    }
//
//    private func calculateAngle(pointA: CGPoint, pointB: CGPoint, pointC: CGPoint) -> Float {
//        let ab = CGPoint(x: pointB.x - pointA.x, y: pointB.y - pointA.y)
//        let bc = CGPoint(x: pointB.x - pointC.x, y: pointB.y - pointC.y)
//
//        let dotProduct = ab.x * bc.x + ab.y * bc.y
//        let magnitudeAB = sqrt(ab.x * ab.x + ab.y * ab.y)
//        let magnitudeBC = sqrt(bc.x * bc.x + bc.y * bc.y)
//
//        let angle = acos(dotProduct / (magnitudeAB * magnitudeBC))
//        return Float(angle * (180.0 / .pi))
//    }
//}
//



//class PoseDetectionViewModel: ObservableObject {
//    private var poseLandmarker: PoseLandmarker?
//
//    init() {
//        setupPoseLandmarker()
//    }
//
//    func setupPoseLandmarker() {
//        // Load the pose detection model from the bundle
//        guard let modelPath = Bundle.main.path(forResource: "pose_landmarker_full.task", ofType: nil) else {
//            fatalError("Failed to load pose detection model.")
//        }
//
//        do {
//            // Initialize the pose landmarker with the model path
//            let options = PoseLandmarkerOptions()
//            options.baseOptions.modelAssetPath = modelPath
//            poseLandmarker = try PoseLandmarker(options: options)
//
//        } catch {
//            fatalError("Failed to initialize PoseLandmarker: \(error.localizedDescription)")
//        }
//    }
//
//    // Function to detect pose landmarks from a given UIImage
//    func detectPose(in image: UIImage) -> [[NormalizedLandmark]]? {
//        guard let poseLandmarker = poseLandmarker else { return nil }
//
//        do {
//            // Convert UIImage to MPImage
//            let mpImage = try MPImage(uiImage: image)
//
//            // Detect poses in the image and return the landmarks for each pose
//            let detectionResult = try poseLandmarker.detect(image: mpImage)
//
//            // Return the detected landmarks (array of poses, each containing an array of landmarks)
//            return detectionResult.landmarks
//
//        } catch {
//            print("Pose detection failed: \(error.localizedDescription)")
//            return nil
//        }
//    }
//
//    // Function to process detected landmarks for all poses
//    func processLandmarks(_ landmarks: [[NormalizedLandmark]]) {
//        for (poseIndex, poseLandmarks) in landmarks.enumerated() {
//            print("Pose \(poseIndex + 1):")
//            for (landmarkIndex, landmark) in poseLandmarks.enumerated() {
//                print("Landmark \(landmarkIndex + 1): x: \(landmark.x), y: \(landmark.y), z: \(landmark.z)")
//            }
//        }
//    }
//}

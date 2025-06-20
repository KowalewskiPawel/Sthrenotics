import SwiftUI

struct FreePostureStickFigureView: View {
    @ObservedObject var poseEstimator: PoseEstimator
    var size: CGSize
    
    var body: some View {
        if poseEstimator.bodyParts.isEmpty == false {
            ZStack {
                // Right leg
                if let rightAnkle = poseEstimator.bodyParts[.rightAnkle],
                   let rightKnee = poseEstimator.bodyParts[.rightKnee],
                   let rightHip = poseEstimator.bodyParts[.rightHip],
                   let root = poseEstimator.bodyParts[.root],
                   rightAnkle.confidence > 0.2,
                   rightKnee.confidence > 0.2,
                   rightHip.confidence > 0.2,
                   root.confidence > 0.2 {
                    
                    Stick(points: [rightAnkle.location.cgPoint, rightKnee.location.cgPoint, rightHip.location.cgPoint, root.location.cgPoint], size: size)
                        .stroke(lineWidth: 5.0)
                        .fill(Color.green)
                }
                
                // Left leg
                if let leftAnkle = poseEstimator.bodyParts[.leftAnkle],
                   let leftKnee = poseEstimator.bodyParts[.leftKnee],
                   let leftHip = poseEstimator.bodyParts[.leftHip],
                   let root = poseEstimator.bodyParts[.root],
                   leftAnkle.confidence > 0.2,
                   leftKnee.confidence > 0.2,
                   leftHip.confidence > 0.2,
                   root.confidence > 0.2 {
                    
                    Stick(points: [leftAnkle.location.cgPoint, leftKnee.location.cgPoint, leftHip.location.cgPoint, root.location.cgPoint], size: size)
                        .stroke(lineWidth: 5.0)
                        .fill(Color.green)
                }
                
                // Right arm
                if let rightWrist = poseEstimator.bodyParts[.rightWrist],
                   let rightElbow = poseEstimator.bodyParts[.rightElbow],
                   let rightShoulder = poseEstimator.bodyParts[.rightShoulder],
                   let neck = poseEstimator.bodyParts[.neck],
                   rightWrist.confidence > 0.2,
                   rightElbow.confidence > 0.2,
                   rightShoulder.confidence > 0.2,
                   neck.confidence > 0.2 {
                    
                    Stick(points: [rightWrist.location.cgPoint, rightElbow.location.cgPoint, rightShoulder.location.cgPoint, neck.location.cgPoint], size: size)
                        .stroke(lineWidth: 5.0)
                        .fill(Color.green)
                }
                
                // Left arm
                if let leftWrist = poseEstimator.bodyParts[.leftWrist],
                   let leftElbow = poseEstimator.bodyParts[.leftElbow],
                   let leftShoulder = poseEstimator.bodyParts[.leftShoulder],
                   let neck = poseEstimator.bodyParts[.neck],
                   leftWrist.confidence > 0.2,
                   leftElbow.confidence > 0.2,
                   leftShoulder.confidence > 0.2,
                   neck.confidence > 0.2 {
                    
                    Stick(points: [leftWrist.location.cgPoint, leftElbow.location.cgPoint, leftShoulder.location.cgPoint, neck.location.cgPoint], size: size)
                        .stroke(lineWidth: 5.0)
                        .fill(Color.green)
                }
                
                // Root to nose
                if let root = poseEstimator.bodyParts[.root],
                   let neck = poseEstimator.bodyParts[.neck],
                   let nose = poseEstimator.bodyParts[.nose],
                   root.confidence > 0.2,
                   neck.confidence > 0.2,
                   nose.confidence > 0.2 {
                    
                    Stick(points: [root.location.cgPoint, neck.location.cgPoint, nose.location.cgPoint], size: size)
                        .stroke(lineWidth: 5.0)
                        .fill(Color.green)
                }
            }
        }
    }
}

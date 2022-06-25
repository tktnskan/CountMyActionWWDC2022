/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The app's main view model.
*/

import SwiftUI
import CreateMLComponents
import AsyncAlgorithms

/// - Tag: ViewModel
class ViewModel: ObservableObject {

    /// The full-screen view that presents the pose on top of the video frames.
    @Published var liveCameraImageAndPoses: (image: CGImage, poses: [Pose])?

    /// The user-visible value of the repetition count.
    var uiCount: Float = 0.0

    private var displayCameraTask: Task<Void, Error>?

    private var predictionTask: Task<Void, Error>?

    /// Stores the predicted action repetition count in the last window.
    private var lastCumulativeCount: Float = 0.0

    /// An asynchronous channel to divert the pose stream for another consumer.
    private let poseStream = AsyncChannel<TemporalFeature<[Pose]>>()
    
    /// A Create ML Components transformer to extract human body poses from a single image or a video frame.
    /// - Tag: poseExtractor
    private let poseExtractor = HumanBodyPoseExtractor()
    
    /// The camera configuration to define the basic camera position, pixel format, and resolution to use.
    private var configuration = VideoReader.CameraConfiguration(
        position: .front,
        pixelFormat: .bgra32,
        resolution: .high
    )
    
    /// The counter to count action repetitions from a pose stream.
    private let actionCounter = ActionCounter()

// MARK: - View Controller Events

    /// Configures the main view after it loads.
    /// Starts the video-processing pipeline.
    func initialize() {
        startVideoProcessingPipeline()
    }

// MARK: - Button Events

    /// Toggles the view between the front- and back-facing cameras.
    func onCameraButtonTapped() {
        toggleCameraSelection()

        // Reset the count.
        uiCount = 0.0

        // Restart the video processing.
        startVideoProcessingPipeline()
    }

// MARK: - Helper methods

    /// Change the camera toggle positions.
    func toggleCameraSelection() {
        if configuration.cameraPosition == .front {
            configuration = VideoReader.CameraConfiguration(
                position: .back,
                pixelFormat: .bgra32,
                resolution: .high)
        } else {
            configuration = VideoReader.CameraConfiguration(
                position: .front,
                pixelFormat: .bgra32,
                resolution: .high)
        }
    }
    
    /// Start the video-processing pipeline by displaying the poses in the camera frames and
    /// starting the action repetition count prediction stream.
    func startVideoProcessingPipeline() {

        if let displayCameraTask = displayCameraTask {
            displayCameraTask.cancel()
        }

        displayCameraTask = Task {
            // Display poses on top of each camera frame.
            try await self.displayPoseInCamera()
        }

        if predictionTask == nil {
            predictionTask = Task {
                // Predict the action repetition count.
                try await self.predictCount()
            }
        }
    }

    /// Display poses on top of each camera frame.
    func displayPoseInCamera() async throws {
        // Start reading the camera.
        let frameSequence = try await VideoReader.readCamera(
            configuration: configuration
        )
        var lastTime = CFAbsoluteTimeGetCurrent()

        for try await frame in frameSequence {

            if Task.isCancelled {
                return
            }

            // Extract poses in every frame.
            let poses = try await poseExtractor.applied(to: frame.feature)

            // Send poses into another pose stream for additional consumers.
            await poseStream.send(TemporalFeature(id: frame.id, feature: poses))

            // Calculate poses from the image frame and display both.
            if let cgImage = CIContext()
                .createCGImage(frame.feature, from: frame.feature.extent) {
                await display(image: cgImage, poses: poses)
            }

            // Frame rate debug information.
//            print(String(format: "Frame rate %2.2f fps", 1 / (CFAbsoluteTimeGetCurrent() - lastTime)))
            lastTime = CFAbsoluteTimeGetCurrent()
        }
    }
    
    /// Predict the action repetition count.
    func predictCount() async throws {
        
        
//        var rightKnee: CGPoint = CGPoint()
//        var leftKnee: CGPoint = CGPoint()
//        var rightHip: CGPoint = CGPoint()
//        var rightAnkle: CGPoint = CGPoint()
//        var leftAnkle: CGPoint = CGPoint()
//
//        if let livePoses = liveCameraImageAndPoses {
//            for pose in livePoses.poses {
//                if po
//            }
//        }
//
//        let firstAngle = atan2(rightHip.y - rightKnee.y, rightHip.x - rightKnee.x)
//        let secondAngle = atan2(rightAnkle.y - rightKnee.y, rightAnkle.x - rightKnee.x)
//        var angleDiffRadians = firstAngle - secondAngle
//        while angleDiffRadians < 0 {
//            angleDiffRadians += CGFloat(2 * Double.pi)
//        }
//        let angleDiffDegrees = Int(angleDiffRadians * 180 / .pi)
//        print(angleDiffDegrees)
//        if (angleDiffDegrees > 150) && (angleDiffDegrees < 170) && self.wasInBottomPosition {
//
//
//            self.squatCount += 1
//            print("squatCount: \(self.squatCount)")
//            self.wasInBottomPosition = false
//
//        }
//
//        let hipHeight = rightHip.y
//        let kneeHeight = rightKnee.y
//
//
//        if hipHeight < kneeHeight {
//            let deadlineTime = DispatchTime.now() + .seconds(3)
//            DispatchQueue.main.asyncAfter(deadline: deadlineTime){
//                print("true")
//                self.wasInBottomPosition = true
//            }
//        }
//
//
//        let kneeDistance = rightKnee.distance(to: leftKnee)
//        let ankleDistance = rightAnkle.distance(to: leftAnkle)
//
//        if ankleDistance > kneeDistance {
//            self.isGoodPosture = false
//        } else {
//            self.isGoodPosture = true
//        }
        
        
        // Create an asynchronous temporal sequence for the pose stream.
        let poseTemporalSequence = AnyTemporalSequence<[Pose]>(poseStream, count: nil)

        // Apply the repetition-counting transformer pipeline to the incoming pose stream.
        let finalResults = try await actionCounter.count(poseTemporalSequence)

        var lastTime = CFAbsoluteTimeGetCurrent()
        for try await item in finalResults {

            if Task.isCancelled {
                return
            }

            let currentCumulativeCount = item.feature
            // Observe each predicted count (cumulative) and compare it to the previous result.
            if currentCumulativeCount - lastCumulativeCount <= 0.001 {
                // Reset the UI counter to 0 if the cumulative count isn't increasing.
//                uiCount = 0.0
            }

            // Add the incremental count to the UI counter.
            uiCount += currentCumulativeCount - lastCumulativeCount

            // Counter debug information.
//            print("""
//                    Cumulative count \(currentCumulativeCount), last count \(lastCumulativeCount), \
//                    incremental count \(currentCumulativeCount - lastCumulativeCount), UI count \(uiCount)
//                    """)

            // Update and store the last predicted count.
            lastCumulativeCount = currentCumulativeCount

            // Prediction rate debug information.
//            print(String(format: "Count rate %2.2f fps", 1 / (CFAbsoluteTimeGetCurrent() - lastTime)))
            lastTime = CFAbsoluteTimeGetCurrent()
        }
    }

    /// Updates the user interface's image view with the rendered poses.
    /// - Parameters:
    ///   - image: The image frame from the camera.
    ///   - poses: The detected poses to render on-screen.
    /// - Tag: display
    @MainActor func display(image: CGImage, poses: [Pose]) {
        self.liveCameraImageAndPoses = (image, poses)
    }
}

/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A collection of transformers that form a pipeline to continuously count human body actions from a pose stream.
*/

import CreateMLComponents

/// The counter that consists of a transformer pipeline to count action repetitions from a pose stream.
/// - Tag: ActionCounter
struct ActionCounter {
    // Use an optional Downsampler transformer to downsample the
    // incoming frames (that is, effectively speed up the observed actions).
    let pipeline = Downsampler(factor: 3)

    // Use a PoseSelector transformer to choose one pose to count if
    // the system detects multiple poses.
        .appending(PoseSelector(strategy: .maximumBoundingBoxArea))

    // Use an optional JointsSelector transformer to specifically ignore
    // or select a set of joints in a pose to include in counting.
        .appending(JointsSelector(selectedJoints: [.neck, .rightShoulder, .leftShoulder, .leftHip, .rightHip, .leftKnee, .rightKnee]))

    // Use a SlidingWindowTransformer to group frames into windows, and
    // prepare them for prediction.
        .appending(SlidingWindowTransformer<Pose>(stride: 5, length: 90))

    // Use a HumanBodyActionCounter transformer to count actions from
    // each window and produce cumulative counts for the input stream.
        .appending(HumanBodyActionCounter())

    /// Count action repetitions from a pose stream.
    /// - Parameters:
    ///   - poseStream: an asynchronous sequence of poses.
    /// - Returns: An asynchronous sequence of cumulative action counts.
    /// - Tag: count
    
//    func getPipeline(poseStream: AnyTemporalSequence<[Pose]>) -> Downsampler<[Pose]> {
//        let jointsSelector = JointsSelector(selectedJoints: [.neck, .rightShoulder, .leftShoulder, .leftHip, .rightHip, .leftKnee, .rightKnee])
//        let pipeline = Downsampler(factor: 3)
//            .appending(PoseSelector(strategy: .maximumBoundingBoxArea))
//            .appending(jointsSelector)
//            .appending(SlidingWindowTransformer<Pose>(stride: 5, length: 90))
//            .appending(HumanBodyActionCounter())
//        return pipeline(poseStream)
//    }
    
    func count(_ poseStream: AnyTemporalSequence<[Pose]>) async throws -> HumanBodyActionCounter.CumulativeSumSequence {
        return try await pipeline(poseStream)
    }
    
}

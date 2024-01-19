import AgoraRtcKit


public class CallQualityManager: AgoraManager {
    /// A dictionary mapping user IDs to call quality statistics.
    @Published public var callQualities: [UInt: String] = [:]
}

extension CallQualityManager {
    public func rtcEngine(_ engine: AgoraRtcEngineKit, remoteVideoStats stats: AgoraRtcRemoteVideoStats) {
        self.callQualities[stats.uid] = """
        Received Bitrate = \(stats.receivedBitrate)
        Frame = \(stats.width)x\(stats.height), \(stats.receivedFrameRate)fps
        Frame Loss Rate = \(stats.frameLossRate)
        Packet Loss Rate = \(stats.packetLossRate)
        """
    }

    public func rtcEngine(_ engine: AgoraRtcEngineKit, localVideoStats stats: AgoraRtcLocalVideoStats, sourceType: AgoraVideoSourceType) {
        self.callQualities[self.localUserId] = """
        Captured Frame = \(stats.captureFrameWidth)x\(stats.captureFrameHeight), \(stats.captureFrameRate)fps
        Encoded Frame = \(stats.encodedFrameWidth)x\(stats.encodedFrameHeight), \(stats.encoderOutputFrameRate)fps
        Sent Data = \(stats.sentFrameRate)fps, bitrate: \(stats.sentBitrate)
        Packet Loss Rate = \(stats.txPacketLossRate)
        """
    }
}

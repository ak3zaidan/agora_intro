import AgoraRtcKit
import SwiftUI
import Foundation
import AVFoundation

open class AgoraManager: NSObject, ObservableObject {

    public let appId: String
    /// The client's role in the session.
    public var role: AgoraClientRole = .audience {
        didSet { agoraEngine.setClientRole(role) }
    }

    /// The set of all users in the channel.
    @Published public var allUsers: Set<UInt> = []

    @Published var label: String?

    /// Integer ID of the local user.
    @Published public var localUserId: UInt = 0

    // MARK: - Agora Engine Functions

    private var engine: AgoraRtcEngineKit?
    /// The Agora RTC Engine Kit for the session.
    public var agoraEngine: AgoraRtcEngineKit {
        if let engine { return engine }
        let engine = setupEngine()
        self.engine = engine
        return engine
    }

    open func setupEngine() -> AgoraRtcEngineKit {
        let eng = AgoraRtcEngineKit.sharedEngine(withAppId: appId, delegate: self)
//        if DocsAppConfig.shared.product != .voice {
//            eng.enableVideo()
//        } else {
//            eng.enableAudio()
//        }
        eng.enableVideo()
        
        eng.setClientRole(role)
        return eng
    }

    /// Joins a channel, starting the connection to an RTC session.
    /// - Parameters:
    ///   - channel: Name of the channel to join.
    ///   - token: Token to join the channel, this can be nil for an weak security testing session.
    ///   - uid: User ID of the local user. This can be 0 to allow the engine to automatically assign an ID.
    ///   - mediaOptions: AgoraRtcChannelMediaOptions object for join settings
    /// - Returns: Error code, 0 = success, &lt; 0 = failure.
    @discardableResult
    open func joinChannel(
        _ channel: String, token: String? = nil, uid: UInt = 0,
        mediaOptions: AgoraRtcChannelMediaOptions? = nil
    ) async -> Int32 {
        if await !checkForPermissions() {
            await self.updateLabel(key: "invalid-permissions")
            return -3
        }

        if let mediaOptions {
            return self.agoraEngine.joinChannel(
                byToken: token, channelId: channel,
                uid: uid, mediaOptions: mediaOptions
            )
        }
        return self.agoraEngine.joinChannel(
            byToken: token, channelId: channel,
            info: nil, uid: uid
        )
    }

    /// Joins a video call, establishing a connection for video communication.
    /// - Parameters:
    ///   - channel: Name of the channel to join.
    ///   - token: Token to join the channel, this can be nil for a weak security testing session.
    ///   - uid: User ID of the local user. This can be 0 to allow the engine to automatically assign an ID.
    /// - Returns: Error code, 0 = success, &lt; 0 = failure.
    @discardableResult
    func joinVideoCall(
        _ channel: String, token: String? = nil, uid: UInt = 0
    ) async -> Int32 {
        /// See ``AgoraManager/checkForPermissions()``, or Apple's docs for details of this method.
        if await !checkForPermissions() {
            await self.updateLabel(key: "invalid-permissions")
            return -3
        }

        let opt = AgoraRtcChannelMediaOptions()
        opt.channelProfile = .communication

        return self.agoraEngine.joinChannel(
            byToken: token, channelId: channel,
            uid: uid, mediaOptions: opt
        )
    }

    /// Joins a voice call, establishing a connection for audio communication.
    /// - Parameters:
    ///   - channel: Name of the channel to join.
    ///   - token: Token to join the channel, this can be nil for a weak security testing session.
    ///   - uid: User ID of the local user. This can be 0 to allow the engine to automatically assign an ID.
    /// - Returns: Error code, 0 = success, &lt; 0 = failure.
    @discardableResult
    func joinVoiceCall(
        _ channel: String, token: String? = nil, uid: UInt = 0
    ) async -> Int32 {
        /// See ``AgoraManager/checkForPermissions()``, or Apple's docs for details of this method.
        if await !checkForPermissions() {
            await self.updateLabel(key: "invalid-permissions")
            return -3
        }

        let opt = AgoraRtcChannelMediaOptions()
        opt.channelProfile = .communication

        return self.agoraEngine.joinChannel(
            byToken: token, channelId: channel,
            uid: uid, mediaOptions: opt
        )
    }

    /// Joins a broadcast stream, enabling broadcasting or audience mode.
    /// - Parameters:
    ///   - channel: Name of the channel to join.
    ///   - token: Token to join the channel, this can be nil for a weak security testing session.
    ///   - uid: User ID of the local user. This can be 0 to allow the engine to automatically assign an ID.
    ///   - isBroadcaster: Flag to indicate if the user is joining as a broadcaster (true) or audience (false).
    ///                    Defaults to true.
    /// - Returns: Error code, 0 = success, &lt; 0 = failure.
    @discardableResult
    func joinBroadcastStream(
        _ channel: String, token: String? = nil,
        uid: UInt = 0, isBroadcaster: Bool = true
    ) async -> Int32 {
        /// See ``AgoraManager/checkForPermissions()``, or Apple's docs for details of this method.
        if isBroadcaster, await !checkForPermissions() {
            await self.updateLabel(key: "invalid-permissions")
            return -3
        }

        let opt = AgoraRtcChannelMediaOptions()
        opt.channelProfile = .liveBroadcasting
        opt.clientRoleType = isBroadcaster ? .broadcaster : .audience
        opt.audienceLatencyLevel = isBroadcaster ? .ultraLowLatency : .lowLatency

        return self.agoraEngine.joinChannel(
            byToken: token, channelId: channel,
            uid: uid, mediaOptions: opt
        )
    }

    /// Leaves the channel and stops the preview for the session.
    ///
    /// - Parameter leaveChannelBlock: An optional closure that will be called when the client leaves the channel.
    ///      The closure takes an `AgoraChannelStats` object as its parameter.
    ///
    ///
    /// This method also empties all entries in ``allUsers``,
    @discardableResult
    open func leaveChannel(
        leaveChannelBlock: ((AgoraChannelStats) -> Void)? = nil,
        destroyInstance: Bool = true
    ) -> Int32 {
        let leaveErr = self.agoraEngine.leaveChannel(leaveChannelBlock)
        self.agoraEngine.stopPreview()
        defer { if destroyInstance { AgoraRtcEngineKit.destroy() } }
        self.allUsers.removeAll()
        return leaveErr
    }

    public init(appId: String, role: AgoraClientRole = .audience) {
        self.appId = appId
        self.role = role
    }

    @MainActor
    func updateLabel(to message: String) {
        self.label = message
    }

    @MainActor
    func updateLabel(key: String, comment: String = "") {
        self.label = NSLocalizedString(key, comment: comment)
    }
    
    func checkForPermissions() async -> Bool {
        var hasPermissions = await avAuthorization(mediaType: .video)
        if !hasPermissions { return false }
        hasPermissions = await avAuthorization(mediaType: .audio)
        return hasPermissions
    }

    func avAuthorization(mediaType: AVMediaType) async -> Bool {
        let mediaAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: mediaType)
        switch mediaAuthorizationStatus {
            case .denied, .restricted: return false
            case .authorized: return true
            case .notDetermined:
                return await withCheckedContinuation { continuation in
                    AVCaptureDevice.requestAccess(for: mediaType) { granted in
                        continuation.resume(returning: granted)
                    }
                }
            @unknown default: return false
        }
    }
}

extension AgoraManager: AgoraRtcEngineDelegate {

    open func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        self.localUserId = uid
        if self.role == .broadcaster {
            self.allUsers.insert(uid)
        }
    }

    open func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        self.allUsers.insert(uid)
    }

    open func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        self.allUsers.remove(uid)
    }
}

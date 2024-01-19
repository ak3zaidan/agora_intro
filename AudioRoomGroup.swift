import AgoraRtcKit
import SwiftUI
import AVFoundation

struct ScrollingVideoCallView: View {
    @ObservedObject var agoraManager = AgoraManager(appId: "6e03e8fb974041d8b764ddcadf78373e", role: .broadcaster)
    var channelId: String = "main"
    
    var body: some View {
        ScrollView {
            VStack {
                ForEach(Array(agoraManager.allUsers), id: \.self) { uid in
                    AgoraVideoCanvasView(manager: agoraManager, uid: uid)
                        .aspectRatio(contentMode: .fit).cornerRadius(10)
                }
            }.padding(20)
        }
        .onAppear {
            Task {
                //temporary token generated from agora console
                await agoraManager.joinChannel(channelId, token: "007eJxTYBBrip4v8D9oy9Ou1Qd5v1zO01p28mm6qvO507cMOTmzZlQpMJilGhinWqQlWZqbGJgYplgkmZuZpKQkJ6akmVsYmxunbmValdoQyMhQwizPzMgAgSA+C0NuYmYeAwMAeL0fNg==")
            }
        }
        .onDisappear {
            agoraManager.leaveChannel()
        }
    }
}

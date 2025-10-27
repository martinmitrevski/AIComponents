//
//  AIComponentsApp.swift
//  AIComponents
//
//  Created by Martin Mitrevski on 24.10.25.
//

import SwiftUI
import StreamChat
import StreamChatSwiftUI

@main
struct AIComponentsApp: App {
    
    @State var streamChat: StreamChat
    
    var chatClient: ChatClient = {
        var config = ChatClientConfig(apiKey: .init("zcgvnykxsfm8"))
        config.isLocalStorageEnabled = true
        config.applicationGroupIdentifier = "group.io.getstream.iOS.ChatDemoAppSwiftUI"

        let client = ChatClient(config: config)
        return client
    }()
    
    init() {
        _streamChat = State(initialValue: StreamChat(chatClient: chatClient))
        chatClient.connectUser(
            userInfo: UserInfo(
                id: "anakin_skywalker",
                imageURL: URL(string: "https://vignette.wikia.nocookie.net/starwars/images/6/6f/Anakin_Skywalker_RotS.png")
            ),
            token: try! Token(rawValue: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiYW5ha2luX3NreXdhbGtlciJ9.ZwCV1qPrSAsie7-0n61JQrSEDbp6fcMgVh4V2CB0kM8")
        )
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

//
//  ContentView.swift
//  AIComponents
//
//  Created by Martin Mitrevski on 24.10.25.
//

import SwiftUI
import StreamChat
import StreamChatAI
import StreamChatSwiftUI

struct ContentView: View {
    
    @Injected(\.chatClient) var chatClient
    
    @State var text = ""
    @State var channelController: ChatChannelController?
    
    @State var showMessageList = false
        
    var body: some View {
        NavigationStack {
            VStack {
                if showMessageList, let channelController {
                    ConversationView(viewModel: ChatChannelViewModel(channelController: channelController))
                } else {
                    Spacer()
                }
                ComposerView(text: $text) { messageData in
                    if channelController == nil {
                        channelController = try? chatClient.channelController(
                            createChannelWithId: ChannelId(type: .messaging, id: UUID().uuidString)
                        )
                        channelController?.synchronize { _ in
                            channelController?.createNewMessage(text: messageData.text)
                            showMessageList = true
                        }
                    } else {
                        channelController?.createNewMessage(text: messageData.text)
                    }
                    self.text = ""
                }
            }
        }
    }
}

struct ConversationView: View {
    @StateObject var viewModel: ChatChannelViewModel
    
    var body: some View {
        if let channel = viewModel.channel {
            MessageListView(
                factory: AIComponentsViewFactory.shared,
                channel: channel,
                messages: viewModel.messages,
                messagesGroupingInfo: viewModel.messagesGroupingInfo,
                scrolledId: $viewModel.scrolledId,
                showScrollToLatestButton: $viewModel.showScrollToLatestButton,
                quotedMessage: $viewModel.quotedMessage,
                currentDateString: viewModel.currentDateString,
                listId: viewModel.listId,
                isMessageThread: viewModel.isMessageThread,
                shouldShowTypingIndicator: viewModel.shouldShowTypingIndicator,
                scrollPosition: $viewModel.scrollPosition,
                loadingNextMessages: viewModel.loadingNextMessages,
                firstUnreadMessageId: $viewModel.firstUnreadMessageId,
                onMessageAppear: viewModel.handleMessageAppear(index:scrollDirection:),
                onScrollToBottom: viewModel.scrollToLastMessage,
                onLongPress: { displayInfo in },
                onJumpToMessage: viewModel.jumpToMessage(messageId:)
            )
        } else {
            ProgressView()
        }
    }
}

class AIComponentsViewFactory: ViewFactory {
    
    @Injected(\.chatClient) var chatClient: ChatClient
    
    static let shared = AIComponentsViewFactory()
    
    public func makeMessageListBackground(
        colors: ColorPalette,
        isInThread: Bool
    ) -> some View {
        Color.clear
    }
}

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
    @State private var isSplitOpen = false
    @State private var composerHeight: CGFloat = 0
        
    var body: some View {
        NavigationStack {
            SidebarView(
                isOpen: $isSplitOpen,
                excludedBottomHeight: composerHeight,
                menu: {
                    SplitSidebarView(onChannelSelected: handleChannelSelection)
                },
                content: {
                    mainConversation()
                }
            )
        }
    }
    
    private func mainConversation() -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .leading) {
                Color.clear
                    .allowsHitTesting(false)
                
                if showMessageList, let channelController {
                    ConversationView(viewModel: ChatChannelViewModel(channelController: channelController))
                        .id(channelController.cid)
                } else {
                    Color.clear
                        .onChange(of: text) { oldValue, newValue in
                            // already create the channel for faster reply.
                            if text.count > 10 {
                                setupChannel()
                            }
                        }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            
            ComposerView(text: $text) { messageData in
                let attachments = messageData.attachments.compactMap { url in
                    try? AnyAttachmentPayload(localFileURL: url, attachmentType: .image)
                }
                setupChannel {
                    channelController?.createNewMessage(text: messageData.text, attachments: attachments)
                    showMessageList = true
                    
                    if channelController?.channel?.name == nil {
                        Task {
                            let summary = try await AgentService.shared.summarize(text: messageData.text, platform: "openai") //TODO: fix this
                            channelController?.updateChannel(name: summary, imageURL: nil, team: nil)
                        }
                    }
                }
                self.text = ""
            }
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: ComposerHeightPreferenceKey.self, value: proxy.size.height)
                }
            )
            .onPreferenceChange(ComposerHeightPreferenceKey.self) { newHeight in
                composerHeight = newHeight
            }
        }
    }
    
    private func setupChannel(completion: (() -> ())? = nil) {
        if channelController == nil {
            let id = UUID().uuidString
            let channelId = ChannelId(type: .messaging, id: id)
            channelController = try? chatClient.channelController(
                createChannelWithId: channelId
            )
            setupAgent(for: channelController, completion: completion)
        } else {
            completion?()
        }
    }

    private func handleChannelSelection(_ channel: ChatChannel) {
        channelController = chatClient.channelController(for: channel.cid)
        showMessageList = true
        setupAgent(for: channelController)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            isSplitOpen = false
        }
    }
    
    private func setupAgent(
        for channelController: ChatChannelController?,
        completion: (() -> ())? = nil
    ) {
        channelController?.synchronize { _ in
            Task { @MainActor in
                if let id = channelController?.cid?.id {
                    try await AgentService.shared.setupAgent(channelId: id)
                }
                completion?()
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
    let typingIndicatorHandler = TypingIndicatorHandler()
    
    public func makeMessageListBackground(
        colors: ColorPalette,
        isInThread: Bool
    ) -> some View {
        Color.clear
    }
    
    func makeMessageReadIndicatorView(channel: ChatChannel, message: ChatMessage) -> some View {
        EmptyView()
    }
    
    @ViewBuilder
    func makeCustomAttachmentViewType(
        for message: ChatMessage,
        isFirst: Bool,
        availableWidth: CGFloat,
        scrolledId: Binding<String?>
    ) -> some View {
        let isGenerating = message.extraData["generating"]?.boolValue == true
        StreamingMessageView(
            content: message.text,
            isGenerating: isGenerating
        )
        .padding()
    }
    
    func makeMessageListContainerModifier() -> some ViewModifier {
        CustomMessageListContainerModifier(typingIndicatorHandler: typingIndicatorHandler)
    }
    
    func makeEmptyMessagesView(
        for channel: ChatChannel,
        colors: ColorPalette
    ) -> some View {
        AIAgentOverlayView(typingIndicatorHandler: typingIndicatorHandler)
    }
}

class CustomMessageResolver: MessageTypeResolving {
    
    func hasCustomAttachment(message: ChatMessage) -> Bool {
        message.extraData["ai_generated"] == true
    }
}


private struct SplitSidebarView: View {
    
    let onChannelSelected: (ChatChannel) -> Void
    @StateObject private var viewModel = ChatChannelListViewModel()
    
    var body: some View {
        VStack {
            ConversationListView(
                viewModel: viewModel,
                onChannelSelected: onChannelSelected
            )
        }
        .padding(.top, 40)
    }
}

struct ConversationListView: View {
    
    @ObservedObject var viewModel: ChatChannelListViewModel
    var onChannelSelected: (ChatChannel) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack {
                HStack {
                    Text("Conversations")
                        .font(.headline)
                    
                    Spacer()
                }
                .padding()

                ForEach(viewModel.channels) { channel in
                    HStack {
                        Text(channel.name ?? channel.id)
                            .multilineTextAlignment(.leading)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onChannelSelected(channel)
                    }
                    .onAppear {
                        if let index = viewModel.channels.firstIndex(of: channel) {
                            viewModel.checkForChannels(index: index)
                        }
                    }
                }
            }
        }
    }
}

private struct ComposerHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct CustomMessageListContainerModifier: ViewModifier {
    
    @ObservedObject var typingIndicatorHandler: TypingIndicatorHandler
    
    func body(content: Content) -> some View {
        content.overlay {
            AIAgentOverlayView(typingIndicatorHandler: typingIndicatorHandler)
        }
    }
}

struct AIAgentOverlayView: View {
    
    @ObservedObject var typingIndicatorHandler: TypingIndicatorHandler
    
    var body: some View {
        VStack {
            Spacer()
            if typingIndicatorHandler.typingIndicatorShown {
                HStack {
                    AITypingIndicatorView(text: typingIndicatorHandler.state)
                    Spacer()
                }
                .padding()
                .frame(height: 80)
                .background(Color(UIColor.secondarySystemBackground))
            }
        }
    }
}

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
    @State private var dragOffset: CGFloat = 0
    @State private var composerHeight: CGFloat = 0
    @State private var isSplitDragActive = false

    private let splitWidthRatio: CGFloat = 0.82
    private let edgeActivationWidth: CGFloat = 32
        
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let splitWidth = geometry.size.width * splitWidthRatio
                let clampedDrag = max(-splitWidth, min(splitWidth, dragOffset))
                let mainOffset = isSplitOpen ? (splitWidth + min(0, clampedDrag)) : max(0, clampedDrag)
                let panelOffset = isSplitOpen ? min(0, clampedDrag) : (-splitWidth + max(0, clampedDrag))
                let availableHeight = max(0, geometry.size.height - composerHeight)
                
                ZStack(alignment: .leading) {
                    mainConversation(
                        splitWidth: splitWidth,
                        availableHeight: availableHeight
                    )
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .offset(x: mainOffset)
                    
                    if isSplitOpen {
                        Color.black.opacity(0.25)
                            .ignoresSafeArea()
                            .onTapGesture {
                                closeSplitView()
                            }
                            .gesture(
                                splitDragGesture(
                                    splitWidth: splitWidth,
                                    availableHeight: nil
                                )
                            )
                    }
                    
                    if isSplitOpen || clampedDrag > 0 {
                        SplitSidebarView(onChannelSelected: handleChannelSelection)
                            .frame(width: splitWidth)
                            .offset(x: panelOffset)
                            .transition(.move(edge: .leading))
                            .shadow(color: .black.opacity(0.15), radius: 12, x: 4, y: 0)
                            .background(Color.white)
                    }
                }
                .animation(.spring(response: 0.28, dampingFraction: 0.85), value: isSplitOpen)
                .animation(.spring(response: 0.28, dampingFraction: 0.85), value: dragOffset)
            }
        }
    }
    
    private func mainConversation(splitWidth: CGFloat, availableHeight: CGFloat) -> some View {
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
            .simultaneousGesture(
                splitDragGesture(
                    splitWidth: splitWidth,
                    availableHeight: availableHeight
                ),
                including: .gesture
            )
            
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
            channelController?.synchronize { _ in
                Task { @MainActor in
                    try await AgentService.shared.setupAgent(channelId: id)
                    completion?()
                }
            }
        } else {
            completion?()
        }
    }
    
    private func splitDragGesture(splitWidth: CGFloat, availableHeight: CGFloat?) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                
                if !isSplitOpen && !isSplitDragActive && value.startLocation.x > edgeActivationWidth {
                    return
                }
                
                if let availableHeight, value.startLocation.y > availableHeight {
                    return
                }
                if abs(horizontal) < abs(vertical) {
                    return
                }
                
                if !isSplitDragActive {
                    isSplitDragActive = true
                }
                
                if isSplitOpen {
                    dragOffset = min(0, horizontal)
                } else if horizontal > 0 {
                    dragOffset = horizontal
                }
            }
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                
                defer {
                    dragOffset = 0
                    isSplitDragActive = false
                }
                
                if !isSplitOpen && value.startLocation.x > edgeActivationWidth {
                    return
                }
                if let availableHeight, value.startLocation.y > availableHeight {
                    return
                }
                if abs(horizontal) < abs(vertical) {
                    return
                }
                if isSplitOpen {
                    if horizontal < -splitWidth * 0.2 {
                        closeSplitView(animated: true)
                    }
                } else if horizontal > splitWidth * 0.2 {
                    openSplitView()
                }
            }
    }
    
    private func openSplitView() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            isSplitOpen = true
            dragOffset = 0
        }
    }
    
    private func closeSplitView(animated: Bool = false) {
        let animation: Animation? = animated ? .spring(response: 0.28, dampingFraction: 0.85) : nil
        if let animation {
            withAnimation(animation) {
                isSplitOpen = false
            }
        } else {
            isSplitOpen = false
        }
        dragOffset = 0
    }

    private func handleChannelSelection(_ channel: ChatChannel) {
        let controller = chatClient.channelController(for: channel.cid)
        channelController = controller
        showMessageList = true
        controller.synchronize { _ in }
        closeSplitView(animated: true)
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
        StreamingMessageView(
            content: message.text,
            isGenerating: false //TODO: check this.
        )
        .padding()
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

// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import SwiftUI

public struct AIChatView: View {
    @StateObject private var viewModel: AIChatViewModel
    @FocusState private var inputFocused: Bool

    public init(viewModel: AIChatViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        HSplitView {
            conversationList
                .frame(minWidth: 190, idealWidth: 220, maxWidth: 280)
            chatPane
                .frame(minWidth: 440)
        }
        .frame(minWidth: 700, minHeight: 480)
        .onAppear { inputFocused = true }
    }

    private var conversationList: some View {
        VStack(spacing: 10) {
            HStack {
                Text("AI Chat")
                    .font(.headline)
                Spacer()
                Button(action: viewModel.newChat) {
                    Image(systemName: "square.and.pencil")
                }
                .buttonStyle(.plain)
                .help("New Chat")
            }

            TextField("Search chats", text: $viewModel.conversationSearch)
                .textFieldStyle(.roundedBorder)

            List(selection: $viewModel.activeConversationID) {
                ForEach(viewModel.filteredConversations) { conversation in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(conversation.title)
                            .lineLimit(1)
                        Text(conversation.provider.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(conversation.id)
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.selectConversation(conversation.id) }
                    .contextMenu {
                        Button("Delete Chat", role: .destructive) {
                            viewModel.deleteConversation(conversation.id)
                        }
                    }
                }
            }
            .overlay {
                if viewModel.filteredConversations.isEmpty {
                    ContentUnavailableView(
                        "No Conversations",
                        systemImage: "bubble.left.and.bubble.right"
                    )
                }
            }
        }
        .padding(12)
    }

    private var chatPane: some View {
        VStack(spacing: 0) {
            providerBar
            Divider()
            messages
            Divider()
            composer
        }
    }

    private var providerBar: some View {
        HStack {
            Picker("Provider", selection: $viewModel.selectedProvider) {
                ForEach(viewModel.availableProviders) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }
            .labelsHidden()

            Picker("Model", selection: $viewModel.selectedModel) {
                ForEach(viewModel.models) { model in
                    Text(model.name).tag(model.id)
                }
            }
            .labelsHidden()
            .frame(maxWidth: 260)

            Spacer()

            if viewModel.isStreaming {
                Button("Stop", action: viewModel.stop)
                    .keyboardShortcut(".", modifiers: .command)
            }
        }
        .padding(10)
    }

    private var messages: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if viewModel.visibleMessages.isEmpty && !viewModel.isStreaming {
                        ContentUnavailableView(
                            "Ask AI Anything",
                            systemImage: "sparkles",
                            description: Text("Start typing to begin a conversation")
                        )
                        .frame(maxWidth: .infinity, minHeight: 280)
                    }

                    ForEach(viewModel.visibleMessages) { message in
                        messageRow(message)
                            .id(message.id)
                    }

                    if viewModel.isStreaming {
                        messageRow(
                            AIChatMessage(
                                role: .assistant,
                                content: viewModel.streamingContent
                            ),
                            streaming: true
                        )
                        .id("streaming")
                    }
                }
                .padding(18)
            }
            .onChange(of: viewModel.visibleMessages.count) {
                scrollToBottom(proxy)
            }
            .onChange(of: viewModel.streamingContent) {
                scrollToBottom(proxy)
            }
        }
    }

    private func messageRow(_ message: AIChatMessage, streaming: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: message.role == .user ? "person.crop.circle" : "sparkles")
                .foregroundStyle(message.role == .user ? Color.secondary : Color.accentColor)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 6) {
                Text(message.role == .user ? "You" : "Assistant")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                if message.content.isEmpty && streaming {
                    ProgressView()
                        .controlSize(.small)
                } else if message.role == .assistant {
                    MarkdownText(message.content)
                        .textSelection(.enabled)
                } else {
                    Text(message.content)
                        .textSelection(.enabled)
                }

                if message.cancelled {
                    Text("Stopped")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack(alignment: .bottom, spacing: 8) {
                TextField("Ask AI anything", text: $viewModel.input, axis: .vertical)
                    .lineLimit(1...6)
                    .textFieldStyle(.roundedBorder)
                    .focused($inputFocused)
                    .onSubmit(viewModel.send)
                    .disabled(viewModel.isStreaming)

                Button(action: viewModel.send) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .disabled(
                    viewModel.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || viewModel.isStreaming
                )
            }
        }
        .padding(12)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.15)) {
            if viewModel.isStreaming {
                proxy.scrollTo("streaming", anchor: .bottom)
            } else if let last = viewModel.visibleMessages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}

private struct MarkdownText: View {
    let source: String

    init(_ source: String) {
        self.source = source
    }

    var body: some View {
        if let attributed = try? AttributedString(markdown: source) {
            Text(attributed)
        } else {
            Text(source)
        }
    }
}

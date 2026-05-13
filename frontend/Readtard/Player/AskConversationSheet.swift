//
//  AskConversationSheet.swift
//  Readtard
//

import Combine
import SwiftUI

struct AskConversationSheet: View {
    let context: AskSheetContext
    let onClose: () -> Void
    @StateObject private var conversation = AskConversationController()
    @FocusState private var isInputFocused: Bool
    @GestureState private var dragOffset: CGFloat = 0
    @State private var keyboardHeight: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(.white.opacity(0.64))
                .frame(width: 42, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 8)

            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.bottom, 14)

            ScrollViewReader { scrollProxy in
                ZStack(alignment: .bottom) {
                    ScrollView {
                        VStack(spacing: 18) {
                            headerCard

                            LazyVStack(spacing: 12) {
                                ForEach(conversation.messages) { message in
                                    AskMessageBubble(
                                        message: message,
                                        theme: sheetTheme
                                    )
                                    .id(message.id)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.top, 12)
                        .padding(.bottom, 104 + keyboardHeight)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: conversation.messages.count) { _, _ in
                        guard let lastMessageID = conversation.messages.last?.id else {
                            return
                        }

                        withAnimation(.easeOut(duration: 0.2)) {
                            scrollProxy.scrollTo(lastMessageID, anchor: .bottom)
                        }
                    }
                    .onTapGesture {
                        isInputFocused = false
                    }

                    composer
                }
            }
        }
        .background(backgroundLayer)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
        .padding(.top, 18)
        .ignoresSafeArea(edges: .bottom)
        .ignoresSafeArea(.keyboard)
        .offset(y: max(dragOffset, 0))
        .gesture(dismissGesture)
        .task {
            conversation.configure(context: context)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
                return
            }

            withAnimation(.easeOut(duration: 0.25)) {
                keyboardHeight = frame.height
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) {
                keyboardHeight = 0
            }
        }
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
    }

    private var headerCard: some View {
        VStack(spacing: 14) {
            Capsule()
                .fill(.white.opacity(0.96))
                .frame(width: 104, height: 54)
                .overlay {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.85))
                }

            Text("What do you want to ask?")
                .font(.system(size: 23, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)

            Text(supportLine)
                .font(.system(size: 15, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.62))

            if let contextSummary = conversation.contextSummary {
                Text(contextSummary)
                    .font(.system(size: 13, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.52))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField(composerPlaceholder, text: $conversation.draft, axis: .vertical)
                .focused($isInputFocused)
                .lineLimit(1...5)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(sheetTheme.backgroundBottom.opacity(0.34))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                }
                .foregroundStyle(.white)

            Button {
                conversation.sendCurrentQuestion()
            } label: {
                Group {
                    if conversation.isSending {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 18, weight: .bold))
                    }
                }
                .frame(width: 52, height: 52)
                .background(sheetTheme.coverStripe)
                .foregroundStyle(.white)
                .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(conversation.isSending || conversation.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(conversation.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, max(12, keyboardHeight + 12))
        .background(.ultraThinMaterial)
    }

    private var title: String {
        switch context.source {
        case .audiobook:
            return "Audiobook · Ask"
        case .ebook:
            return "Ebook · Ask"
        }
    }

    private var supportLine: String {
        switch context.source {
        case .audiobook:
            return "Answers are based on what you've heard so far."
        case .ebook:
            return "Answers are based on your selected passage."
        }
    }

    private var composerPlaceholder: String {
        switch context.source {
        case .audiobook:
            return "Ask about what you just heard..."
        case .ebook:
            return "Ask about what you're reading..."
        }
    }

    private var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .updating($dragOffset) { value, state, _ in
                if value.translation.height > 0 {
                    state = value.translation.height
                }
            }
            .onEnded { value in
                if value.translation.height > 140 || value.predictedEndTranslation.height > 220 {
                    isInputFocused = false
                    onClose()
                }
            }
    }

    private var sheetTheme: PlayerTheme {
        context.book.theme
    }

    private var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: [
                    sheetTheme.backgroundTop,
                    sheetTheme.backgroundBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [
                    Color.black.opacity(0.10),
                    Color.black.opacity(0.28)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    sheetTheme.coverStripe.opacity(0.24),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 320
            )
        }
    }

    private var cardBackground: some ShapeStyle {
        LinearGradient(
            colors: [
                sheetTheme.backgroundTop.opacity(0.32),
                sheetTheme.backgroundBottom.opacity(0.24)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct AskMessageBubble: View {
    let message: AskMessage
    let theme: PlayerTheme

    var body: some View {
        HStack {
            if message.role == .assistant {
                bubble
                Spacer(minLength: 42)
            } else {
                Spacer(minLength: 42)
                bubble
            }
        }
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(message.role.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.46))

            Text(message.text)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var background: Color {
        switch message.role {
        case .assistant:
            return theme.backgroundBottom.opacity(0.34)
        case .user:
            return theme.coverStripe.opacity(0.76)
        }
    }
}

#Preview {
    AskConversationSheet(
        context: AskSheetContext(
            source: .audiobook,
            book: Audiobook(
                folderName: "Preview",
                backendBookID: "Preview",
                backendEpubFilename: nil,
                title: "Preview Book",
                author: "Preview Author",
                publisher: "Preview Publisher",
                badge: "Sample",
                duration: 300,
                coverImageFileName: nil,
                audioFileName: nil,
                audioFileExtension: nil,
                ebookFileName: nil,
                ebookFileExtension: nil,
                theme: PlayerTheme(
                    backgroundTop: Color(red: 0.20, green: 0.08, blue: 0.12),
                    backgroundBottom: Color(red: 0.11, green: 0.04, blue: 0.07),
                    coverStripe: Color(red: 0.66, green: 0.18, blue: 0.24)
                )
            ),
            currentTime: 52,
            duration: 300,
            currentPage: nil,
            totalPages: nil,
            ebookSelectionLocator: nil
        ),
        onClose: {}
    )
}

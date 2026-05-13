//
//  AskConversationController.swift
//  Readtard
//

import Combine
import Foundation

enum AskSource: Equatable {
    case audiobook
    case ebook

    var title: String {
        switch self {
        case .audiobook:
            return "audiobook"
        case .ebook:
            return "ebook"
        }
    }
}

struct AskSheetContext {
    let source: AskSource
    let book: Audiobook
    let currentTime: TimeInterval?
    let duration: TimeInterval?
    let currentPage: Int?
    let totalPages: Int?
    let ebookSelectionLocator: EbookLocator?
}

@MainActor
final class AskConversationController: ObservableObject {
    @Published var messages: [AskMessage] = []
    @Published var draft = ""
    @Published var isSending = false
    @Published private(set) var contextSummary: String?

    private let apiClient: ReadtardAPIClient
    private var context: AskContext?

    init() {
        self.apiClient = ReadtardAPIClient()
    }

    init(apiClient: ReadtardAPIClient) {
        self.apiClient = apiClient
    }

    func configure(context: AskSheetContext?) {
        guard messages.isEmpty else {
            return
        }

        guard let context else {
            contextSummary = "I could not load the current book context yet."
            return
        }

        self.context = AskContext(
            source: context.source,
            title: context.book.title,
            author: context.book.author,
            publisher: context.book.publisher,
            bookID: context.book.backendBookID,
            currentTime: context.currentTime,
            duration: context.duration,
            currentPage: context.currentPage,
            totalPages: context.totalPages,
            ebookSelectionLocator: context.ebookSelectionLocator
        )

        switch context.source {
        case .audiobook:
            contextSummary = "\(context.book.title) · Audiobook · \(formattedTime(context.currentTime ?? 0))"
        case .ebook:
            let currentPage = context.currentPage ?? 1
            let totalPages = context.totalPages ?? 1
            contextSummary = "\(context.book.title) · Ebook · Page \(currentPage) of \(totalPages)"
        }
    }

    func sendCurrentQuestion() {
        let trimmedDraft = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDraft.isEmpty, !isSending else {
            return
        }

        draft = ""
        isSending = true
        messages.append(AskMessage(role: .user, text: trimmedDraft))

        let responseContext = context

        Task {
            defer { isSending = false }

            guard let responseContext else {
                messages.append(AskMessage(role: .assistant, text: "The ask assistant is not ready because the book context is missing."))
                return
            }

            do {
                if responseContext.source == .ebook, responseContext.ebookSelectionLocator == nil {
                    messages.append(AskMessage(role: .assistant, text: "I could not extract readable text from this page yet. Try turning a page and ask again."))
                    return
                }

                let request = responseContext.makeRequest(question: trimmedDraft)
                debugPrintRequest(request)
                let response = try await apiClient.ask(request)
                messages.append(AskMessage(role: .assistant, text: response.answer))
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                messages.append(AskMessage(role: .assistant, text: message))
            }
        }
    }

    private func formattedTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds.rounded(.down))
        let minutes = totalSeconds / 60
        let remainder = totalSeconds % 60
        return String(format: "%d:%02d", minutes, remainder)
    }

    private func debugPrintRequest(_ request: AskRequest) {
        #if DEBUG
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard
            let data = try? encoder.encode(request),
            let json = String(data: data, encoding: .utf8)
        else {
            print("=== ASK REQUEST PAYLOAD ===")
            print("Unable to encode ask request for debug output.")
            print("===========================")
            return
        }

        print("=== ASK REQUEST PAYLOAD ===")
        print(json)
        print("===========================")
        #endif
    }
}

struct AskMessage: Identifiable {
    enum Role {
        case assistant
        case user

        var title: String {
            switch self {
            case .assistant:
                return "Assistant"
            case .user:
                return "You"
            }
        }
    }

    let id = UUID()
    let role: Role
    let text: String
}

private struct AskContext {
    let source: AskSource
    let title: String
    let author: String
    let publisher: String
    let bookID: String
    let currentTime: TimeInterval?
    let duration: TimeInterval?
    let currentPage: Int?
    let totalPages: Int?
    let ebookSelectionLocator: EbookLocator?

    func makeRequest(question: String) -> AskRequest {
        switch source {
        case .audiobook:
            return AskRequest(
                bookID: bookID,
                source: source.title,
                question: question,
                ebook: nil,
                audiobook: .init(timestampSec: currentTime ?? 0)
            )
        case .ebook:
            return AskRequest(
                bookID: bookID,
                source: source.title,
                question: question,
                ebook: .init(kind: "locator", locator: ebookSelectionLocator),
                audiobook: nil
            )
        }
    }
}

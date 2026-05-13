//
//  ContentView.swift
//  Readtard
//
//  Created by Daan Barsukoff Poniatowsky on 06/04/2026.
//

import SwiftUI

struct ContentView: View {
    private enum ReadingMode {
        case library
        case audiobook
        case ebook
    }

    @StateObject private var player = AudioPlayerController()
    @StateObject private var ebookReader = EbookReaderController()
    @StateObject private var progressStore = ReadingProgressStore()
    private let apiClient = ReadtardAPIClient()
    @State private var books: [Audiobook] = []
    @State private var currentBook: Audiobook?
    @State private var isAskSheetPresented = false
    @State private var askContext: AskSheetContext?
    @State private var readingMode: ReadingMode = .library
    @State private var libraryError: String?
    @GestureState private var audiobookDragOffset: CGFloat = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: backgroundColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if readingMode == .library {
                if books.isEmpty {
                    MissingAudiobookView(message: libraryError ?? "No books found in Book/.")
                        .padding(24)
                } else {
                    LibraryView(
                        books: books,
                        progressStore: progressStore,
                        onSelectBook: openBook
                    )
                }
            } else if let book = currentBook {
                if readingMode == .audiobook {
                    if book.hasAudiobook {
                        AudiobookPlayerView(
                            player: player,
                            onAskTapped: presentAskSheet,
                            onSwitchMode: switchToEbook
                        )
                        .padding(.horizontal, 20)
                        .padding(.vertical, 24)
                        .offset(y: audiobookDragOffset)
                        .gesture(audiobookDismissGesture)
                    } else {
                        MissingModeView(
                            book: book,
                            message: "No audiobook loaded for \(book.title)",
                            buttonTitle: "Switch to ebook",
                            action: switchToEbook
                        )
                        .padding(24)
                    }
                } else if readingMode == .ebook {
                    EbookReaderView(
                        reader: ebookReader,
                        book: book,
                        onAskTapped: presentAskSheetFromEbook,
                        onSwitchToAudiobook: switchToAudiobook,
                        onReturnToLibrary: returnToLibrary
                    )
                }
            } else {
                MissingAudiobookView(message: player.loadingError ?? "Unable to load audiobook.")
                    .padding(24)
            }

            if isAskSheetPresented, let askContext {
                Color.black.opacity(0.18)
                    .ignoresSafeArea()
                    .transition(.opacity)

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    AskConversationSheet(
                        context: askContext,
                        onClose: dismissAskSheet
                    )
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(1)
            }
        }
        .ignoresSafeArea(.keyboard)
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: isAskSheetPresented)
        .onAppear {
            resetToLibrary()
        }
        .onChange(of: player.currentTime) { _, newValue in
            guard
                readingMode == .audiobook,
                let currentBook,
                currentBook.hasAudiobook
            else {
                return
            }

            progressStore.recordAudiobookProgress(
                for: currentBook,
                currentTime: newValue,
                duration: player.duration
            )
        }
        .onChange(of: ebookReader.currentPageNumber) { _, newValue in
            guard
                readingMode == .ebook,
                let currentBook,
                currentBook.hasEbook
            else {
                return
            }

            progressStore.recordEbookProgress(
                for: currentBook,
                currentPage: newValue,
                totalPages: ebookReader.totalPages,
                locatorJSON: ebookReader.currentLocatorJSON
            )
        }
        .task {
            await loadLibrary()
        }
    }

    private var backgroundColors: [Color] {
        if let theme = player.book?.theme {
            return [theme.backgroundTop, theme.backgroundBottom]
        }

        return [Color(red: 0.14, green: 0.06, blue: 0.09), Color(red: 0.08, green: 0.03, blue: 0.05)]
    }

    private func presentAskSheet() {
        guard let book = currentBook else {
            return
        }

        player.pausePlayback()
        askContext = AskSheetContext(
            source: .audiobook,
            book: book,
            currentTime: player.currentTime,
            duration: player.duration,
            currentPage: nil,
            totalPages: nil,
            ebookSelectionLocator: nil
        )
        isAskSheetPresented = true
    }

    private func presentAskSheetFromEbook() {
        guard let book = currentBook else {
            return
        }

        Task {
            let askLocator = await ebookReader.askLocatorFromLastVisibleWords()

            askContext = AskSheetContext(
                source: .ebook,
                book: book,
                currentTime: nil,
                duration: nil,
                currentPage: ebookReader.currentPageNumber,
                totalPages: ebookReader.totalPages,
                ebookSelectionLocator: askLocator ?? ebookReader.selectedAskLocator
            )
            isAskSheetPresented = true
        }
    }

    private func dismissAskSheet() {
        isAskSheetPresented = false
        askContext = nil
    }

    private func loadLibrary() async {
        do {
            let bundledBooks = try AudiobookLoader.loadBundledBooks()
            let syncedBooks = try await syncBooksWithBackend(bundledBooks)
            books = syncedBooks
            libraryError = nil
        } catch {
            books = []
            libraryError = error.localizedDescription
        }
    }

    private func openBook(_ book: Audiobook) {
        currentBook = book
        if book.hasAudiobook {
            player.load(book: book)
            if let resumeTime = progressStore.audiobookResumeTime(for: book) {
                player.seek(to: resumeTime)
            }
            readingMode = .audiobook
        } else {
            Task {
                let resolvedBook = await ensureBackendEpubIfNeeded(for: book)
                if currentBook?.folderName == book.folderName {
                    currentBook = resolvedBook
                }
                ebookReader.load(
                    from: resolvedBook,
                    resumeLocatorJSON: progressStore.ebookResumeLocatorJSON(for: resolvedBook)
                )
                readingMode = .ebook
            }
        }
    }

    private func switchToEbook() {
        dismissAskSheet()
        if let book = currentBook {
            Task {
                let resolvedBook = await ensureBackendEpubIfNeeded(for: book)
                if currentBook?.folderName == book.folderName {
                    currentBook = resolvedBook
                }
                ebookReader.load(
                    from: resolvedBook,
                    resumeLocatorJSON: progressStore.ebookResumeLocatorJSON(for: resolvedBook)
                )
            }
        }
        readingMode = .ebook
    }

    private func switchToAudiobook() {
        if let book = currentBook {
            player.load(book: book)
            if let resumeTime = progressStore.audiobookResumeTime(for: book) {
                player.seek(to: resumeTime)
            }
        }
        readingMode = .audiobook
    }

    private var audiobookDismissGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($audiobookDragOffset) { value, state, _ in
                if value.translation.height > 0 {
                    state = value.translation.height
                }
            }
            .onEnded { value in
                let shouldDismiss =
                    value.translation.height > 140 ||
                    value.predictedEndTranslation.height > 220

                if shouldDismiss {
                    returnToLibrary()
                }
            }
    }

    private func returnToLibrary() {
        dismissAskSheet()
        player.pausePlayback()
        ebookReader.reset()
        currentBook = nil
        readingMode = .library
    }

    private func resetToLibrary() {
        dismissAskSheet()
        player.unloadBook()
        ebookReader.reset()
        currentBook = nil
        readingMode = .library
    }

    private func syncBooksWithBackend(_ localBooks: [Audiobook]) async throws -> [Audiobook] {
        let backendBooks = try await apiClient.listBooks().books
        let byID = Dictionary(uniqueKeysWithValues: backendBooks.map { ($0.id, $0) })
        let byNormalizedTitle = Dictionary(uniqueKeysWithValues: backendBooks.compactMap { item -> (String, BookListItem)? in
            guard let title = item.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else {
                return nil
            }
            return (title.lowercased(), item)
        })

        return localBooks.map { book in
            if let exact = byID[book.folderName] {
                return book.updatingBackendInfo(bookID: exact.id, epubFilename: exact.epubFilename)
            }

            let titleKey = book.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if let titleMatch = byNormalizedTitle[titleKey] {
                return book.updatingBackendInfo(bookID: titleMatch.id, epubFilename: titleMatch.epubFilename)
            }

            return book
        }
    }

    private func ensureBackendEpubIfNeeded(for book: Audiobook) async -> Audiobook {
        guard
            book.ebookURL == nil,
            let backendEpubFilename = book.backendEpubFilename
        else {
            return book
        }

        do {
            _ = try await apiClient.downloadEpub(bookID: book.backendBookID, fileName: backendEpubFilename)
            return book
        } catch {
            libraryError = "Could not download ebook for \(book.title): \(error.localizedDescription)"
            return book
        }
    }
}

#Preview {
    ContentView()
}

private struct MissingAudiobookView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))

            Text("Book files not found")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)

            Text(message)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(.center)
        }
    }
}
private struct MissingModeView: View {
    let book: Audiobook
    let message: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Spacer(minLength: 24)

                ArtworkCard(book: book)

                Text(message)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .multilineTextAlignment(.center)

                Button(buttonTitle) {
                    action()
                }
                .font(.system(size: 18, weight: .semibold))
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.12))
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .buttonStyle(.plain)

                Spacer(minLength: 24)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
}

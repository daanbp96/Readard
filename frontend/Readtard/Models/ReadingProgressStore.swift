//
//  ReadingProgressStore.swift
//  Readtard
//

import Combine
import Foundation

@MainActor
final class ReadingProgressStore: ObservableObject {
    @Published private(set) var entries: [String: ReadingProgressEntry] = [:]

    private let userDefaultsKey = "ReadingProgressStore.entries"

    init() {
        loadEntries()
    }

    func percentage(for book: Audiobook) -> Int {
        let progress = entries[book.folderName]?.displayProgress ?? 0
        return Int((progress * 100).rounded())
    }

    func recordAudiobookProgress(for book: Audiobook, currentTime: TimeInterval, duration: TimeInterval) {
        guard duration > 0 else {
            return
        }

        var entry = entries[book.folderName] ?? ReadingProgressEntry()
        let normalizedTime = min(max(currentTime, 0), duration)
        entry.audiobookTime = normalizedTime
        entry.audiobookProgress = min(max(normalizedTime / duration, 0), 1)
        save(entry, for: book.folderName)
    }

    func recordEbookProgress(
        for book: Audiobook,
        currentPage: Int,
        totalPages: Int,
        locatorJSON: String?
    ) {
        guard totalPages > 0 else {
            return
        }

        var entry = entries[book.folderName] ?? ReadingProgressEntry()
        let normalizedPage = min(max(currentPage, 1), totalPages)
        entry.ebookPage = normalizedPage
        entry.ebookTotalPages = totalPages
        entry.ebookProgress = min(max(Double(normalizedPage) / Double(totalPages), 0), 1)
        entry.ebookLocatorJSON = locatorJSON
        save(entry, for: book.folderName)
    }

    func audiobookResumeTime(for book: Audiobook) -> TimeInterval? {
        entries[book.folderName]?.audiobookTime
    }

    func ebookResumeLocatorJSON(for book: Audiobook) -> String? {
        entries[book.folderName]?.ebookLocatorJSON
    }

    private func save(_ entry: ReadingProgressEntry, for folderName: String) {
        entries[folderName] = entry

        guard let data = try? JSONEncoder().encode(entries) else {
            return
        }

        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }

    private func loadEntries() {
        guard
            let data = UserDefaults.standard.data(forKey: userDefaultsKey),
            let decodedEntries = try? JSONDecoder().decode([String: ReadingProgressEntry].self, from: data)
        else {
            entries = [:]
            return
        }

        entries = decodedEntries
    }
}

struct ReadingProgressEntry: Codable, Equatable {
    var audiobookProgress: Double?
    var audiobookTime: TimeInterval?
    var ebookProgress: Double?
    var ebookPage: Int?
    var ebookTotalPages: Int?
    var ebookLocatorJSON: String?

    var displayProgress: Double {
        max(audiobookProgress ?? 0, ebookProgress ?? 0)
    }
}

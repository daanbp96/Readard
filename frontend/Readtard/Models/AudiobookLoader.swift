//
//  AudiobookLoader.swift
//  Readtard
//

import Foundation

enum AudiobookLoader {
    static func loadBundledBooks() throws -> [Audiobook] {
        let bookDirectoryURL = try bookDirectoryURL()
        let fileManager = FileManager.default
        let bookFolderURLs = try fileManager.contentsOfDirectory(
            at: bookDirectoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        .filter { folderURL in
            (try? folderURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

        guard !bookFolderURLs.isEmpty else {
            throw AudiobookLoaderError.missingMetadata
        }

        return try bookFolderURLs.map(loadBook(from:))
    }

    private static func bookDirectoryURL() throws -> URL {
        guard let bookDirectoryURL = Bundle.main.resourceURL?.appendingPathComponent("Book") else {
            throw AudiobookLoaderError.missingMetadata
        }

        return bookDirectoryURL
    }

    private static func loadBook(from bookFolderURL: URL) throws -> Audiobook {
        let metadataURL = bookFolderURL.appendingPathComponent("metadata.json")
        let data = try Data(contentsOf: metadataURL)
        let metadata = try JSONDecoder().decode(AudiobookMetadata.self, from: data)

        return Audiobook(
            folderName: bookFolderURL.lastPathComponent,
            backendBookID: bookFolderURL.lastPathComponent,
            backendEpubFilename: nil,
            title: metadata.title,
            author: metadata.author,
            publisher: metadata.publisher,
            badge: metadata.badge,
            duration: metadata.durationSeconds ?? 0,
            coverImageFileName: metadata.coverImageFileName,
            audioFileName: metadata.audioFileName,
            audioFileExtension: metadata.audioFileExtension,
            ebookFileName: metadata.ebookFileName,
            ebookFileExtension: metadata.ebookFileExtension,
            theme: PlayerTheme(
                backgroundTop: .fromHex(metadata.theme.backgroundTopHex),
                backgroundBottom: .fromHex(metadata.theme.backgroundBottomHex),
                coverStripe: .fromHex(metadata.theme.coverStripeHex)
            )
        )
    }
}

enum AudiobookLoaderError: LocalizedError {
    case missingMetadata

    var errorDescription: String? {
        switch self {
        case .missingMetadata:
            return "Missing Book/<BookName>/metadata.json in the app bundle."
        }
    }
}

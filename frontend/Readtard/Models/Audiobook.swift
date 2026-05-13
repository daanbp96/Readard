//
//  Audiobook.swift
//  Readtard
//

import Foundation

struct Audiobook {
    let folderName: String
    let backendBookID: String
    let backendEpubFilename: String?
    let title: String
    let author: String
    let publisher: String
    let badge: String
    let duration: TimeInterval
    let coverImageFileName: String?
    let audioFileName: String?
    let audioFileExtension: String?
    let ebookFileName: String?
    let ebookFileExtension: String?
    let theme: PlayerTheme

    private var bundledBookDirectoryURL: URL? {
        Bundle.main.resourceURL?
            .appendingPathComponent("Book", isDirectory: true)
            .appendingPathComponent(folderName, isDirectory: true)
    }

    var audioURL: URL? {
        guard
            let audioFileName,
            let audioFileExtension
        else {
            return nil
        }

        return bundledFileURL(named: audioFileName, extension: audioFileExtension)
    }

    var coverURL: URL? {
        guard let coverImageFileName else {
            return nil
        }

        let fileName = coverImageFileName as NSString
        let fileExtension = fileName.pathExtension.isEmpty ? nil : fileName.pathExtension
        return bundledFileURL(named: fileName.deletingPathExtension, extension: fileExtension)
    }

    var ebookURL: URL? {
        if let downloadedEbookURL, FileManager.default.fileExists(atPath: downloadedEbookURL.path) {
            return downloadedEbookURL
        }

        guard
            let ebookFileName,
            let ebookFileExtension
        else {
            return nil
        }

        return bundledFileURL(named: ebookFileName, extension: ebookFileExtension)
    }

    var hasAudiobook: Bool {
        audioURL != nil
    }

    var hasEbook: Bool {
        (ebookFileName != nil && ebookFileExtension != nil) || backendEpubFilename != nil
    }

    var downloadedEbookURL: URL? {
        guard let backendEpubFilename else {
            return nil
        }

        guard let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        return appSupportDirectory
            .appendingPathComponent("Readtard", isDirectory: true)
            .appendingPathComponent("books", isDirectory: true)
            .appendingPathComponent(backendBookID, isDirectory: true)
            .appendingPathComponent(backendEpubFilename, isDirectory: false)
    }

    func updatingBackendInfo(bookID: String, epubFilename: String?) -> Audiobook {
        Audiobook(
            folderName: folderName,
            backendBookID: bookID,
            backendEpubFilename: epubFilename,
            title: title,
            author: author,
            publisher: publisher,
            badge: badge,
            duration: duration,
            coverImageFileName: coverImageFileName,
            audioFileName: audioFileName,
            audioFileExtension: audioFileExtension,
            ebookFileName: ebookFileName,
            ebookFileExtension: ebookFileExtension,
            theme: theme
        )
    }

    private func bundledFileURL(named fileName: String, extension fileExtension: String?) -> URL? {
        guard let bundledBookDirectoryURL else {
            return nil
        }

        let candidateURL = bundledBookDirectoryURL.appendingPathComponent(
            fileExtension.map { "\(fileName).\($0)" } ?? fileName,
            isDirectory: false
        )

        guard FileManager.default.fileExists(atPath: candidateURL.path) else {
            return nil
        }

        return candidateURL
    }
}

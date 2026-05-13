//
//  ReadtardAPIClient.swift
//  Readtard
//

import Foundation

struct ReadtardAPIConfiguration {
    let baseURL: URL
    let askTimeout: TimeInterval
    let defaultTimeout: TimeInterval

    static let development = ReadtardAPIConfiguration(
        baseURL: URL(string: "http://127.0.0.1:8000")!,
        askTimeout: 90,
        defaultTimeout: 20
    )
}

struct BookListResponse: Decodable {
    let books: [BookListItem]
}

struct BookListItem: Decodable {
    let id: String
    let directoryID: String?
    let epubFilename: String
    let title: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case directoryID = "directory_id"
        case epubFilename = "epub_filename"
        case title
    }
}

struct AskResponse: Decodable {
    let answer: String
}

struct AskRequest: Encodable {
    let bookID: String
    let source: String
    let question: String
    let ebook: EbookPayload?
    let audiobook: AudiobookPayload?

    struct EbookPayload: Encodable {
        let kind: String
        let locator: EbookLocator?

        private enum CodingKeys: String, CodingKey {
            case kind
            case locator
        }
    }

    struct AudiobookPayload: Encodable {
        let timestampSec: Double

        private enum CodingKeys: String, CodingKey {
            case timestampSec = "timestamp_sec"
        }
    }

    private enum CodingKeys: String, CodingKey {
        case bookID = "book_id"
        case source
        case question
        case ebook
        case audiobook
    }
}

enum ReadtardAPIError: LocalizedError {
    case invalidResponse
    case http(statusCode: Int, message: String, code: String?)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The backend returned an invalid response."
        case let .http(statusCode, message, code):
            if let code, !code.isEmpty {
                return "\(message) (\(code), HTTP \(statusCode))"
            }

            return "\(message) (HTTP \(statusCode))"
        case let .transport(error):
            if let urlError = error as? URLError, urlError.code == .timedOut {
                return "The request timed out."
            }

            return error.localizedDescription
        }
    }
}

struct ReadtardAPIClient {
    let configuration: ReadtardAPIConfiguration
    let session: URLSession

    init(
        configuration: ReadtardAPIConfiguration = .development,
        session: URLSession? = nil
    ) {
        self.configuration = configuration

        if let session {
            self.session = session
        } else {
            let urlSessionConfiguration = URLSessionConfiguration.default
            urlSessionConfiguration.timeoutIntervalForRequest = configuration.defaultTimeout
            urlSessionConfiguration.timeoutIntervalForResource = configuration.askTimeout
            self.session = URLSession(configuration: urlSessionConfiguration)
        }
    }

    func health() async throws -> HealthResponse {
        let request = try makeRequest(path: "health")
        return try await send(request, as: HealthResponse.self)
    }

    func listBooks() async throws -> BookListResponse {
        let request = try makeRequest(path: "books")
        return try await send(request, as: BookListResponse.self)
    }

    func downloadEpub(bookID: String, fileName: String) async throws -> URL {
        let request = try makeRequest(path: "books/\(bookID)/epub")
        let temporaryURL = try await download(request)

        let destinationDirectory = try applicationSupportDirectory()
            .appendingPathComponent("Readtard", isDirectory: true)
            .appendingPathComponent("books", isDirectory: true)
            .appendingPathComponent(bookID, isDirectory: true)

        try FileManager.default.createDirectory(
            at: destinationDirectory,
            withIntermediateDirectories: true
        )

        let destinationURL = destinationDirectory.appendingPathComponent(fileName, isDirectory: false)

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
        return destinationURL
    }

    func ask(_ requestBody: AskRequest) async throws -> AskResponse {
        var request = try makeRequest(path: "ask", method: "POST", timeout: configuration.askTimeout)
        request.httpBody = try JSONEncoder().encode(requestBody)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await send(request, as: AskResponse.self)
    }

    private func makeRequest(path: String, method: String = "GET", timeout: TimeInterval? = nil) throws -> URLRequest {
        let url = configuration.baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout ?? configuration.defaultTimeout
        return request
    }

    private func send<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        do {
            let (data, response) = try await session.data(for: request)
            try validate(response: response, data: data)
            return try JSONDecoder().decode(T.self, from: data)
        } catch let error as ReadtardAPIError {
            throw error
        } catch {
            throw ReadtardAPIError.transport(error)
        }
    }

    private func download(_ request: URLRequest) async throws -> URL {
        do {
            let (url, response) = try await session.download(for: request)
            try validate(response: response, data: nil)
            return url
        } catch let error as ReadtardAPIError {
            throw error
        } catch {
            throw ReadtardAPIError.transport(error)
        }
    }

    private func validate(response: URLResponse, data: Data?) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ReadtardAPIError.invalidResponse
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let backendError = data.flatMap { try? JSONDecoder().decode(BackendErrorEnvelope.self, from: $0) }
            let message = backendError?.detail.message ?? backendError?.detail.rawString ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            let code = backendError?.detail.code
            throw ReadtardAPIError.http(statusCode: httpResponse.statusCode, message: message, code: code)
        }
    }

    private func applicationSupportDirectory() throws -> URL {
        guard let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw ReadtardAPIError.invalidResponse
        }

        return url
    }
}

struct HealthResponse: Decodable {
    let status: String
    let ready: Bool
}

private struct BackendErrorEnvelope: Decodable {
    let detail: BackendErrorDetail
}

private struct BackendErrorDetail: Decodable {
    let rawString: String?
    let code: String?
    let message: String

    init(from decoder: Decoder) throws {
        let singleValueContainer = try? decoder.singleValueContainer()
        if let rawString = try? singleValueContainer?.decode(String.self) {
            self.rawString = rawString
            self.code = nil
            self.message = rawString
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.rawString = nil
        self.code = try? container.decode(String.self, forKey: .code)
        self.message = (try? container.decode(String.self, forKey: .message))
            ?? (try? container.decode(String.self, forKey: .detail))
            ?? "Unknown backend error."
    }

    private enum CodingKeys: String, CodingKey {
        case code
        case message
        case detail
    }
}

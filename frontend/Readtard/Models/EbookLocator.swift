//
//  EbookLocator.swift
//  Readtard
//

import Foundation
import ReadiumShared

struct EbookLocator: Codable, Equatable {
    var href: String
    var title: String?
    var fragments: [String]
    var position: Int?
    var progression: Double?
    var totalProgression: Double?
    var otherLocations: [String: JSONValue]?
    var textBefore: String?
    var textHighlight: String?
    var textAfter: String?

    init?(locator: Locator) {
        href = locator.href.string
        title = locator.title
        fragments = locator.locations.fragments
        position = locator.locations.position
        progression = locator.locations.progression
        totalProgression = locator.locations.totalProgression
        otherLocations = JSONValue.makeObject(from: locator.locations.otherLocations)
        textBefore = locator.text.before
        textHighlight = locator.text.highlight
        textAfter = locator.text.after

        if href.isEmpty {
            return nil
        }
    }
}

enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
            return
        }

        if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
            return
        }

        if let int = try? container.decode(Int.self) {
            self = .number(Double(int))
            return
        }

        if let double = try? container.decode(Double.self) {
            self = .number(double)
            return
        }

        if let string = try? container.decode(String.self) {
            self = .string(string)
            return
        }

        if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
            return
        }

        if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
            return
        }

        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value.")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value):
            try container.encode(value)
        case let .number(value):
            try container.encode(value)
        case let .bool(value):
            try container.encode(value)
        case let .object(value):
            try container.encode(value)
        case let .array(value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    static func makeObject(from dictionary: [String: Any]) -> [String: JSONValue]? {
        guard !dictionary.isEmpty else {
            return nil
        }

        var object: [String: JSONValue] = [:]
        object.reserveCapacity(dictionary.count)

        for (key, value) in dictionary {
            object[key] = JSONValue(value)
        }

        return object
    }

    init(_ value: Any) {
        switch value {
        case let value as String:
            self = .string(value)
        case let value as Bool:
            self = .bool(value)
        case let value as Int:
            self = .number(Double(value))
        case let value as Double:
            self = .number(value)
        case let value as Float:
            self = .number(Double(value))
        case let value as [Any]:
            self = .array(value.map(JSONValue.init))
        case let value as [String: Any]:
            self = .object(JSONValue.makeObject(from: value) ?? [:])
        default:
            self = .null
        }
    }
}

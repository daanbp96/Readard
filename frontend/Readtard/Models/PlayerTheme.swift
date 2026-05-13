//
//  PlayerTheme.swift
//  Readtard
//

import SwiftUI

struct PlayerTheme {
    let backgroundTop: Color
    let backgroundBottom: Color
    let coverStripe: Color
}

extension Color {
    static func fromHex(_ hex: String) -> Color {
        let sanitizedHex = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        guard let value = UInt64(sanitizedHex, radix: 16), sanitizedHex.count == 6 else {
            return .clear
        }

        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255

        return Color(red: red, green: green, blue: blue)
    }
}

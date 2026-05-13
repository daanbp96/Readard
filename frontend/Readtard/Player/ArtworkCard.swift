//
//  ArtworkCard.swift
//  Readtard
//

import SwiftUI
import UIKit

struct ArtworkCard: View {
    let book: Audiobook
    /// Fixed cover height. When `width` is nil, the card expands to the parent width (portrait player).
    var coverHeight: CGFloat = 344
    /// When set (e.g. landscape), keeps cover proportions without stretching full width.
    var width: CGFloat? = nil

    var body: some View {
        Group {
            if let width {
                coverContent
                    .frame(width: width, height: coverHeight)
            } else {
                coverContent
                    .frame(maxWidth: .infinity)
                    .frame(height: coverHeight)
            }
        }
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.28), radius: 24, y: 14)
    }

    private var coverContent: some View {
        ZStack {
            Rectangle()
                .fill(Color(red: 0.01, green: 0.02, blue: 0.10))

            if let coverImage {
                Image(uiImage: coverImage)
                    .resizable()
                    .scaledToFill()
            }
        }
    }

    private var coverImage: UIImage? {
        guard let coverURL = book.coverURL else {
            return nil
        }

        return UIImage(contentsOfFile: coverURL.path)
    }
}

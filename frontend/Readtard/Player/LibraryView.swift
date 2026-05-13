//
//  LibraryView.swift
//  Readtard
//

import SwiftUI
import UIKit

struct LibraryView: View {
    let books: [Audiobook]
    let progressStore: ReadingProgressStore
    let onSelectBook: (Audiobook) -> Void

    /// Fills the row in landscape and on larger devices without hard-coding column counts.
    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 152, maximum: 240), spacing: 18, alignment: .top)]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                LazyVGrid(columns: gridColumns, spacing: 28) {
                    ForEach(books, id: \.folderName) { book in
                        Button {
                            onSelectBook(book)
                        } label: {
                            LibraryBookCard(book: book, progressPercentage: progressStore.percentage(for: book))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            Text("Library")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(.white)

            Spacer()

            HStack(spacing: 12) {
                headerButton(systemImage: "line.3.horizontal")
                headerButton(systemImage: "ellipsis")
            }
        }
    }

    private func headerButton(systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 18, weight: .medium))
            .frame(width: 44, height: 44)
            .background(Color.white.opacity(0.08))
            .clipShape(Circle())
            .foregroundStyle(.white)
    }
}

private struct LibraryBookCard: View {
    let book: Audiobook
    let progressPercentage: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.white.opacity(0.06))

                if let image = coverImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(
                        colors: [book.theme.backgroundTop, book.theme.backgroundBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .overlay {
                        Text(book.title)
                            .font(.system(size: 18, weight: .medium, design: .serif))
                            .foregroundStyle(.white.opacity(0.88))
                            .multilineTextAlignment(.center)
                            .padding(16)
                    }
                }
            }
            .frame(height: 198)
            .clipped()
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            }

            HStack(spacing: 6) {
                Text(progressText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))

                Spacer()

                if book.hasAudiobook {
                    Image(systemName: "speaker.wave.2")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }

                if book.hasEbook {
                    Image(systemName: "book")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            HStack {
                Text(book.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)

                Spacer()

                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    private var progressText: String {
        "\(progressPercentage)%"
    }

    private var coverImage: UIImage? {
        guard let coverURL = book.coverURL else {
            return nil
        }

        return UIImage(contentsOfFile: coverURL.path)
    }
}

#Preview {
    LibraryView(books: [], progressStore: ReadingProgressStore(), onSelectBook: { _ in })
}

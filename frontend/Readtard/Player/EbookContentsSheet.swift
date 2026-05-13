//
//  EbookContentsSheet.swift
//  Readtard
//

import SwiftUI

struct EbookContentsSheet: View {
    @ObservedObject var reader: EbookReaderController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            if reader.chapters.isEmpty {
                Text("No table of contents found in this EPUB.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(reader.chapters) { chapter in
                            Button {
                                reader.goToChapter(chapter)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    Text(chapter.title)
                                        .font(.system(size: 17, weight: chapter.id == reader.currentChapterID ? .semibold : .medium))
                                        .foregroundStyle(chapter.id == reader.currentChapterID ? .white : .white.opacity(0.78))
                                        .multilineTextAlignment(.leading)
                                        .padding(.leading, CGFloat(chapter.depth) * 14)

                                    Spacer()

                                    if chapter.id == reader.currentChapterID {
                                        Image(systemName: "book.fill")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(.white.opacity(0.92))
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(rowBackground(for: chapter))
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .padding(20)
        .presentationDetents([.fraction(0.6), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .presentationBackground(
            LinearGradient(
                colors: [
                    Color(red: 0.11, green: 0.11, blue: 0.12),
                    Color(red: 0.16, green: 0.16, blue: 0.17)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Contents")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.white)

                if let chapterTitle = reader.currentChapterTitle {
                    Text(chapterTitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.62))
                }
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.9))
        }
    }

    private func rowBackground(for chapter: EbookChapter) -> some ShapeStyle {
        if chapter.id == reader.currentChapterID {
            return AnyShapeStyle(Color.white.opacity(0.16))
        }

        return AnyShapeStyle(Color.white.opacity(0.06))
    }
}

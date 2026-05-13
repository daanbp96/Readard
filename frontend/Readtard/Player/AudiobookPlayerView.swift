//
//  AudiobookPlayerView.swift
//  Readtard
//

import SwiftUI

struct AudiobookPlayerView: View {
    @ObservedObject var player: AudioPlayerController
    let onAskTapped: () -> Void
    let onSwitchMode: () -> Void

    var body: some View {
        GeometryReader { geometry in
            if let book = player.book {
                let isLandscape = geometry.size.width > geometry.size.height
                Group {
                    if isLandscape {
                        landscapeContent(book: book, geometry: geometry)
                    } else {
                        portraitContent(book: book)
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func portraitContent(book: Audiobook) -> some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)

            ArtworkCard(book: book)

            metadataRow(book: book)
            progressSection(book: book)
            transportControls
            volumeSection
            utilityRow

            Spacer(minLength: 0)
        }
    }

    private func landscapeContent(book: Audiobook, geometry: GeometryProxy) -> some View {
        let safe = geometry.safeAreaInsets
        let usableH = geometry.size.height - safe.top - safe.bottom
        let coverHeight = min(300, max(160, usableH - 24))
        let coverWidth = min(coverHeight * 0.68, max(120, geometry.size.width * 0.36 - safe.leading - safe.trailing))

        return HStack(alignment: .center, spacing: 20) {
            ArtworkCard(book: book, coverHeight: coverHeight, width: coverWidth)

            VStack(alignment: .leading, spacing: 16) {
                landscapeMetadata(book: book)
                progressSection(book: book)
                transportControls
                volumeSection
                utilityRow
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func titleAuthorStack(book: Audiobook, titleSize: CGFloat, titleLineLimit: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(book.title)
                .font(.system(size: titleSize, weight: .semibold, design: .rounded))
                .lineLimit(titleLineLimit)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.leading)

            Text(book.author)
                .font(.system(size: titleSize >= 28 ? 16 : 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.86))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func landscapeMetadata(book: Audiobook) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            titleAuthorStack(book: book, titleSize: 22, titleLineLimit: 2)

            HStack(spacing: 10) {
                Button {
                    onAskTapped()
                } label: {
                    Text("Ask me")
                        .font(.system(size: 16, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Menu {
                    Button("Switch to ebook") {
                        onSwitchMode()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
    }

    private func metadataRow(book: Audiobook) -> some View {
        HStack(alignment: .center, spacing: 12) {
            titleAuthorStack(book: book, titleSize: 33, titleLineLimit: 1)

            Spacer(minLength: 8)

            Button {
                onAskTapped()
            } label: {
                Text("Ask me")
                    .font(.system(size: 18, weight: .semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Menu {
                Button("Switch to ebook") {
                    onSwitchMode()
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
        }
    }

    private func progressSection(book: Audiobook) -> some View {
        VStack(spacing: 8) {
            Slider(
                value: Binding(
                    get: { player.currentTime },
                    set: { player.seek(to: $0) }
                ),
                in: 0...max(player.duration, 1)
            )
                .tint(.white.opacity(0.75))

            HStack {
                Text(timeString(player.currentTime))
                Spacer()
                Text(book.badge)
                Spacer()
                Text("-\(timeString(max(player.duration - player.currentTime, 0)))")
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white.opacity(0.74))
        }
    }

    private var transportControls: some View {
        HStack(spacing: 42) {
            skipButton(systemImage: "gobackward.15") {
                player.skip(by: -15)
            }

            Button {
                player.togglePlayback()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 30, weight: .bold))
                    .frame(width: 86, height: 86)
                    .background(Color.white)
                    .foregroundStyle(Color(red: 0.25, green: 0.08, blue: 0.12))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
            }
            .buttonStyle(.plain)

            skipButton(systemImage: "goforward.15") {
                player.skip(by: 15)
            }
        }
        .padding(.top, 4)
    }

    private var volumeSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))

            Slider(
                value: Binding(
                    get: { player.volume },
                    set: { player.setVolume($0) }
                )
            )
                .tint(.white.opacity(0.78))

            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
        }
    }

    private var utilityRow: some View {
        HStack {
            utilityButton(title: speedLabel, systemImage: nil) {
                player.advanceSpeed()
            }

            Spacer()

            utilityButton(title: nil, systemImage: "moon.stars.fill") {
            }

            Spacer()

            utilityButton(title: nil, systemImage: "airplayaudio") {
            }

            Spacer()

            utilityButton(title: nil, systemImage: "list.bullet") {
            }
        }
        .foregroundStyle(.white.opacity(0.78))
        .padding(.top, 2)
    }

    private var speedLabel: String {
        if player.playbackRate == 1 {
            return "1x"
        }

        return "\(player.playbackRate.formatted(.number.precision(.fractionLength(2))))x"
            .replacingOccurrences(of: ".00", with: "")
            .replacingOccurrences(of: "0x", with: "x")
    }

    private func skipButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .regular))
                .frame(width: 54, height: 54)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
    }

    private func utilityButton(title: String?, systemImage: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if let title {
                Text(title)
                    .font(.system(size: 17, weight: .medium))
            } else if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 21, weight: .medium))
                    .frame(width: 30, height: 24)
            }
        }
        .buttonStyle(.plain)
    }

    private func timeString(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds.rounded(.down))
        let minutes = totalSeconds / 60
        let remainder = totalSeconds % 60
        return String(format: "%d:%02d", minutes, remainder)
    }
}

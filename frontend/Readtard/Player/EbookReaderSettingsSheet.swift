//
//  EbookReaderSettingsSheet.swift
//  Readtard
//

import SwiftUI

struct EbookReaderSettingsSheet: View {
    @ObservedObject var reader: EbookReaderController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            fontControls
            brightnessControls
            themeGrid
            customizeButton
        }
        .padding(20)
        .presentationDetents([.height(470)])
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
            Text("Themes & Settings")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(.white)

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

    private var fontControls: some View {
        HStack(spacing: 12) {
            Button {
                reader.stepFontScale(by: -0.07)
            } label: {
                HStack {
                    Spacer()
                    Text("A")
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                    Spacer()
                }
                .frame(height: 50)
                .background(Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            Button {
                reader.stepFontScale(by: 0.07)
            } label: {
                HStack {
                    Spacer()
                    Text("A")
                        .font(.system(size: 28, weight: .semibold, design: .serif))
                    Spacer()
                }
                .frame(height: 50)
                .background(Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
    }

    private var brightnessControls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "sun.min.fill")
                    .foregroundStyle(.white.opacity(0.78))

                Slider(
                    value: Binding(
                        get: { reader.appearance.brightness },
                        set: { reader.setBrightness($0) }
                    ),
                    in: 0.45...1.0
                )
                .tint(.white)

                Image(systemName: "sun.max.fill")
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
    }

    private var themeGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(EbookReaderThemePreset.allCases) { preset in
                Button {
                    reader.setThemePreset(preset)
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Aa")
                            .font(.system(size: 26, weight: .medium, design: .serif))

                        Spacer()

                        Text(preset.title)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(themeForeground(for: preset))
                    .padding(14)
                    .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
                    .background(themeBackground(for: preset))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                reader.appearance.themePreset == preset
                                    ? Color.white.opacity(0.95)
                                    : Color.white.opacity(0.08),
                                lineWidth: reader.appearance.themePreset == preset ? 2 : 1
                            )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var customizeButton: some View {
        Button {
        } label: {
            HStack {
                Spacer()
                Image(systemName: "dial.medium")
                Text("Customize")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
            }
            .frame(height: 48)
            .background(Color.white.opacity(0.12))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(0.95))
    }

    private func themeBackground(for preset: EbookReaderThemePreset) -> Color {
        switch preset {
        case .original: return Color.black
        case .quiet: return Color(red: 0.10, green: 0.10, blue: 0.11)
        case .paper: return Color(red: 0.22, green: 0.22, blue: 0.24)
        case .bold: return Color.black
        case .calm: return Color(red: 0.40, green: 0.35, blue: 0.24)
        case .focus: return Color(red: 0.19, green: 0.18, blue: 0.10)
        }
    }

    private func themeForeground(for preset: EbookReaderThemePreset) -> Color {
        switch preset {
        case .paper, .calm:
            return Color(red: 0.98, green: 0.96, blue: 0.88)
        case .quiet:
            return Color.white.opacity(0.72)
        case .original, .bold, .focus:
            return .white
        }
    }
}

//
//  EbookReaderView.swift
//  Readtard
//

import ReadiumNavigator
import SwiftUI
import UIKit

struct EbookReaderView: View {
    @ObservedObject var reader: EbookReaderController
    let book: Audiobook
    let onAskTapped: () -> Void
    let onSwitchToAudiobook: () -> Void
    let onReturnToLibrary: () -> Void
    @State private var isSettingsPresented = false
    @State private var isContentsPresented = false

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            let safeArea = geometry.safeAreaInsets

            ZStack {
                readerCanvasColor
                    .ignoresSafeArea()

                if reader.hasLoadedEbook {
                    if let navigator = reader.navigator {
                        EbookNavigatorContainerView(navigator: navigator)
                            .padding(.top, topContentInset(isLandscape: isLandscape))
                            .padding(.bottom, bottomContentInset(isLandscape: isLandscape))
                            .ignoresSafeArea()

                        Color.black
                            .opacity((1 - reader.appearance.brightness) * 0.55)
                            .ignoresSafeArea()
                            .allowsHitTesting(false)

                        navigationOverlay()

                        readerChromeProtection(isLandscape: isLandscape)

                        overlayControls(isLandscape: isLandscape, safeArea: safeArea)
                    } else if reader.isLoading {
                        loadingView
                    } else {
                        loadingFailureView
                    }
                } else {
                    missingEbookView
                }
            }
            .onAppear {
                reader.setLandscapeLayout(isLandscape)
            }
            .onChange(of: isLandscape) { _, newValue in
                reader.setLandscapeLayout(newValue)
            }
        }
        .sheet(isPresented: $isSettingsPresented) {
            EbookReaderSettingsSheet(reader: reader)
        }
        .sheet(isPresented: $isContentsPresented) {
            EbookContentsSheet(reader: reader)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.white)

            Text("Opening ebook…")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white.opacity(0.84))
        }
    }

    private var loadingFailureView: some View {
        VStack(spacing: 18) {
            Spacer()

            Text(reader.loadingError ?? "Unable to open ebook.")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                .multilineTextAlignment(.center)

            Button("Switch to audiobook") {
                onSwitchToAudiobook()
            }
            .font(.system(size: 18, weight: .semibold))
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.12))
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .buttonStyle(.plain)

            Button("Back to library") {
                onReturnToLibrary()
            }
            .font(.system(size: 18, weight: .semibold))
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.08))
            .foregroundStyle(.white.opacity(0.9))
            .clipShape(Capsule())
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(24)
    }

    private var missingEbookView: some View {
        VStack {
            Spacer()

            Text("No ebook loaded")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))

            Spacer()

            HStack(spacing: 16) {
                Button("Library") {
                    onReturnToLibrary()
                }
                .font(.system(size: 17, weight: .semibold))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.08))
                .foregroundStyle(.white.opacity(0.9))
                .clipShape(Capsule())
                .buttonStyle(.plain)

                Button("Switch to audiobook") {
                    onSwitchToAudiobook()
                }
                .font(.system(size: 17, weight: .semibold))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.12))
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .buttonStyle(.plain)
            }
            .padding(.bottom, 34)
        }
    }

    private var readerCanvasColor: Color {
        switch reader.appearance.themePreset {
        case .original, .bold, .focus:
            return .black
        case .quiet:
            return Color(red: 0.98, green: 0.98, blue: 0.99)
        case .paper, .calm:
            return Color(red: 0.96, green: 0.94, blue: 0.88)
        }
    }

    private func readerChromeProtection(isLandscape: Bool) -> some View {
        let base = readerCanvasColor
        VStack(spacing: 0) {
            LinearGradient(
                stops: chromeGradientStops(edge: .top, base: base, isLandscape: isLandscape),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: fixedTopChromeHeight(isLandscape: isLandscape))

            Spacer()

            LinearGradient(
                stops: chromeGradientStops(edge: .bottom, base: base, isLandscape: isLandscape),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: fixedBottomChromeHeight(isLandscape: isLandscape))
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func chromeGradientStops(edge: ChromeEdge, base: Color, isLandscape: Bool) -> [Gradient.Stop] {
        let strong: CGFloat = isLandscape ? 0.55 : 0.88
        let mid: CGFloat = isLandscape ? 0.18 : 0.42
        switch edge {
        case .top:
            return [
                .init(color: base.opacity(strong), location: 0),
                .init(color: base.opacity(mid), location: isLandscape ? 0.55 : 0.45),
                .init(color: base.opacity(0), location: 1)
            ]
        case .bottom:
            return [
                .init(color: base.opacity(0), location: 0),
                .init(color: base.opacity(mid), location: isLandscape ? 0.45 : 0.55),
                .init(color: base.opacity(strong), location: 1)
            ]
        }
    }

    private enum ChromeEdge {
        case top
        case bottom
    }

    private func topContentInset(isLandscape: Bool) -> CGFloat {
        isLandscape ? 36 : 108
    }

    private func bottomContentInset(isLandscape: Bool) -> CGFloat {
        isLandscape ? 40 : 104
    }

    private func fixedTopChromeHeight(isLandscape: Bool) -> CGFloat {
        isLandscape ? 52 : 120
    }

    private func fixedBottomChromeHeight(isLandscape: Bool) -> CGFloat {
        isLandscape ? 56 : 126
    }

    private func chromeLabelColor(opacity: Double) -> Color {
        switch reader.appearance.themePreset {
        case .original, .bold, .focus:
            return Color.white.opacity(opacity)
        case .quiet, .paper, .calm:
            return Color.black.opacity(opacity)
        }
    }

    @ViewBuilder
    private func overlayControls(isLandscape: Bool, safeArea: EdgeInsets) -> some View {
        if reader.controlsVisible {
            VStack {
                HStack {
                    Spacer()

                    Button {
                        onReturnToLibrary()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .medium))
                            .frame(width: 48, height: 48)
                            .background(Color.black.opacity(0.45))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                }
                .padding(.leading, max(24, safeArea.leading + 8))
                .padding(.trailing, max(24, safeArea.trailing + 8))
                .padding(.top, max(18, safeArea.top + 8))

                Text("\(reader.pagesLeftInChapter) pages left in chapter")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(chromeLabelColor(opacity: 0.7))
                    .padding(.top, isLandscape ? 6 : 8)
                    .padding(.horizontal, max(24, max(safeArea.leading, safeArea.trailing) + 8))

                Spacer()

                HStack(alignment: .bottom) {
                    Button {
                        onAskTapped()
                    } label: {
                        Text("Ask me")
                            .font(.system(size: 17, weight: .semibold))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 11)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(chromeLabelColor(opacity: 1))

                    Spacer()

                    Text("\(reader.currentPageNumber) of \(reader.totalPages)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(chromeLabelColor(opacity: 0.7))
                        .multilineTextAlignment(.center)

                    Spacer()

                    Menu {
                        Button("Contents") {
                            isContentsPresented = true
                        }

                        Button("Switch to audiobook") {
                            onSwitchToAudiobook()
                        }

                        Button("Themes & Settings") {
                            isSettingsPresented = true
                        }
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 22, weight: .medium))
                            .frame(width: 54, height: 54)
                            .background(Color.black.opacity(0.45))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                }
                .padding(.leading, max(24, safeArea.leading + 8))
                .padding(.trailing, max(24, safeArea.trailing + 8))
                .padding(.bottom, max(isLandscape ? 20 : 28, safeArea.bottom + 10))
            }
        } else {
            VStack {
                Text(reader.title)
                    .font(.system(size: isLandscape ? 14 : 18, weight: .medium, design: .serif))
                    .foregroundStyle(chromeLabelColor(opacity: isLandscape ? 0.42 : 0.72))
                    .lineLimit(isLandscape ? 1 : 2)
                    .minimumScaleFactor(0.85)
                    .padding(.top, isLandscape ? max(6, safeArea.top + 2) : max(42, safeArea.top + 20))

                Spacer()

                Text("\(reader.currentPageNumber)")
                    .font(.system(size: isLandscape ? 13 : 16, weight: .medium, design: .rounded))
                    .foregroundStyle(chromeLabelColor(opacity: isLandscape ? 0.38 : 0.62))
                    .padding(.bottom, isLandscape ? max(8, safeArea.bottom + 4) : max(34, safeArea.bottom + 12))
            }
            .padding(.horizontal, max(24, max(safeArea.leading, safeArea.trailing) + 8))
            .allowsHitTesting(false)
        }
    }
    private func navigationOverlay() -> some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                tapColumn(width: geometry.size.width * 0.2) {
                    reader.goToPreviousPage()
                }

                tapColumn(width: geometry.size.width * 0.6) {
                    reader.toggleControls()
                }

                tapColumn(width: geometry.size.width * 0.2) {
                    reader.goToNextPage()
                }
            }
        }
        .ignoresSafeArea()
    }

    private func tapColumn(width: CGFloat, action: @escaping () -> Void) -> some View {
        Color.clear
            .frame(width: width)
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
    }
}

private struct EbookNavigatorContainerView: UIViewControllerRepresentable {
    let navigator: VisualNavigator & UIViewController

    func makeUIViewController(context: Context) -> EbookNavigatorHostViewController {
        EbookNavigatorHostViewController(navigator: navigator)
    }

    func updateUIViewController(_ uiViewController: EbookNavigatorHostViewController, context: Context) {
        uiViewController.setNavigator(navigator)
    }
}

private final class EbookNavigatorHostViewController: UIViewController {
    private var navigator: (VisualNavigator & UIViewController)

    init(navigator: VisualNavigator & UIViewController) {
        self.navigator = navigator
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init?(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        embedCurrentNavigator()
    }

    func setNavigator(_ newNavigator: VisualNavigator & UIViewController) {
        guard navigator !== newNavigator else {
            return
        }

        removeCurrentNavigator()
        navigator = newNavigator

        if isViewLoaded {
            embedCurrentNavigator()
        }
    }

    private func embedCurrentNavigator() {
        addChild(navigator)
        navigator.view.frame = view.bounds
        navigator.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        navigator.view.backgroundColor = .clear
        view.addSubview(navigator.view)
        navigator.didMove(toParent: self)
    }

    private func removeCurrentNavigator() {
        navigator.willMove(toParent: nil)
        navigator.view.removeFromSuperview()
        navigator.removeFromParent()
    }
}

#Preview {
    ContentView()
}

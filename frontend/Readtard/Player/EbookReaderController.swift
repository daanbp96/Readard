//
//  EbookReaderController.swift
//  Readtard
//

import Combine
import Foundation
import ReadiumNavigator
import ReadiumShared
import ReadiumStreamer
import UIKit

enum EbookReaderThemePreset: String, CaseIterable, Identifiable {
    case original
    case quiet
    case paper
    case bold
    case calm
    case focus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .original: "Original"
        case .quiet: "Quiet"
        case .paper: "Paper"
        case .bold: "Bold"
        case .calm: "Calm"
        case .focus: "Focus"
        }
    }

    var navigatorTheme: Theme {
        switch self {
        case .paper, .calm:
            .sepia
        case .quiet:
            .light
        case .original, .bold, .focus:
            .dark
        }
    }

    var usesPublisherStyles: Bool {
        self == .original
    }
}

struct EbookReaderAppearance: Equatable {
    var fontScale: Double = 0.92
    var brightness: Double = 0.9
    var themePreset: EbookReaderThemePreset = .original
}

struct EbookChapter: Identifiable, Equatable {
    let id: String
    let title: String
    let href: String
    let depth: Int
    let startPosition: Int
}

private struct ChapterTarget {
    let chapter: EbookChapter
    let locator: Locator
}

@MainActor
final class EbookReaderController: ObservableObject {
    @Published private(set) var navigator: (VisualNavigator & UIViewController)?
    @Published private(set) var hasLoadedEbook = false
    @Published private(set) var isLoading = false
    @Published private(set) var loadingError: String?
    @Published private(set) var title = ""
    @Published private(set) var currentPageNumber = 1
    @Published private(set) var totalPages = 1
    @Published private(set) var chapters: [EbookChapter] = []
    @Published private(set) var currentChapterID: String?
    @Published var controlsVisible = false
    @Published private(set) var appearance = EbookReaderAppearance()
    @Published private(set) var selectedAskLocator: EbookLocator?
    @Published private(set) var selectedAskText: String?

    private let readium = ReadiumServices()
    private var publication: Publication?
    private var currentLocator: Locator?
    private var chapterTargetsByID: [String: ChapterTarget] = [:]
    private var positions: [Locator] = []
    private var openTask: Task<Void, Never>?
    private var isLandscapeLayout = false

    func reset() {
        openTask?.cancel()
        navigator = nil
        publication = nil
        currentLocator = nil
        selectedAskLocator = nil
        selectedAskText = nil
        chapterTargetsByID = [:]
        positions = []
        hasLoadedEbook = false
        isLoading = false
        loadingError = nil
        title = ""
        currentPageNumber = 1
        totalPages = 1
        chapters = []
        currentChapterID = nil
        controlsVisible = false
        appearance = EbookReaderAppearance()
    }

    func load(from book: Audiobook, resumeLocatorJSON: String?) {
        reset()
        title = book.title
        hasLoadedEbook = book.hasEbook

        guard let ebookURL = book.ebookURL else {
            isLoading = false
            return
        }

        isLoading = true

        openTask = Task { [weak self] in
            await self?.openEbook(
                at: ebookURL,
                fallbackTitle: book.title,
                resumeLocator: self?.decodePersistedLocator(from: resumeLocatorJSON)
            )
        }
    }

    var pagesLeftInChapter: Int {
        guard
            let currentChapter,
            let nextChapter = nextChapter(after: currentChapter)
        else {
            return max(totalPages - currentPageNumber, 0)
        }

        return max(nextChapter.startPosition - currentPageNumber, 0)
    }

    var currentChapterTitle: String? {
        currentChapter?.title
    }

    var currentLocatorJSON: String? {
        encodePersistedLocator(from: currentLocator)
    }

    var currentEbookLocator: EbookLocator? {
        guard let currentLocator else {
            return nil
        }

        return EbookLocator(locator: currentLocator)
    }

    func toggleControls() {
        controlsVisible.toggle()
    }

    func setControlsVisible(_ isVisible: Bool) {
        controlsVisible = isVisible
    }

    func setThemePreset(_ preset: EbookReaderThemePreset) {
        guard appearance.themePreset != preset else {
            return
        }

        appearance.themePreset = preset
        submitCurrentPreferences()
    }

    func setFontScale(_ value: Double) {
        let clampedValue = min(max(value, 0.75), 1.35)
        guard appearance.fontScale != clampedValue else {
            return
        }

        appearance.fontScale = clampedValue
        submitCurrentPreferences()
    }

    func stepFontScale(by amount: Double) {
        setFontScale(appearance.fontScale + amount)
    }

    func setBrightness(_ value: Double) {
        appearance.brightness = min(max(value, 0.45), 1.0)
    }

    func setLandscapeLayout(_ isLandscape: Bool) {
        guard isLandscapeLayout != isLandscape else {
            return
        }

        isLandscapeLayout = isLandscape
        submitCurrentPreferences()
    }

    func goToNextPage() {
        guard let navigator else {
            return
        }

        Task {
            _ = await navigator.goForward(options: .animated)
        }
    }

    func goToPreviousPage() {
        guard let navigator else {
            return
        }

        Task {
            _ = await navigator.goBackward(options: .animated)
        }
    }

    func goToChapter(_ chapter: EbookChapter) {
        guard
            let publication,
            let chapterTarget = chapterTargetsByID[chapter.id]
        else {
            return
        }

        do {
            let navigator = try makeNavigator(publication: publication, initialLocation: chapterTarget.locator)
            self.navigator = navigator
            updateLocationState(from: chapterTarget.locator)
            currentChapterID = chapter.id
            controlsVisible = false
            loadingError = nil
        } catch {
            loadingError = "Unable to open this chapter."
        }
    }

    func askLocatorFromLastVisibleWords() async -> EbookLocator? {
        guard let navigator = navigator as? EPUBNavigatorViewController else {
            #if DEBUG
            print("=== READIUM LAST VISIBLE WORDS ===")
            print("Navigator is not ready.")
            print("==================================")
            #endif
            return nil
        }

        let script = """
        (function() {
          function isRectVisible(rect) {
            return rect &&
              rect.width > 0 &&
              rect.height > 0 &&
              rect.right > 0 &&
              rect.left < window.innerWidth &&
              rect.bottom > 0 &&
              rect.top < window.innerHeight;
          }

          function isTextNodeRenderable(node) {
            if (!node || !node.nodeValue || !node.nodeValue.trim()) return false;
            const parent = node.parentElement;
            if (!parent) return false;
            const style = window.getComputedStyle(parent);
            if (!style) return false;
            return style.display !== "none" &&
              style.visibility !== "hidden" &&
              style.opacity !== "0";
          }

          function hasVisibleRectForRange(range) {
            const rects = range.getClientRects();
            for (let i = 0; i < rects.length; i++) {
              if (isRectVisible(rects[i])) return true;
            }
            return false;
          }

          function nodeHasVisibleContent(node) {
            const range = document.createRange();
            range.selectNodeContents(node);
            return hasVisibleRectForRange(range);
          }

          function lastVisibleOffset(node) {
            const text = node.nodeValue || "";
            if (text.length === 0) return 0;

            let low = 1;
            let high = text.length;
            let best = 0;

            while (low <= high) {
              const mid = Math.floor((low + high) / 2);
              const range = document.createRange();
              range.setStart(node, 0);
              range.setEnd(node, mid);
              if (hasVisibleRectForRange(range)) {
                best = mid;
                low = mid + 1;
              } else {
                high = mid - 1;
              }
            }

            return best;
          }

          const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
          const candidates = [];
          let current = walker.nextNode();
          while (current) {
            if (isTextNodeRenderable(current) && nodeHasVisibleContent(current)) {
              candidates.push(current);
            }
            current = walker.nextNode();
          }

          for (let i = candidates.length - 1; i >= 0; i--) {
            const node = candidates[i];
            const offset = lastVisibleOffset(node);
            if (offset <= 0) continue;

            const prefix = (node.nodeValue || "").slice(0, offset).trim();
            if (!prefix) continue;

            const words = prefix.split(/\\s+/).filter(Boolean);
            if (words.length === 0) continue;
            return words.slice(-20).join(" ");
          }

          return "";
        })();
        """

        let result = await navigator.evaluateJavaScript(script)
        let extractedWords: String

        switch result {
        case let .success(value):
            extractedWords = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        case .failure:
            extractedWords = ""
        }

        #if DEBUG
        print("=== READIUM LAST VISIBLE WORDS ===")
        if !extractedWords.isEmpty {
            print(extractedWords)
        } else {
            print("No visible text words found on this page.")
        }
        print("==================================")
        #endif

        guard
            !extractedWords.isEmpty,
            let currentLocator,
            var locator = EbookLocator(locator: currentLocator)
        else {
            return nil
        }

        locator.textHighlight = extractedWords
        selectedAskText = extractedWords
        selectedAskLocator = locator
        return locator
    }

    private func openEbook(
        at url: URL,
        fallbackTitle: String,
        resumeLocator: EbookLocator?
    ) async {
        do {
            guard let absoluteURL = url.anyURL.absoluteURL else {
                throw EbookOpenError.invalidURL
            }

            let asset = try await readium.assetRetriever.retrieve(url: absoluteURL).get()
            let publication = try await readium.publicationOpener.open(
                asset: asset,
                allowUserInteraction: false,
                sender: nil
            ).get()

            let positionsByReadingOrder = try await publication.positionsByReadingOrder().get()
            let positions = positionsByReadingOrder.flatMap { $0 }
            let initialLocator = restoredLocator(from: resumeLocator, in: publication, positions: positions)
            let navigator = try makeNavigator(publication: publication, initialLocation: initialLocator)
            let tableOfContents = try await publication.tableOfContents().get()
            let chapterTargets = buildChapterTargets(from: tableOfContents, positions: positions)

            if Task.isCancelled {
                return
            }

            self.publication = publication
            self.positions = positions
            self.navigator = navigator
            self.title = resolvedTitle(publicationTitle: publication.metadata.title, fallbackTitle: fallbackTitle)
            self.totalPages = max(positions.count, 1)
            self.chapterTargetsByID = Dictionary(uniqueKeysWithValues: chapterTargets.map { ($0.chapter.id, $0) })
            self.chapters = chapterTargets.map(\.chapter)
            updateLocationState(from: navigator.currentLocation ?? initialLocator)
            self.loadingError = nil
            self.isLoading = false
        } catch {
            if Task.isCancelled {
                return
            }

            navigator = nil
            publication = nil
            currentLocator = nil
            chapterTargetsByID = [:]
            chapters = []
            loadingError = "Unable to open ebook."
            isLoading = false
        }
    }

    private func preferredPreferences(for publication: Publication) -> EPUBPreferences {
        EPUBPreferences(
            fontSize: appearance.fontScale,
            lineHeight: 1.45,
            pageMargins: currentPageMargins,
            publisherStyles: appearance.themePreset.usesPublisherStyles,
            scroll: false,
            theme: appearance.themePreset.navigatorTheme
        )
    }

    private func submitCurrentPreferences() {
        guard let navigator = navigator as? EPUBNavigatorViewController else {
            return
        }

        navigator.submitPreferences(
            EPUBPreferences(
                fontSize: appearance.fontScale,
                lineHeight: 1.45,
                pageMargins: currentPageMargins,
                publisherStyles: appearance.themePreset.usesPublisherStyles,
                scroll: false,
                theme: appearance.themePreset.navigatorTheme
            )
        )
    }

    private var currentPageMargins: Double {
        isLandscapeLayout ? 0.72 : 1.0
    }

    private func buildChapterTargets(from links: [Link], positions: [Locator], depth: Int = 0) -> [ChapterTarget] {
        links.flatMap { link -> [ChapterTarget] in
            guard let locator = locatorForTableOfContentsLink(link, positions: positions) else {
                return buildChapterTargets(from: link.children, positions: positions, depth: depth + 1)
            }

            let title = normalizedChapterTitle(for: link)
            let chapter = EbookChapter(
                id: "\(depth):\(link.href)",
                title: title,
                href: link.href,
                depth: depth,
                startPosition: locator.locations.position ?? 1
            )

            return [ChapterTarget(chapter: chapter, locator: locator)] +
                buildChapterTargets(from: link.children, positions: positions, depth: depth + 1)
        }
    }

    private func locatorForTableOfContentsLink(_ link: Link, positions: [Locator]) -> Locator? {
        let href = link.href
        let components = href.components(separatedBy: "#")
        let baseHref = components.first ?? href

        if
            let fragment = components.dropFirst().first,
            let numericPosition = Int(fragment),
            let exactPosition = positions.first(where: { $0.locations.position == numericPosition })
        {
            return exactPosition
        }

        if let exactHrefMatch = positions.first(where: { normalizedHref($0.href.string) == baseHref }) {
            return exactHrefMatch
        }

        return positions.first(where: { $0.href.string.contains(baseHref) })
    }

    private func normalizedChapterTitle(for link: Link) -> String {
        let cleanedTitle = link.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !cleanedTitle.isEmpty {
            return cleanedTitle
        }

        let fileName = (link.href as NSString).lastPathComponent
        let trimmed = (fileName as NSString).deletingPathExtension
        return trimmed.isEmpty ? "Untitled Section" : trimmed.replacingOccurrences(of: "_", with: " ")
    }

    private func restoredLocator(
        from persistedLocator: EbookLocator?,
        in publication: Publication,
        positions: [Locator]
    ) -> Locator? {
        guard let persistedLocator else {
            return nil
        }

        let mediaType = publication.readingOrder.first { $0.href == persistedLocator.href }?.mediaType ?? .xhtml

        if
            let position = persistedLocator.position,
            let exactPosition = positions.first(where: { $0.locations.position == position })
        {
            return exactPosition
        }

        if let exactHref = positions.first(where: { $0.href.string == persistedLocator.href }) {
            return Locator(
                href: exactHref.href,
                mediaType: mediaType,
                title: persistedLocator.title,
                locations: Locator.Locations(
                    fragments: persistedLocator.fragments,
                    progression: persistedLocator.progression,
                    totalProgression: persistedLocator.totalProgression,
                    position: exactHref.locations.position
                ),
                text: Locator.Text(
                    after: persistedLocator.textAfter,
                    before: persistedLocator.textBefore,
                    highlight: persistedLocator.textHighlight
                )
            )
        }

        return positions.first { normalizedHref($0.href.string) == normalizedHref(persistedLocator.href) }
    }

    private func updateLocationState(from locator: Locator?) {
        currentLocator = locator
        currentPageNumber = locator?.locations.position ?? 1
        currentChapterID = currentChapterID(for: locator)

        // Clearing the selection when moving pages keeps Ask anchored to an explicit, current selection.
        if let selectableNavigator = navigator as? SelectableNavigator, selectableNavigator.currentSelection == nil {
            selectedAskLocator = nil
            selectedAskText = nil
        }
    }

    private func currentChapterID(for locator: Locator?) -> String? {
        guard
            let currentPosition = locator?.locations.position,
            !chapters.isEmpty
        else {
            return nil
        }

        return chapters
            .filter { $0.startPosition <= currentPosition }
            .max(by: { $0.startPosition < $1.startPosition })?
            .id
    }

    private var currentChapter: EbookChapter? {
        guard let currentChapterID else {
            return nil
        }

        return chapters.first { $0.id == currentChapterID }
    }

    private func nextChapter(after chapter: EbookChapter) -> EbookChapter? {
        guard let index = chapters.firstIndex(where: { $0.id == chapter.id }) else {
            return nil
        }

        let nextIndex = chapters.index(after: index)
        guard nextIndex < chapters.endIndex else {
            return nil
        }

        return chapters[nextIndex]
    }

    private func makeNavigator(publication: Publication, initialLocation: Locator?) throws -> EPUBNavigatorViewController {
        let navigator = try EPUBNavigatorViewController(
            publication: publication,
            initialLocation: initialLocation,
            config: EPUBNavigatorViewController.Configuration(
                preferences: preferredPreferences(for: publication)
            )
        )
        navigator.delegate = self
        return navigator
    }

    private func resolvedTitle(publicationTitle: String?, fallbackTitle: String) -> String {
        let cleanedPublicationTitle = publicationTitle?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            let cleanedPublicationTitle,
            !cleanedPublicationTitle.isEmpty,
            cleanedPublicationTitle.caseInsensitiveCompare("unknown") != .orderedSame
        else {
            return fallbackTitle
        }

        return cleanedPublicationTitle
    }

    private func encodePersistedLocator(from locator: Locator?) -> String? {
        guard
            let locator,
            let persistedLocator = EbookLocator(locator: locator),
            let data = try? JSONEncoder().encode(persistedLocator),
            let json = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return json
    }

    private func decodePersistedLocator(from json: String?) -> EbookLocator? {
        guard
            let json,
            let data = json.data(using: .utf8),
            let locator = try? JSONDecoder().decode(EbookLocator.self, from: data)
        else {
            return nil
        }

        return locator
    }

    private func normalizedHref(_ href: String) -> String {
        href.components(separatedBy: "#").first ?? href
    }
}

extension EbookReaderController: EPUBNavigatorDelegate {
    func navigator(_ navigator: Navigator, locationDidChange locator: Locator) {
        updateLocationState(from: locator)
    }

    func navigator(_ navigator: SelectableNavigator, shouldShowMenuForSelection selection: Selection) -> Bool {
        let locator = selection.locator
        selectedAskLocator = EbookLocator(locator: locator)
        selectedAskText = locator.text.highlight?.trimmingCharacters(in: .whitespacesAndNewlines)

        #if DEBUG
        if let json = locator.jsonString {
            print("=== READIUM SELECTION LOCATOR ===")
            print(json)
            print("================================")
        } else {
            print("=== READIUM SELECTION LOCATOR ===")
            print("Unable to serialize selection locator to JSON.")
            print("================================")
        }

        // Intentionally verbose: we need to see if Readium provides CFI/domRange/cssSelector.
        let otherLocations = locator.locations.otherLocations
        if !otherLocations.isEmpty {
            print("=== READIUM SELECTION OTHER LOCATIONS ===")
            print(otherLocations)
            print("=========================================")
        }
        #endif

        return true
    }

    func navigator(_ navigator: Navigator, presentError error: NavigatorError) {
        loadingError = "Unable to display this page."
    }
}

private struct ReadiumServices {
    let httpClient: HTTPClient
    let assetRetriever: AssetRetriever
    let publicationOpener: PublicationOpener

    init() {
        let httpClient = DefaultHTTPClient()
        let assetRetriever = AssetRetriever(httpClient: httpClient)

        self.httpClient = httpClient
        self.assetRetriever = assetRetriever
        self.publicationOpener = PublicationOpener(
            parser: DefaultPublicationParser(
                httpClient: httpClient,
                assetRetriever: assetRetriever,
                pdfFactory: DefaultPDFDocumentFactory()
            ),
            contentProtections: []
        )
    }
}

private enum EbookOpenError: Error {
    case invalidURL
}

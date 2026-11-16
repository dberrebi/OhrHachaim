import SwiftUI
import UIKit

private struct ReadingAnchor: Equatable {
    let id: Int
    let minY: CGFloat
}

private struct ReadingAnchorKey: PreferenceKey {
    static var defaultValue: [ReadingAnchor] = []
    static func reduce(value: inout [ReadingAnchor], nextValue: () -> [ReadingAnchor]) {
        value.append(contentsOf: nextValue())
    }
}

private enum ReadingBlock: Identifiable {
    case header(parashaID: Int)
    case gap(parashaID: Int, chapter: Int)
    case verse(parashaID: Int, chapter: Int, verse: Int, comments: [Comment])
    case prose(comments: [Comment])

    var id: String {
        switch self {
        case .header(let parashaID):
            return "h-\(parashaID)"
        case .gap(let parashaID, let chapter):
            return "g-\(parashaID)-\(chapter)"
        case .verse(let parashaID, let chapter, let verse, _):
            return "v-\(parashaID)-\(chapter)-\(verse)"
        case .prose:
            return "prose"
        }
    }
}

struct ReadingView: View {
    let route: ReadingRoute
    @Environment(AppSettings.self) private var settings
    @Environment(CommentaryStore.self) private var store
    @Environment(UserLibrary.self) private var library
    @Environment(\.colorScheme) private var scheme
    @State private var allowTracking = false
    @State private var trackedCommentID: Int?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .trailing, spacing: 0) {
                    blocksView
                    footer
                }
                .frame(maxWidth: 740)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 48)
            }
            .coordinateSpace(name: "reading")
            .background(Theme.background(scheme))
            .onPreferenceChange(ReadingAnchorKey.self) { anchors in
                guard allowTracking else { return }
                let nearTop = anchors.filter { $0.minY >= -8 && $0.minY < 140 }
                let pick = nearTop.min { $0.minY < $1.minY }
                guard let pick, pick.id != trackedCommentID, let comment = store.comment(id: pick.id) else { return }
                trackedCommentID = pick.id
                library.note(comment)
            }
            .onAppear {
                restore(using: proxy)
            }
        }
        .studyBar(title: navigationTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: portionShareText) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel(L10n.text("a11y.share", settings.language))
            }
        }
    }

    private var navigationTitle: String {
        switch route {
        case .parasha(let id, _):
            return store.parasha(id: id)?.name(for: settings.language) ?? ""
        case .introduction:
            return L10n.text("book.introduction", settings.language)
        case .weekly(let ids, _):
            return store.title(for: ids, language: settings.language)
        }
    }

    @ViewBuilder
    private var blocksView: some View {
        let blocks = makeBlocks()
        if blocks.isEmpty {
            Text(L10n.text("reading.empty", settings.language))
                .font(Theme.menuFont(settings.language))
                .foregroundStyle(Theme.secondary(scheme))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        } else {
            ForEach(blocks) { block in
                switch block {
                case .header(let parashaID):
                    if let parasha = store.parasha(id: parashaID) {
                        Text(parasha.name(for: settings.language))
                            .font(Theme.menuFont(settings.language))
                            .foregroundStyle(Theme.emphasis(scheme))
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 18)
                            .accessibilityAddTraits(.isHeader)
                    }
                case .gap(_, let chapter):
                    gapRow(chapter: chapter)
                case .verse(_, let chapter, let verse, let comments):
                    verseSection(chapter: chapter, verse: verse, comments: comments)
                case .prose(let comments):
                    ForEach(comments) { comment in
                        commentRow(comment)
                    }
                }
            }
        }
    }

    private func gapRow(chapter: Int) -> some View {
        let numeral = settings.language == .he ? HebrewNumerals.string(chapter) : String(chapter)
        return Text(String(format: L10n.text("reading.noCommentary", settings.language), numeral))
            .font(settings.language == .he ? .custom(Theme.hebrewFamily, size: 17, relativeTo: .body) : .body)
            .foregroundStyle(Theme.secondary(scheme))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .overlay(alignment: .bottom) { divider }
    }

    private func verseSection(chapter: Int, verse: Int, comments: [Comment]) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(verseHeading(chapter: chapter, verse: verse))
                .font(settings.language == .he ? .custom(Theme.hebrewFamily, size: 16, relativeTo: .subheadline).weight(.semibold) : .subheadline.weight(.semibold))
                .foregroundStyle(Theme.emphasis(scheme))
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .padding(.top, 18)
                .padding(.bottom, 8)
                .accessibilityAddTraits(.isHeader)
            ForEach(comments) { comment in
                commentRow(comment)
            }
        }
    }

    private func commentRow(_ comment: Comment) -> some View {
        let spoken = HebrewText.plain(comment.body, stripNikud: true)
        return HStack(alignment: .top, spacing: 10) {
            Button {
                library.toggleFavourite(comment.id)
            } label: {
                Image(systemName: library.isFavourite(comment.id) ? "star.fill" : "star")
                    .font(.body)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                L10n.text(library.isFavourite(comment.id) ? "a11y.removeFavourite" : "a11y.addFavourite", settings.language)
            )

            Text(HebrewText.attributed(
                comment.body,
                showNikud: settings.showNikud,
                size: settings.commentarySize,
                textColor: Theme.text(scheme),
                emphasisColor: Theme.emphasis(scheme)
            ))
            .lineSpacing(settings.commentarySize * 0.38)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
            .environment(\.layoutDirection, .rightToLeft)
            .accessibilityLabel(spoken)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .padding(.vertical, 12)
        .id(comment.id)
        .overlay(alignment: .bottom) { divider }
        .background(anchor(for: comment.id))
        .contextMenu {
            Button {
                library.toggleFavourite(comment.id)
            } label: {
                Label(
                    L10n.text(library.isFavourite(comment.id) ? "a11y.removeFavourite" : "a11y.addFavourite", settings.language),
                    systemImage: library.isFavourite(comment.id) ? "star.slash" : "star"
                )
            }
            Button {
                UIPasteboard.general.string = HebrewText.plain(comment.body, stripNikud: !settings.showNikud)
            } label: {
                Label(L10n.text("action.copy", settings.language), systemImage: "doc.on.doc")
            }
            ShareLink(item: passageShareText(comment)) {
                Label(L10n.text("action.sharePassage", settings.language), systemImage: "square.and.arrow.up")
            }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.divider(scheme))
            .frame(height: 0.5)
    }

    private var footer: some View {
        let key = isIntroduction ? "reading.footer.introduction" : "reading.footer.vocalized"
        return Text(L10n.text(key, settings.language))
            .font(.footnote)
            .foregroundStyle(Theme.secondary(scheme))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 28)
    }

    private var isIntroduction: Bool {
        if case .introduction = route { return true }
        return false
    }

    private func verseHeading(chapter: Int, verse: Int) -> String {
        let chapterText = settings.language == .he ? HebrewNumerals.string(chapter) : String(chapter)
        let verseText = settings.language == .he ? HebrewNumerals.string(verse) : String(verse)
        return String(format: L10n.text("reading.place", settings.language), chapterText, verseText)
    }

    private func anchor(for id: Int) -> some View {
        GeometryReader { geo in
            Color.clear.preference(
                key: ReadingAnchorKey.self,
                value: [ReadingAnchor(id: id, minY: geo.frame(in: .named("reading")).minY)]
            )
        }
    }

    private func restore(using proxy: ScrollViewProxy) {
        guard let target = route.scrollTarget else {
            allowTracking = true
            return
        }
        DispatchQueue.main.async {
            proxy.scrollTo(target, anchor: .top)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                allowTracking = true
            }
        }
    }

    private func makeBlocks() -> [ReadingBlock] {
        switch route {
        case .introduction:
            return introductionBlocks()
        case .parasha(let id, _):
            return parashaBlocks(id, includeHeader: false)
        case .weekly(let ids, _):
            return ids.flatMap { parashaBlocks($0, includeHeader: ids.count > 1) }
        }
    }

    private func introductionBlocks() -> [ReadingBlock] {
        let comments = store.introduction()
        guard !comments.isEmpty else { return [] }
        return [.prose(comments: comments)]
    }

    private func parashaBlocks(_ parashaID: Int, includeHeader: Bool) -> [ReadingBlock] {
        let comments = store.comments(parashaID: parashaID)
        let gaps = Set(store.gapChapters(parashaID: parashaID))
        let byChapter = Dictionary(grouping: comments, by: \.chapter)
        let chapters = Set(byChapter.keys).union(gaps).sorted()
        var blocks: [ReadingBlock] = []
        if includeHeader {
            blocks.append(.header(parashaID: parashaID))
        }
        for chapter in chapters {
            let verses = byChapter[chapter] ?? []
            if verses.isEmpty {
                blocks.append(.gap(parashaID: parashaID, chapter: chapter))
                continue
            }
            let byVerse = Dictionary(grouping: verses, by: \.verse)
            for verse in byVerse.keys.sorted() {
                let items = byVerse[verse, default: []].sorted { $0.index < $1.index }
                blocks.append(.verse(parashaID: parashaID, chapter: chapter, verse: verse, comments: items))
            }
        }
        return blocks
    }

    private var portionShareText: String {
        if case .introduction = route {
            return L10n.text("share.introHeading", settings.language)
        }
        return String(format: L10n.text("share.portion", settings.language), navigationTitle)
    }

    private func passageShareText(_ comment: Comment) -> String {
        let plain = HebrewText.plain(comment.body, stripNikud: !settings.showNikud)
        if comment.isIntroduction {
            return String(format: L10n.text("share.intro", settings.language), plain)
        }
        let book = store.book(id: comment.bookID)?.name(for: settings.language) ?? ""
        let chapter = settings.language == .he ? HebrewNumerals.string(comment.chapter) : String(comment.chapter)
        let verse = settings.language == .he ? HebrewNumerals.string(comment.verse) : String(comment.verse)
        return String(
            format: L10n.text("share.passage", settings.language),
            book,
            navigationTitle,
            chapter,
            verse,
            plain
        )
    }
}

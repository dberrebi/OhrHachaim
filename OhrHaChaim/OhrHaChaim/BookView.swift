import SwiftUI

struct BookView: View {
    let bookID: Int
    @Binding var path: NavigationPath
    @Environment(AppSettings.self) private var settings
    @Environment(CommentaryStore.self) private var store
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        List {
            if store.hasIntroduction(bookID: bookID) {
                menuRow(L10n.text("book.introduction", settings.language), identifier: "parasha.intro") {
                    path.append(ReadingRoute.introduction(scrollTo: nil))
                }
            }
            ForEach(store.parashot(in: bookID)) { parasha in
                menuRow(parasha.name(for: settings.language), identifier: "parasha.\(parasha.id)") {
                    path.append(ReadingRoute.parasha(id: parasha.id, scrollTo: nil))
                }
            }
        }
        .modifier(MenuListStyle())
        .listRowSeparator(.hidden)
        .environment(\.defaultMinListRowHeight, 56)
        .studyBar(title: store.book(id: bookID)?.name(for: settings.language) ?? "")
    }

    private func menuRow(_ title: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            CenteredMenuRow(title: title)
        }
        .accessibilityIdentifier(identifier)
        .buttonStyle(.plain)
        .modifier(FullWidthDividerRow())
    }
}

struct ResumeView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(CommentaryStore.self) private var store
    @Environment(UserLibrary.self) private var library
    @Environment(\.colorScheme) private var scheme
    /// The place to resume, fixed when this screen opens. Reading here moves
    /// `lastCommentID`; following it would rebuild the whole page each time.
    @State private var openedAt: Int?

    var body: some View {
        let id = openedAt ?? library.lastCommentID
        Group {
            if let id, let comment = store.comment(id: id) {
                ReadingView(route: library.route(for: comment))
            } else if id != nil {
                message(L10n.text("reading.missingPlace", settings.language))
            } else {
                message(L10n.text("home.resume.empty", settings.language))
            }
        }
        .onAppear {
            if openedAt == nil {
                openedAt = library.lastCommentID
            }
        }
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .font(Theme.menuFont(settings.language))
            .foregroundStyle(Theme.secondary(scheme))
            .multilineTextAlignment(.center)
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background(scheme))
            .studyBar(title: L10n.text("home.resume", settings.language))
    }
}

struct WeeklyView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(CommentaryStore.self) private var store
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if !store.readingCoversToday() {
            message(
                String(
                    format: L10n.text("home.weekly.outOfRange", settings.language),
                    store.yearStart,
                    store.yearEnd
                )
            )
        } else if let reading = store.currentReading(israel: settings.israelCalendar), !reading.parashaIDs.isEmpty {
            ReadingView(route: .weekly(ids: reading.parashaIDs, scrollTo: nil))
        } else {
            message(L10n.text("home.weekly.empty", settings.language))
        }
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .font(Theme.menuFont(settings.language))
            .foregroundStyle(Theme.secondary(scheme))
            .multilineTextAlignment(.center)
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background(scheme))
            .studyBar(title: L10n.text("home.weekly", settings.language))
    }
}

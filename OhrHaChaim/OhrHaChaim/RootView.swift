import SwiftUI

struct RootView: View {
    @Environment(CommentaryStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var selection: SidebarItem?
    @State private var path = NavigationPath()

    var body: some View {
        Group {
            if sizeClass == .regular {
                split
            } else {
                stack
            }
        }
        .background(Theme.background(scheme).ignoresSafeArea())
    }

    /// iPhone, and any compact width: a stack. Each tap appends, including the same row after Back.
    private var stack: some View {
        NavigationStack(path: $path) {
            HomeView { path.append($0) }
                .navigationDestination(for: SidebarItem.self) { item in
                    destination(item)
                }
                .navigationDestination(for: ReadingRoute.self) { route in
                    ReadingView(route: route)
                }
        }
    }

    /// iPad: the sidebar selection drives the detail column.
    private var split: some View {
        NavigationSplitView {
            HomeView { item in
                selection = item
            }
            .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 420)
        } detail: {
            NavigationStack(path: $path) {
                detail
                    .navigationDestination(for: ReadingRoute.self) { route in
                        ReadingView(route: route)
                    }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: selection) { _, _ in
            path = NavigationPath()
        }
    }

    @ViewBuilder
    private var detail: some View {
        if store.loadError != nil {
            MissingTextView()
        } else if let selection {
            destination(selection)
        } else {
            WelcomeView()
        }
    }

    @ViewBuilder
    private func destination(_ item: SidebarItem) -> some View {
        if store.loadError != nil {
            MissingTextView()
        } else {
            switch item {
            case .resume:
                ResumeView()
            case .history:
                HistoryView(path: $path)
            case .weekly:
                WeeklyView()
            case .search:
                SearchView(path: $path)
            case .book(let id):
                BookView(bookID: id, path: $path)
            case .settings:
                SettingsView()
            case .help:
                HelpView()
            case .about:
                AboutView()
            case .favourites:
                FavouritesView(path: $path)
            }
        }
    }
}

struct WelcomeView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 18) {
            Image("ToolbarMark")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)
            Text(L10n.text("app.title", settings.language))
                .font(Theme.menuFont(settings.language))
                .foregroundStyle(Theme.text(scheme))
            Text(L10n.text("welcome.subtitle", settings.language))
                .font(settings.language == .he ? .custom(Theme.hebrewFamily, size: 17, relativeTo: .body) : .body)
                .foregroundStyle(Theme.secondary(scheme))
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background(scheme))
        // The sidebar's bar and this screen already show the app's name, so this bar stays empty.
        .studyBar(title: "")
        .accessibilityElement(children: .combine)
    }
}

struct MissingTextView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Text(L10n.text("data.missing", settings.language))
            .font(Theme.menuFont(settings.language))
            .foregroundStyle(Theme.text(scheme))
            .multilineTextAlignment(.center)
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background(scheme))
            .studyBar(title: L10n.text("app.title", settings.language))
    }
}

struct CenteredMenuRow: View {
    let title: String
    var subtitle: String?
    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var scheme
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(Theme.menuFont(settings.language))
                .foregroundStyle(Theme.text(scheme))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(subtitleFont)
                    .foregroundStyle(Theme.secondary(scheme))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity)
                    // A Hebrew passage under an English title (History, Favourites) is read
                    // with a Hebrew voice. See hebrewSpeech().
                    .environment(\.locale, HebrewText.containsHebrew(subtitle) ? Locale(identifier: "he") : locale)
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private var subtitleFont: Font {
        if settings.language == .he || HebrewText.containsHebrew(subtitle ?? "") {
            return .custom(Theme.hebrewFamily, size: 15, relativeTo: .footnote)
        }
        return .footnote
    }
}

struct MenuListStyle: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.background(scheme))
            .listRowSeparatorTint(Theme.divider(scheme))
    }
}

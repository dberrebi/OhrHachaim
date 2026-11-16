import SwiftUI

struct HomeView: View {
    var onOpen: (SidebarItem) -> Void
    @Environment(AppSettings.self) private var settings
    @Environment(CommentaryStore.self) private var store
    @Environment(UserLibrary.self) private var library
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        List {
            row(.resume, title: L10n.text("home.resume", settings.language), subtitle: resumeSubtitle)
            row(.history, title: L10n.text("home.history", settings.language), subtitle: nil)
            row(.weekly, title: L10n.text("home.weekly", settings.language), subtitle: weeklySubtitle)
            ForEach(store.books) { book in
                row(
                    .book(book.id),
                    title: book.name(for: settings.language),
                    subtitle: nil,
                    identifier: "home.book.\(book.id)"
                )
            }
            row(.settings, title: L10n.text("home.settings", settings.language), subtitle: nil)
            row(.help, title: L10n.text("home.help", settings.language), subtitle: nil)
            row(.about, title: L10n.text("home.about", settings.language), subtitle: nil)
        }
        .modifier(MenuListStyle())
        .environment(\.defaultMinListRowHeight, 56)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.bar, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Image("ToolbarMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .accessibilityHidden(true)
                    Text(L10n.text("app.title", settings.language))
                        .font(Theme.titleFont(for: L10n.text("app.title", settings.language)))
                        .foregroundStyle(Color.white)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel(L10n.text("app.title", settings.language))
            }
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel(L10n.text("a11y.share", settings.language))
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onOpen(.favourites)
                } label: {
                    Image(systemName: "star")
                }
                .accessibilityLabel(L10n.text("a11y.favourites", settings.language))
                .accessibilityIdentifier("home.favourites")
            }
        }
        .navigationTitle(L10n.text("app.title", settings.language))
    }

    private func row(_ item: SidebarItem, title: String, subtitle: String?, identifier: String? = nil) -> some View {
        Button {
            onOpen(item)
        } label: {
            CenteredMenuRow(title: title, subtitle: subtitle)
        }
        .accessibilityIdentifier(identifier ?? item.accessibilityID)
        .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .listRowBackground(Theme.background(scheme))
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            .listRowSeparatorTint(Theme.divider(scheme))
    }

    private var resumeSubtitle: String? {
        guard let id = library.lastCommentID else {
            return L10n.text("home.resume.empty", settings.language)
        }
        guard let comment = store.comment(id: id) else {
            return L10n.text("reading.missingPlace", settings.language)
        }
        return store.locationTitle(for: comment, language: settings.language)
    }

    private var weeklySubtitle: String? {
        guard store.readingCoversToday() else {
            return String(
                format: L10n.text("home.weekly.outOfRange", settings.language),
                store.yearStart,
                store.yearEnd
            )
        }
        guard let reading = store.currentReading(israel: settings.israelCalendar) else {
            return L10n.text("home.weekly.empty", settings.language)
        }
        var title = store.title(for: reading.parashaIDs, language: settings.language)
        if reading.isSimchatTorah {
            title += " · " + L10n.text("weekly.simchat", settings.language)
        }
        return title
    }

    private var shareText: String {
        if let reading = store.currentReading(israel: settings.israelCalendar) {
            let name = store.title(for: reading.parashaIDs, language: settings.language)
            return String(format: L10n.text("share.app", settings.language), name)
        }
        return L10n.text("app.title", settings.language)
    }
}

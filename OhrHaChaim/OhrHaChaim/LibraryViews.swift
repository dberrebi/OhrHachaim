import SwiftUI

struct HistoryView: View {
    @Binding var path: NavigationPath
    @Environment(AppSettings.self) private var settings
    @Environment(CommentaryStore.self) private var store
    @Environment(UserLibrary.self) private var library
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Group {
            if library.history.isEmpty {
                empty(L10n.text("history.empty", settings.language))
            } else {
                List(library.history) { entry in
                    if let comment = store.comment(id: entry.commentID) {
                        Button {
                            path.append(library.route(for: comment))
                        } label: {
                            CenteredMenuRow(
                                title: store.locationTitle(for: comment, language: settings.language),
                                subtitle: HebrewText.preview(comment, stripNikud: !settings.showNikud)
                            )
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .listRowBackground(Theme.background(scheme))
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                        .listRowSeparatorTint(Theme.divider(scheme))
                    }
                }
                .modifier(MenuListStyle())
            }
        }
        .studyBar(title: L10n.text("history.title", settings.language))
    }

    private func empty(_ text: String) -> some View {
        Text(text)
            .font(Theme.menuFont(settings.language))
            .foregroundStyle(Theme.secondary(scheme))
            .multilineTextAlignment(.center)
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background(scheme))
    }
}

struct FavouritesView: View {
    @Binding var path: NavigationPath
    @Environment(AppSettings.self) private var settings
    @Environment(CommentaryStore.self) private var store
    @Environment(UserLibrary.self) private var library
    @Environment(\.colorScheme) private var scheme

    private var comments: [Comment] {
        library.favouriteIDs.compactMap { store.comment(id: $0) }
    }

    var body: some View {
        Group {
            if comments.isEmpty {
                Text(L10n.text("favourites.empty", settings.language))
                    .font(Theme.menuFont(settings.language))
                    .foregroundStyle(Theme.secondary(scheme))
                    .multilineTextAlignment(.center)
                    .padding(32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.background(scheme))
            } else {
                List(comments) { comment in
                    Button {
                        path.append(library.route(for: comment))
                    } label: {
                        CenteredMenuRow(
                            title: store.locationTitle(for: comment, language: settings.language),
                            subtitle: HebrewText.preview(comment, stripNikud: !settings.showNikud)
                        )
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .listRowBackground(Theme.background(scheme))
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    .listRowSeparatorTint(Theme.divider(scheme))
                }
                .modifier(MenuListStyle())
            }
        }
        .studyBar(title: L10n.text("favourites.title", settings.language))
    }
}

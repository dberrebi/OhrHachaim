import SwiftUI

struct SearchView: View {
    @Binding var path: NavigationPath
    @Environment(AppSettings.self) private var settings
    @Environment(CommentaryStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    @State private var query: String
    @State private var results: [SearchHit] = []

    init(path: Binding<NavigationPath>, initialQuery: String? = nil) {
        _path = path
        _query = State(initialValue: initialQuery ?? AppSettings.launchValue("-search-query") ?? "")
    }

    var body: some View {
        List {
            TextField(L10n.text("search.prompt", settings.language), text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(settings.language == .he ? .custom(Theme.hebrewFamily, size: 20, relativeTo: .body) : .body)
                .multilineTextAlignment(settings.language == .he ? .trailing : .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Theme.background(scheme))
                .accessibilityIdentifier("search.field")

            if queryTrimming.isEmpty {
                note(L10n.text("search.empty", settings.language))
            } else if results.isEmpty {
                note(L10n.text("search.noResults", settings.language))
            } else {
                ForEach(results) { hit in
                    Button {
                        open(hit)
                    } label: {
                        resultRow(hit)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("search.hit.\(hit.id)")
                    .modifier(FullWidthDividerRow())
                }
            }
        }
        .modifier(MenuListStyle())
        .listRowSeparator(.hidden)
        .studyBar(title: L10n.text("search.title", settings.language))
        .onAppear { refresh() }
        .onChange(of: query) { _, _ in refresh() }
    }

    private var queryTrimming: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func refresh() {
        results = store.search(query)
    }

    private func open(_ hit: SearchHit) {
        let comment = hit.comment
        if comment.isIntroduction {
            path.append(ReadingRoute.introduction(scrollTo: comment.id))
        } else if let parashaID = comment.parashaID {
            path.append(ReadingRoute.parasha(id: parashaID, scrollTo: comment.id))
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(settings.language == .he ? .custom(Theme.hebrewFamily, size: 17, relativeTo: .body) : .body)
            .foregroundStyle(Theme.secondary(scheme))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(22)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Theme.background(scheme))
    }

    private func resultRow(_ hit: SearchHit) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(store.locationTitle(for: hit.comment, language: settings.language))
                .font(settings.language == .he ? .custom(Theme.hebrewFamily, size: 18, relativeTo: .headline) : .headline)
                .foregroundStyle(Theme.emphasis(scheme))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(hit.snippet)
                .font(.custom(Theme.hebrewFamily, size: 16, relativeTo: .body))
                .foregroundStyle(Theme.text(scheme))
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .environment(\.layoutDirection, .rightToLeft)
        }
        .accessibilityElement(children: .combine)
    }
}

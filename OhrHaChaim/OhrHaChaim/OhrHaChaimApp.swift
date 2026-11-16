import SwiftUI

@main
struct OhrHaChaimApp: App {
    @State private var settings = AppSettings()
    @State private var library = UserLibrary()
    @State private var store = CommentaryStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(library)
                .environment(store)
                .preferredColorScheme(settings.colorScheme)
                .environment(\.layoutDirection, settings.language == .he ? .rightToLeft : .leftToRight)
                .environment(\.locale, Locale(identifier: settings.language.localeIdentifier))
                .tint(Theme.accent)
        }
    }
}

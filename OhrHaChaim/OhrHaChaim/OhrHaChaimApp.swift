import SwiftUI

@main
struct OhrHaChaimApp: App {
    @State private var settings = AppSettings()
    @State private var library = UserLibrary()
    @State private var store = CommentaryStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            // Locale and layout direction follow the in-app language immediately.
            // The process localization does not: SpringBoard, some system sheets,
            // and the VoiceOver language stay on the device language.
            AppearanceHost {
                RootView()
                    .environment(\.layoutDirection, settings.language == .he ? .rightToLeft : .leftToRight)
                    .environment(\.locale, Locale(identifier: settings.language.localeIdentifier))
                    .tint(Theme.accent)
            }
            .environment(settings)
            .environment(library)
            .environment(store)
            .onChange(of: scenePhase) { _, phase in
                if phase != .active {
                    library.flush()
                }
            }
        }
    }
}

/// Mirrors light, dark, or the system appearance.
/// Setting `preferredColorScheme` back to nil on iOS 17 keeps the previous explicit scheme,
/// so System is applied as the live system scheme and updated when that scheme changes.
private struct AppearanceHost<Content: View>: View {
    @Environment(\.colorScheme) private var systemScheme
    @Environment(AppSettings.self) private var settings
    @State private var override: ColorScheme?
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .preferredColorScheme(override)
            .onAppear { apply(settings.appearance) }
            .onChange(of: settings.appearance) { _, choice in
                apply(choice)
            }
            .onChange(of: systemScheme) { _, _ in
                if settings.appearance == .system {
                    apply(.system)
                }
            }
    }

    private func apply(_ choice: AppearanceChoice) {
        switch choice {
        case .light:
            override = .light
        case .dark:
            override = .dark
        case .system:
            override = systemScheme
        }
    }
}

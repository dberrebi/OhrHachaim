import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                Picker(L10n.text("settings.language", settings.language), selection: $settings.language) {
                    Text(L10n.text("settings.language.he", settings.language)).tag(AppLanguage.he)
                    Text(L10n.text("settings.language.en", settings.language)).tag(AppLanguage.en)
                }
                .pickerStyle(.segmented)
            } header: {
                Text(L10n.text("settings.language", settings.language))
            }

            Section {
                Picker(L10n.text("settings.calendar", settings.language), selection: $settings.israelCalendar) {
                    Text(L10n.text("settings.calendar.israel", settings.language)).tag(true)
                    Text(L10n.text("settings.calendar.diaspora", settings.language)).tag(false)
                }
                .pickerStyle(.segmented)
            } header: {
                Text(L10n.text("settings.calendar", settings.language))
            }

            Section {
                Toggle(L10n.text("settings.nikud", settings.language), isOn: $settings.showNikud)
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.text("settings.fontSize", settings.language))
                    Slider(value: $settings.fontScale, in: 0.85...1.75, step: 0.05)
                        .accessibilityLabel(L10n.text("a11y.fontSize", settings.language))
                    Text(HebrewText.attributed(
                        "בְּרֵאשִׁית בָּרָא אֱלֹהִים אֵת הַשָּׁמַיִם וְאֵת הָאָרֶץ",
                        showNikud: settings.showNikud,
                        size: settings.commentarySize,
                        textColor: Theme.text(scheme),
                        emphasisColor: Theme.emphasis(scheme)
                    ))
                    .lineSpacing(6)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .environment(\.layoutDirection, .rightToLeft)
                    .hebrewSpeech()
                }
                .padding(.vertical, 4)
            } header: {
                Text(L10n.text("settings.nikud", settings.language))
            } footer: {
                Text(L10n.text("settings.nikud.footer", settings.language) + "\n" + L10n.text("settings.dynamicType", settings.language))
            }

            Section {
                Picker(L10n.text("settings.appearance", settings.language), selection: $settings.appearance) {
                    Text(L10n.text("settings.appearance.system", settings.language)).tag(AppearanceChoice.system)
                    Text(L10n.text("settings.appearance.light", settings.language)).tag(AppearanceChoice.light)
                    Text(L10n.text("settings.appearance.dark", settings.language)).tag(AppearanceChoice.dark)
                }
                .pickerStyle(.segmented)
            } header: {
                Text(L10n.text("settings.appearance", settings.language))
            }

            Section {
                Link(destination: AppLinks.privacy) {
                    Text(L10n.text("about.privacy", settings.language))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityIdentifier("settings.privacy")
            } footer: {
                Text(L10n.text("settings.privacy.footer", settings.language))
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background(scheme))
        .studyBar(title: L10n.text("settings.title", settings.language))
    }
}

struct HelpView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            Text(L10n.text("help.body", settings.language))
                .font(.body)
                .foregroundStyle(Theme.text(scheme))
                .lineSpacing(6)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(22)
                .multilineTextAlignment(.leading)
        }
        .background(Theme.background(scheme))
        .studyBar(title: L10n.text("help.title", settings.language))
    }
}

struct AboutView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(CommentaryStore.self) private var store
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                section(
                    L10n.text("about.authorHeading", settings.language),
                    L10n.text("about.author", settings.language)
                )
                section(
                    L10n.text("about.sourcesHeading", settings.language),
                    L10n.text("about.sources", settings.language)
                )
                Text(countsLine)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondary(scheme))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(L10n.text("about.offline", settings.language))
                    .font(.footnote)
                    .foregroundStyle(Theme.secondary(scheme))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Link(destination: AppLinks.privacy) {
                    Text(L10n.text("about.privacy", settings.language))
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityIdentifier("about.privacy")
            }
            .padding(22)
            .frame(maxWidth: 740)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background(scheme))
        .studyBar(title: L10n.text("about.title", settings.language))
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.emphasis(scheme))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(body)
                .font(.body)
                .foregroundStyle(Theme.text(scheme))
                .lineSpacing(5)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }

    private var countsLine: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return String(
            format: L10n.text("about.counts", settings.language),
            version,
            build,
            store.yearStart,
            store.yearEnd,
            formattedBuildDate
        )
    }

    private var formattedBuildDate: String {
        let raw = store.meta["generated_utc"] ?? ""
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime]
        guard let date = parser.date(from: raw) else { return raw }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: settings.language.localeIdentifier)
        formatter.timeZone = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

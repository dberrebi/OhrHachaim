import SwiftUI

enum Theme {
    static let bar = Color(red: 0.110, green: 0.086, blue: 0.071)
    static let accent = Color(red: 0.776, green: 0.631, blue: 0.357)
    static let hebrewFamily = "Noto Serif Hebrew"

    static func background(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.078, green: 0.071, blue: 0.063)
            : Color(red: 0.965, green: 0.945, blue: 0.906)
    }

    static func text(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.953, green: 0.922, blue: 0.867)
            : Color(red: 0.133, green: 0.110, blue: 0.086)
    }

    static func secondary(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.769, green: 0.722, blue: 0.651)
            : Color(red: 0.361, green: 0.325, blue: 0.282)
    }

    static func emphasis(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.886, green: 0.710, blue: 0.416)
            : Color(red: 0.478, green: 0.243, blue: 0.071)
    }

    static func divider(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.14)
    }

    static func menuFont(_ language: AppLanguage) -> Font {
        if language == .he {
            return .custom(hebrewFamily, size: 22, relativeTo: .title3)
        }
        return .title3
    }

    static func hebrewFont(size: CGFloat, emphasis: Bool) -> Font {
        let base = Font.custom(hebrewFamily, size: size, relativeTo: .body)
        return emphasis ? base.weight(.bold) : base
    }

    static func containsHebrew(_ text: String) -> Bool {
        HebrewText.containsHebrew(text)
    }

    static func titleFont(for title: String) -> Font {
        if containsHebrew(title) {
            return .custom(hebrewFamily, size: 18, relativeTo: .headline)
        }
        return .headline
    }
}

struct StudyBar: ViewModifier {
    let title: String

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bar, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(Theme.titleFont(for: title))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .accessibilityAddTraits(.isHeader)
                }
            }
    }
}

extension View {
    func studyBar(title: String) -> some View {
        modifier(StudyBar(title: title))
    }
}

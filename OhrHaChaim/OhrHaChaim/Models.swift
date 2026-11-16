import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case he
    case en

    var id: String { rawValue }

    var localeIdentifier: String { self == .he ? "he" : "en" }
}

enum AppearanceChoice: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }
}

struct Book: Identifiable, Hashable {
    let id: Int
    let heName: String
    let enName: String

    func name(for language: AppLanguage) -> String {
        language == .he ? heName : enName
    }
}

struct Parasha: Identifiable, Hashable {
    let id: Int
    let bookID: Int
    let heName: String
    let enName: String
    let sortOrder: Int

    func name(for language: AppLanguage) -> String {
        language == .he ? heName : enName
    }
}

struct Comment: Identifiable, Hashable {
    let id: Int
    let bookID: Int
    let parashaID: Int?
    let chapter: Int
    let verse: Int
    let index: Int
    let dibbur: String
    let body: String
    let source: String

    var isIntroduction: Bool { chapter == 0 || source == "on-your-way-introduction" }
}

struct WeeklyReading: Identifiable, Hashable {
    let date: String
    let israel: Bool
    let hebcalTitle: String
    let hdate: String
    let parashaIDs: [Int]
    let kind: String

    var id: String { "\(date)#\(israel ? 1 : 0)" }
    var isSimchatTorah: Bool { kind == "simchat_torah" }
}

enum SidebarItem: Hashable {
    case resume
    case history
    case weekly
    case book(Int)
    case settings
    case help
    case about
    case favourites
}

enum ReadingRoute: Hashable {
    case parasha(id: Int, scrollTo: Int?)
    case introduction(scrollTo: Int?)
    case weekly(ids: [Int], scrollTo: Int?)

    var scrollTarget: Int? {
        switch self {
        case .parasha(_, let scrollTo), .introduction(let scrollTo), .weekly(_, let scrollTo):
            return scrollTo
        }
    }
}

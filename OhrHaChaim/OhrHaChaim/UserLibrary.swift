import Foundation
import SwiftUI

@MainActor
@Observable
final class AppSettings {
    var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: Key.language) }
    }
    var israelCalendar: Bool {
        didSet { defaults.set(israelCalendar, forKey: Key.israel) }
    }
    var showNikud: Bool {
        didSet { defaults.set(showNikud, forKey: Key.nikud) }
    }
    var fontScale: Double {
        didSet { defaults.set(fontScale, forKey: Key.fontScale) }
    }
    var appearance: AppearanceChoice {
        didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) }
    }

    var colorScheme: ColorScheme? {
        switch appearance {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var commentarySize: CGFloat { 22 * fontScale }

    private let defaults = UserDefaults.standard

    init() {
        let storedLanguage = defaults.string(forKey: Key.language)
        language = AppLanguage(rawValue: storedLanguage ?? "") ?? .he
        if defaults.object(forKey: Key.israel) == nil {
            israelCalendar = true
        } else {
            israelCalendar = defaults.bool(forKey: Key.israel)
        }
        if defaults.object(forKey: Key.nikud) == nil {
            showNikud = true
        } else {
            showNikud = defaults.bool(forKey: Key.nikud)
        }
        if defaults.object(forKey: Key.fontScale) == nil {
            fontScale = 1
        } else {
            fontScale = min(1.75, max(0.85, defaults.double(forKey: Key.fontScale)))
        }
        appearance = AppearanceChoice(rawValue: defaults.string(forKey: Key.appearance) ?? "") ?? .system
    }

    private enum Key {
        static let language = "ui.language"
        static let israel = "calendar.israel"
        static let nikud = "text.nikud"
        static let fontScale = "text.fontScale"
        static let appearance = "ui.appearance"
    }
}

struct HistoryEntry: Codable, Identifiable, Hashable {
    var id: String { "\(parashaID ?? -1)-\(chapter)-\(verse)" }
    var commentID: Int
    var parashaID: Int?
    var chapter: Int
    var verse: Int
    var date: Date
}

@MainActor
@Observable
final class UserLibrary {
    private(set) var lastCommentID: Int?
    private(set) var history: [HistoryEntry] = []
    private(set) var favouriteIDs: [Int] = []

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    init() {
        load()
    }

    func isFavourite(_ id: Int) -> Bool {
        favouriteIDs.contains(id)
    }

    func toggleFavourite(_ id: Int) {
        if let index = favouriteIDs.firstIndex(of: id) {
            favouriteIDs.remove(at: index)
        } else {
            favouriteIDs.insert(id, at: 0)
        }
        save()
    }

    func note(_ comment: Comment) {
        if let first = history.first,
           first.parashaID == comment.parashaID,
           first.chapter == comment.chapter,
           first.verse == comment.verse {
            guard lastCommentID != comment.id else { return }
            lastCommentID = comment.id
            history[0].commentID = comment.id
            history[0].date = Date()
            save()
            return
        }
        lastCommentID = comment.id
        history.removeAll {
            $0.parashaID == comment.parashaID && $0.chapter == comment.chapter && $0.verse == comment.verse
        }
        history.insert(
            HistoryEntry(
                commentID: comment.id,
                parashaID: comment.parashaID,
                chapter: comment.chapter,
                verse: comment.verse,
                date: Date()
            ),
            at: 0
        )
        if history.count > 40 {
            history.removeLast(history.count - 40)
        }
        save()
    }

    func route(for comment: Comment) -> ReadingRoute {
        if comment.isIntroduction {
            return .introduction(scrollTo: comment.id)
        }
        if let parashaID = comment.parashaID {
            return .parasha(id: parashaID, scrollTo: comment.id)
        }
        return .introduction(scrollTo: comment.id)
    }

    private struct Snapshot: Codable {
        var lastCommentID: Int?
        var history: [HistoryEntry]
        var favouriteIDs: [Int]
    }

    private var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("ohr-hachaim-library.json")
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? decoder.decode(Snapshot.self, from: data) else {
            return
        }
        lastCommentID = snapshot.lastCommentID
        history = snapshot.history
        favouriteIDs = snapshot.favouriteIDs
    }

    private func save() {
        let snapshot = Snapshot(lastCommentID: lastCommentID, history: history, favouriteIDs: favouriteIDs)
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // The bundled text is unaffected if the library file cannot be written.
        }
    }
}

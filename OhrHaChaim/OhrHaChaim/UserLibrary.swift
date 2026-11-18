import Foundation
import os
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
            israelCalendar = Self.usesIsraelCalendar(regionCode: Locale.current.region?.identifier)
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
        if let forced = Self.launchValue("-appearance"), let choice = AppearanceChoice(rawValue: forced) {
            appearance = choice
        } else {
            appearance = AppearanceChoice(rawValue: defaults.string(forKey: Key.appearance) ?? "") ?? .system
        }
    }

    /// A value passed as `-flag value` on launch. Used by screenshot runs; a normal launch has none.
    nonisolated static func launchValue(_ flag: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: flag), index + 1 < args.count else { return nil }
        let value = args[index + 1]
        guard !value.hasPrefix("-") else { return nil }
        return value
    }

    /// Israel only when the device region is Israel. Anywhere else starts on the diaspora calendar.
    nonisolated static func usesIsraelCalendar(regionCode: String?) -> Bool {
        regionCode == "IL"
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
    /// One row per parasha. The introduction is its own row.
    var id: String { parashaID.map { "p-\($0)" } ?? "intro" }
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

    private let storageURL: URL?
    private let writeQueue = DispatchQueue(label: "ohr-hachaim.library", qos: .utility)
    private var saveTask: Task<Void, Never>?

    init(storageURL: URL? = nil) {
        self.storageURL = storageURL
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
        saveNow()
    }

    /// Records reading progress for the parasha. Scrolling inside one parasha updates that row,
    /// and reading a parasha again moves its row to the top, even at the same place.
    func note(_ comment: Comment) {
        let alreadyLast = lastCommentID == comment.id
        lastCommentID = comment.id
        if let index = history.firstIndex(where: { $0.parashaID == comment.parashaID }) {
            let samePlace = history[index].commentID == comment.id
                && history[index].chapter == comment.chapter
                && history[index].verse == comment.verse
            // Already the latest row at this place: nothing to change or save.
            if samePlace, index == 0, alreadyLast { return }
            history[index].commentID = comment.id
            history[index].chapter = comment.chapter
            history[index].verse = comment.verse
            history[index].date = Date()
            if index != 0 {
                let entry = history.remove(at: index)
                history.insert(entry, at: 0)
            }
        } else {
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
        }
        scheduleSave()
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
        if let storageURL { return storageURL }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("ohr-hachaim-library.json")
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let snapshot = try decoder.decode(Snapshot.self, from: data)
            lastCommentID = snapshot.lastCommentID
            history = snapshot.history
            favouriteIDs = snapshot.favouriteIDs
        } catch {
            let stamp = Int(Date().timeIntervalSince1970)
            let backup = fileURL.deletingLastPathComponent()
                .appendingPathComponent(fileURL.lastPathComponent + ".corrupt-\(stamp)")
            try? FileManager.default.copyItem(at: fileURL, to: backup)
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        let snapshot = Snapshot(lastCommentID: lastCommentID, history: history, favouriteIDs: favouriteIDs)
        saveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            write(snapshot)
        }
    }

    /// Saves at once, off the main thread. Used after a deliberate change such as a star.
    private func saveNow() {
        saveTask?.cancel()
        saveTask = nil
        write(Snapshot(lastCommentID: lastCommentID, history: history, favouriteIDs: favouriteIDs), wait: false)
    }

    /// Saves at once and returns only when the file is written. Called when the app leaves
    /// the screen, because iOS can suspend or end it right after. The file is a few kilobytes.
    func flush() {
        saveTask?.cancel()
        saveTask = nil
        write(Snapshot(lastCommentID: lastCommentID, history: history, favouriteIDs: favouriteIDs), wait: true)
    }

    nonisolated private static let log = Logger(subsystem: "app.ohrhachaim.OhrHaChaim", category: "library")

    /// Writes go through one serial queue, so a waiting write also waits for any earlier one.
    private func write(_ snapshot: Snapshot, wait: Bool = false) {
        let data: Data
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            data = try encoder.encode(snapshot)
        } catch {
            Self.log.error("Could not prepare the library file: \(error.localizedDescription, privacy: .public)")
            return
        }
        let url = fileURL
        let save: @Sendable () -> Void = {
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                UserLibrary.log.error("Could not save the library file: \(error.localizedDescription, privacy: .public)")
            }
        }
        if wait {
            writeQueue.sync(execute: save)
        } else {
            writeQueue.async(execute: save)
        }
    }
}

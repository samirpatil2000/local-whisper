import Foundation

@MainActor
@Observable
final class HistoryManager {
    var entries: [HistoryEntry] = []
    
    private let fileURL: URL
    private let maxEntries = 500
    
    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("LocalWhisper", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("history.json")
        load()
    }
    
    // MARK: - Operations
    
    func log(originalText: String, action: HistoryAction, styleName: String, resultText: String) {
        let entry = HistoryEntry(
            timestamp: Date(),
            originalText: originalText,
            action: action,
            styleName: styleName,
            resultText: resultText
        )
        entries.insert(entry, at: 0) // newest first
        
        // Cap at maxEntries
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        save()
    }
    
    func clearAll() {
        entries.removeAll()
        save()
    }
    
    func delete(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
        save()
    }
    
    // MARK: - Persistence
    
    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            entries = try JSONDecoder().decode([HistoryEntry].self, from: data)
        } catch {
            print("[HistoryManager] Failed to load: \(error)")
        }
    }
    
    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(entries)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[HistoryManager] Failed to save: \(error)")
        }
    }
}

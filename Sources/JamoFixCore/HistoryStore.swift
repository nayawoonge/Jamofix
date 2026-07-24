import Foundation

/// rename 기록을 JSON 파일로 영속화 (~/Library/Application Support/JamoFix/history.json)
public final class HistoryStore {
    public private(set) var records: [RenameRecord] = []
    private let fileURL: URL
    private let maxRecords = 2000

    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("JamoFix", isDirectory: true)
            try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
            self.fileURL = base.appendingPathComponent("history.json")
        }
        load()
    }

    public func add(_ newRecords: [RenameRecord]) {
        guard !newRecords.isEmpty else { return }
        records.insert(contentsOf: newRecords, at: 0)
        if records.count > maxRecords {
            records.removeLast(records.count - maxRecords)
        }
        save()
    }

    public func remove(_ record: RenameRecord) {
        records.removeAll { $0.id == record.id }
        save()
    }

    public func clear() {
        records.removeAll()
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        records = (try? decoder.decode([RenameRecord].self, from: data)) ?? []
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(records) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

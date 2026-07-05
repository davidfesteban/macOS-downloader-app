import Foundation

struct DownloadStore {
    let applicationSupportDirectory: URL
    let resumeDataDirectory: URL
    private let downloadsFile: URL

    init() {
        let baseDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("MacDownloader", isDirectory: true)

        applicationSupportDirectory = baseDirectory
        resumeDataDirectory = baseDirectory.appendingPathComponent("ResumeData", isDirectory: true)
        downloadsFile = baseDirectory.appendingPathComponent("downloads.json")

        try? FileManager.default.createDirectory(at: resumeDataDirectory, withIntermediateDirectories: true)
    }

    func load() -> [DownloadItem] {
        guard FileManager.default.fileExists(atPath: downloadsFile.path) else { return [] }

        do {
            let data = try Data(contentsOf: downloadsFile)
            return try JSONDecoder.iso8601Decoder.decode([DownloadItem].self, from: data)
        } catch {
            print("Failed to load downloads: \(error)")
            return []
        }
    }

    func save(_ items: [DownloadItem]) {
        do {
            try FileManager.default.createDirectory(at: applicationSupportDirectory, withIntermediateDirectories: true)
            let data = try JSONEncoder.prettyPrinted.encode(items)
            try data.write(to: downloadsFile, options: [.atomic])
        } catch {
            print("Failed to save downloads: \(error)")
        }
    }

    func resumeDataURL(for item: DownloadItem) -> URL {
        let fileName = item.resumeDataFileName ?? "\(item.id.uuidString).resume"
        return resumeDataDirectory.appendingPathComponent(fileName)
    }

    func readResumeData(for item: DownloadItem) -> Data? {
        let url = resumeDataURL(for: item)
        return try? Data(contentsOf: url)
    }

    func writeResumeData(_ data: Data, for item: DownloadItem) -> String? {
        let fileName = item.resumeDataFileName ?? "\(item.id.uuidString).resume"
        let url = resumeDataDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: url, options: [.atomic])
            return fileName
        } catch {
            print("Failed to write resume data: \(error)")
            return nil
        }
    }

    func deleteResumeData(for item: DownloadItem) {
        try? FileManager.default.removeItem(at: resumeDataURL(for: item))
    }
}

extension JSONEncoder {
    static var prettyPrinted: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var iso8601Decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

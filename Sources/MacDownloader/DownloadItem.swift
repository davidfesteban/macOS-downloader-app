import Foundation

enum DownloadState: String, Codable, CaseIterable {
    case queued
    case downloading
    case paused
    case completed
    case failed
    case canceled
}

struct DownloadItem: Identifiable, Codable, Equatable {
    let id: UUID
    var url: URL
    var fileName: String
    var destinationPath: String?
    var state: DownloadState
    var bytesWritten: Int64
    var totalBytes: Int64
    var createdAt: Date
    var updatedAt: Date
    var errorMessage: String?
    var resumeDataFileName: String?
    var speedBytesPerSecond: Double?

    var progress: Double {
        guard totalBytes > 0 else { return 0 }
        return min(max(Double(bytesWritten) / Double(totalBytes), 0), 1)
    }

    var statusText: String {
        switch state {
        case .queued: return "Queued"
        case .downloading: return "Downloading"
        case .paused: return "Paused"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .canceled: return "Canceled"
        }
    }

    var sizeText: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file

        if totalBytes > 0 {
            return "\(formatter.string(fromByteCount: bytesWritten)) of \(formatter.string(fromByteCount: totalBytes))"
        }

        if bytesWritten > 0 {
            return formatter.string(fromByteCount: bytesWritten)
        }

        return "Waiting for size"
    }

    var speedText: String {
        guard state == .downloading, let speedBytesPerSecond, speedBytesPerSecond > 0 else {
            return "Speed --"
        }

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file

        return "\(formatter.string(fromByteCount: Int64(speedBytesPerSecond)))/s"
    }

    var estimatedTimeText: String {
        guard state == .downloading,
              totalBytes > bytesWritten,
              let speedBytesPerSecond,
              speedBytesPerSecond > 0 else {
            return "ETA --"
        }

        let remainingSeconds = Double(totalBytes - bytesWritten) / speedBytesPerSecond
        return "ETA \(Self.durationFormatter.string(from: remainingSeconds) ?? "--")"
    }

    static func make(url: URL, destinationDirectory: URL) -> DownloadItem {
        let inferredName = url.lastPathComponent.isEmpty ? "download-\(UUID().uuidString.prefix(8))" : url.lastPathComponent

        return DownloadItem(
            id: UUID(),
            url: url,
            fileName: inferredName,
            destinationPath: destinationDirectory.appendingPathComponent(inferredName).path,
            state: .queued,
            bytesWritten: 0,
            totalBytes: 0,
            createdAt: Date(),
            updatedAt: Date(),
            errorMessage: nil,
            resumeDataFileName: nil,
            speedBytesPerSecond: nil
        )
    }

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter
    }()
}

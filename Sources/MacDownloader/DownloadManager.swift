import AppKit
import Foundation

@MainActor
final class DownloadManager: NSObject, ObservableObject {
    @Published private(set) var items: [DownloadItem] = []
    @Published var destinationDirectory: URL

    private let store = DownloadStore()
    private lazy var session = makeSession()
    private var tasksByID: [UUID: URLSessionDownloadTask] = [:]
    private var itemIDsByTaskID: [Int: UUID] = [:]
    private var lastProgressByID: [UUID: (date: Date, bytesWritten: Int64)] = [:]

    override init() {
        destinationDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        super.init()
        items = store.load().map { item in
            var mutableItem = item
            if mutableItem.state == .downloading || mutableItem.state == .queued {
                mutableItem.state = mutableItem.resumeDataFileName == nil ? .failed : .paused
                mutableItem.errorMessage = mutableItem.resumeDataFileName == nil ? "Interrupted before resume data was available." : nil
            }
            return mutableItem
        }
        persist()
    }

    func add(urls: [URL]) {
        let newItems = urls.map { DownloadItem.make(url: $0, destinationDirectory: destinationDirectory) }
        items.insert(contentsOf: newItems, at: 0)
        persist()

        for item in newItems {
            start(item)
        }
    }

    func start(_ item: DownloadItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        guard items[index].state != .completed else { return }

        let task: URLSessionDownloadTask
        if let resumeData = store.readResumeData(for: items[index]) {
            task = session.downloadTask(withResumeData: resumeData)
        } else {
            task = session.downloadTask(with: items[index].url)
        }

        items[index].state = .downloading
        items[index].errorMessage = nil
        items[index].speedBytesPerSecond = nil
        items[index].updatedAt = Date()
        lastProgressByID[items[index].id] = (Date(), items[index].bytesWritten)
        tasksByID[items[index].id] = task
        itemIDsByTaskID[task.taskIdentifier] = items[index].id
        persist()
        task.resume()
    }

    func pause(_ item: DownloadItem) {
        guard let task = tasksByID[item.id] else {
            update(item.id) { item in
                item.state = .paused
                item.speedBytesPerSecond = nil
                item.updatedAt = Date()
            }
            return
        }

        task.cancel { [weak self] resumeData in
            Task { @MainActor in
                guard let self else { return }
                self.finishPause(itemID: item.id, taskID: task.taskIdentifier, resumeData: resumeData)
            }
        }
    }

    func cancel(_ item: DownloadItem) {
        tasksByID[item.id]?.cancel()
        tasksByID[item.id] = nil
        lastProgressByID[item.id] = nil
        store.deleteResumeData(for: item)
        update(item.id) { item in
            item.state = .canceled
            item.resumeDataFileName = nil
            item.speedBytesPerSecond = nil
            item.updatedAt = Date()
        }
    }

    func remove(_ item: DownloadItem) {
        tasksByID[item.id]?.cancel()
        tasksByID[item.id] = nil
        lastProgressByID[item.id] = nil
        store.deleteResumeData(for: item)
        items.removeAll { $0.id == item.id }
        persist()
    }

    func reveal(_ item: DownloadItem) {
        guard let destinationPath = item.destinationPath else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: destinationPath)])
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 7 * 24 * 60 * 60
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }

    private func finishPause(itemID: UUID, taskID: Int, resumeData: Data?) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }

        if let resumeData, let fileName = store.writeResumeData(resumeData, for: items[index]) {
            items[index].resumeDataFileName = fileName
        }

        items[index].state = .paused
        items[index].speedBytesPerSecond = nil
        items[index].updatedAt = Date()
        tasksByID[itemID] = nil
        lastProgressByID[itemID] = nil
        itemIDsByTaskID[taskID] = nil
        persist()
    }

    private func update(_ id: UUID, mutate: (inout DownloadItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        mutate(&items[index])
        persist()
    }

    private func persist() {
        store.save(items)
    }
}

extension DownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        Task { @MainActor in
            guard let itemID = itemIDsByTaskID[downloadTask.taskIdentifier] else { return }
            let now = Date()
            let previous = lastProgressByID[itemID]
            let speedBytesPerSecond = calculateSpeed(
                itemID: itemID,
                now: now,
                totalBytesWritten: totalBytesWritten,
                previous: previous
            )

            update(itemID) { item in
                item.bytesWritten = totalBytesWritten
                item.totalBytes = totalBytesExpectedToWrite
                item.speedBytesPerSecond = speedBytesPerSecond
                item.updatedAt = now
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        Task { @MainActor in
            guard let itemID = itemIDsByTaskID[downloadTask.taskIdentifier],
                  let index = items.firstIndex(where: { $0.id == itemID }) else { return }

            let destinationURL = uniqueDestinationURL(for: items[index])

            do {
                try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.moveItem(at: location, to: destinationURL)

                store.deleteResumeData(for: items[index])
                items[index].destinationPath = destinationURL.path
                items[index].state = .completed
                items[index].bytesWritten = downloadTask.countOfBytesReceived
                items[index].totalBytes = max(downloadTask.countOfBytesExpectedToReceive, downloadTask.countOfBytesReceived)
                items[index].resumeDataFileName = nil
                items[index].speedBytesPerSecond = nil
                items[index].updatedAt = Date()
            } catch {
                items[index].state = .failed
                items[index].errorMessage = error.localizedDescription
                items[index].speedBytesPerSecond = nil
                items[index].updatedAt = Date()
            }

            tasksByID[itemID] = nil
            lastProgressByID[itemID] = nil
            itemIDsByTaskID[downloadTask.taskIdentifier] = nil
            persist()
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        Task { @MainActor in
            guard let error,
                  let itemID = itemIDsByTaskID[task.taskIdentifier],
                  let index = items.firstIndex(where: { $0.id == itemID }) else { return }

            if (error as NSError).code == NSURLErrorCancelled && items[index].state == .paused {
                return
            }

            let resumeData = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data
            if let resumeData, let fileName = store.writeResumeData(resumeData, for: items[index]) {
                items[index].resumeDataFileName = fileName
                items[index].state = .paused
                items[index].errorMessage = nil
                items[index].speedBytesPerSecond = nil
            } else if items[index].state != .completed && items[index].state != .canceled {
                items[index].state = .failed
                items[index].errorMessage = error.localizedDescription
                items[index].speedBytesPerSecond = nil
            }

            items[index].updatedAt = Date()
            tasksByID[itemID] = nil
            lastProgressByID[itemID] = nil
            itemIDsByTaskID[task.taskIdentifier] = nil
            persist()
        }
    }

    private func uniqueDestinationURL(for item: DownloadItem) -> URL {
        let baseURL = item.destinationPath.map(URL.init(fileURLWithPath:)) ?? destinationDirectory.appendingPathComponent(item.fileName)
        let directory = baseURL.deletingLastPathComponent()
        let name = baseURL.deletingPathExtension().lastPathComponent
        let pathExtension = baseURL.pathExtension

        var candidate = baseURL
        var counter = 2

        while FileManager.default.fileExists(atPath: candidate.path) {
            let fileName = pathExtension.isEmpty ? "\(name) \(counter)" : "\(name) \(counter).\(pathExtension)"
            candidate = directory.appendingPathComponent(fileName)
            counter += 1
        }

        return candidate
    }

    private func calculateSpeed(
        itemID: UUID,
        now: Date,
        totalBytesWritten: Int64,
        previous: (date: Date, bytesWritten: Int64)?
    ) -> Double? {
        defer {
            lastProgressByID[itemID] = (now, totalBytesWritten)
        }

        guard let previous else { return nil }

        let elapsedSeconds = now.timeIntervalSince(previous.date)
        let byteDelta = totalBytesWritten - previous.bytesWritten

        guard elapsedSeconds > 0, byteDelta > 0 else { return nil }

        let instantSpeed = Double(byteDelta) / elapsedSeconds
        let currentSpeed = items.first(where: { $0.id == itemID })?.speedBytesPerSecond

        guard let currentSpeed, currentSpeed > 0 else {
            return instantSpeed
        }

        return (currentSpeed * 0.7) + (instantSpeed * 0.3)
    }
}

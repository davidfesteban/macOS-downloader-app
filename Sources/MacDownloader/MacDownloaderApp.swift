import SwiftUI

@main
struct MacDownloaderApp: App {
    @StateObject private var downloadManager = DownloadManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(downloadManager)
                .frame(minWidth: 860, minHeight: 560)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Add Download") {
                    NotificationCenter.default.post(name: .showAddDownload, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command])
            }
        }
    }
}

extension Notification.Name {
    static let showAddDownload = Notification.Name("showAddDownload")
}

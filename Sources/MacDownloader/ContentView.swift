import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var downloadManager: DownloadManager
    @State private var isShowingAddSheet = false
    @State private var selectedItemID: DownloadItem.ID?

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedItemID) {
                Section("Downloads") {
                    Label("All", systemImage: "arrow.down.circle")
                        .tag(Optional<DownloadItem.ID>.none)
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 210)
        } detail: {
            VStack(spacing: 0) {
                toolbar

                if downloadManager.items.isEmpty {
                    ContentUnavailableView(
                        "No Downloads",
                        systemImage: "arrow.down.doc",
                        description: Text("Add one or more URLs to download files with resumable progress.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(downloadManager.items) { item in
                            DownloadRow(item: item)
                                .environmentObject(downloadManager)
                                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("MacDownloader")
        }
        .sheet(isPresented: $isShowingAddSheet) {
            AddDownloadView()
                .environmentObject(downloadManager)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showAddDownload)) { _ in
            isShowingAddSheet = true
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Button {
                isShowingAddSheet = true
            } label: {
                Label("Add", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)

            Spacer()

            Button {
                chooseDefaultDestination()
            } label: {
                Label {
                    Text(downloadManager.destinationDirectory.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } icon: {
                    Image(systemName: "externaldrive")
                }
            }
            .help("Choose the default download destination")
        }
        .padding(12)
        .background(.bar)
    }

    private func chooseDefaultDestination() {
        let panel = NSOpenPanel()
        panel.title = "Choose Default Download Folder"
        panel.message = "New downloads will be saved here unless you choose a different folder for them."
        panel.prompt = "Use Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = downloadManager.destinationDirectory

        guard panel.runModal() == .OK, let directory = panel.url else { return }
        downloadManager.setDefaultDestination(directory)
    }
}

struct DownloadRow: View {
    @EnvironmentObject private var downloadManager: DownloadManager
    let item: DownloadItem

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(item.fileName)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer()

                    Text(item.statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: item.progress)
                    .progressViewStyle(.linear)

                HStack(spacing: 8) {
                    Text(item.sizeText)
                    Text(item.speedText)
                    Text(item.estimatedTimeText)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let destinationPath = item.destinationPath {
                    Label(destinationPath, systemImage: "folder")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                if let errorMessage = item.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }

            HStack(spacing: 8) {
                switch item.state {
                case .queued, .failed, .paused, .canceled:
                    Button {
                        downloadManager.start(item)
                    } label: {
                        Image(systemName: "play.fill")
                    }
                    .help("Start")
                case .downloading:
                    Button {
                        downloadManager.pause(item)
                    } label: {
                        Image(systemName: "pause.fill")
                    }
                    .help("Pause")
                case .completed:
                    Button {
                        downloadManager.reveal(item)
                    } label: {
                        Image(systemName: "folder")
                    }
                    .help("Reveal in Finder")
                }

                Button(role: .destructive) {
                    downloadManager.remove(item)
                } label: {
                    Image(systemName: "trash")
                }
                .help("Remove")
            }
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
        }
    }

    private var iconName: String {
        switch item.state {
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .paused: return "pause.circle.fill"
        case .canceled: return "xmark.circle.fill"
        default: return "arrow.down.circle.fill"
        }
    }

    private var iconColor: Color {
        switch item.state {
        case .completed: return .green
        case .failed: return .red
        case .paused: return .orange
        case .canceled: return .secondary
        default: return .accentColor
        }
    }
}

import AppKit
import SwiftUI

struct AddDownloadView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var downloadManager: DownloadManager
    @State private var urlText = ""
    @State private var validationMessage: String?
    @State private var selectedDestination: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add Downloads")
                .font(.title2.weight(.semibold))

            TextEditor(text: $urlText)
                .font(.system(.body, design: .monospaced))
                .frame(minWidth: 560, minHeight: 180)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.quaternary)
                }

            Text("Paste one URL per line.")
                .font(.caption)
                .foregroundStyle(.secondary)

            destinationPicker

            if let validationMessage {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }

                Button("Download") {
                    submit()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
    }

    private func submit() {
        let urls = urlText
            .split(whereSeparator: \.isNewline)
            .compactMap { URL(string: String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { ["http", "https"].contains($0.scheme?.lowercased()) }

        guard !urls.isEmpty else {
            validationMessage = "Enter at least one valid http or https URL."
            return
        }

        downloadManager.add(urls: urls, destinationDirectory: selectedDestination)
        dismiss()
    }

    private var destinationPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Destination")
                .font(.headline)

            HStack(spacing: 8) {
                Image(systemName: selectedDestination == nil ? "externaldrive" : "folder")
                    .foregroundStyle(.secondary)

                Text(effectiveDestination.path)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                if selectedDestination != nil {
                    Button("Use Default") {
                        selectedDestination = nil
                    }
                }

                Button("Choose Folder…") {
                    chooseDestination()
                }
            }

            Text(selectedDestination == nil ? "Using the app's default destination." : "Only these downloads will use this folder.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var effectiveDestination: URL {
        selectedDestination ?? downloadManager.destinationDirectory
    }

    private func chooseDestination() {
        let panel = NSOpenPanel()
        panel.title = "Choose Download Folder"
        panel.message = "These downloads will be saved to this folder."
        panel.prompt = "Choose Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = effectiveDestination

        guard panel.runModal() == .OK, let directory = panel.url else { return }
        selectedDestination = directory.standardizedFileURL
    }
}

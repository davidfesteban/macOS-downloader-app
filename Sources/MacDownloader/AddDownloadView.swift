import SwiftUI

struct AddDownloadView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var downloadManager: DownloadManager
    @State private var urlText = ""
    @State private var validationMessage: String?

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

        downloadManager.add(urls: urls)
        dismiss()
    }
}

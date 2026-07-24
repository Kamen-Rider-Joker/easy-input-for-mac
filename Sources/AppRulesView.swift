import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct AppRulesView: View {
    @ObservedObject var inputManager: InputSourceManager
    @State private var selection: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Lock an input method in specific apps.")
                    .font(.headline)
                Text("A rule switches to that input method when the app gains focus and blocks Shift cycling until you leave.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            Group {
                if inputManager.appRules.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 30, weight: .light))
                            .foregroundStyle(.secondary)
                        Text("No App Rules")
                            .font(.headline)
                        Text("Add an app to keep one input method locked while you use it.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(32)
                } else {
                    List(inputManager.appRules, selection: $selection) { rule in
                        HStack(spacing: 12) {
                            AppIconView(bundleID: rule.bundleID)
                                .frame(width: 28, height: 28)

                            Text(rule.name)
                                .fontWeight(.medium)
                                .lineLimit(1)

                            Spacer(minLength: 16)

                            Picker(
                                "Input method for \(rule.name)",
                                selection: inputSourceBinding(for: rule.bundleID)
                            ) {
                                if !inputManager.isSourceAvailable(rule.inputSourceID) {
                                    Text("Unavailable Input Method").tag(rule.inputSourceID)
                                    Divider()
                                }
                                ForEach(inputManager.availableSources, id: \.id) { source in
                                    Text(source.name).tag(source.id)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(width: 190, alignment: .trailing)
                        }
                        .padding(.vertical, 4)
                        .tag(rule.bundleID)
                        .contextMenu {
                            Button("Remove Rule", role: .destructive) {
                                removeRule(bundleID: rule.bundleID)
                            }
                        }
                    }
                    .listStyle(InsetListStyle())
                    .onDeleteCommand(perform: removeSelected)
                }
            }

            Divider()

            HStack(spacing: 8) {
                Button(action: addApps) {
                    Label("Add App…", systemImage: "plus")
                }
                .help("Add an app rule")

                Button(action: removeSelected) {
                    Label("Remove", systemImage: "minus")
                }
                .disabled(selection.isEmpty)
                .help("Remove the selected app rules")

                Spacer()

                Text(appCountLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .controlSize(.small)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(minWidth: 520, minHeight: 340)
    }

    private var appCountLabel: String {
        let count = inputManager.appRules.count
        return "\(count) \(count == 1 ? "app" : "apps")"
    }

    private func inputSourceBinding(for bundleID: String) -> Binding<String> {
        Binding(
            get: {
                inputManager.appRules.first(where: { $0.bundleID == bundleID })?.inputSourceID ?? ""
            },
            set: { inputManager.updateAppRule(bundleID: bundleID, inputSourceID: $0) }
        )
    }

    private func addApps() {
        let panel = NSOpenPanel()
        panel.title = "Add App Rule"
        panel.message = "Choose one or more apps whose input method ShiftType should lock."
        panel.prompt = "Add"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.treatsFilePackagesAsDirectories = false

        guard panel.runModal() == .OK else { return }

        for url in panel.urls {
            guard let bundle = Bundle(url: url),
                  let bundleID = bundle.bundleIdentifier else {
                continue
            }
            let name = url.deletingPathExtension().lastPathComponent
            inputManager.addAppRule(bundleID: bundleID, name: name)
        }
    }

    private func removeSelected() {
        for bundleID in selection {
            inputManager.removeAppRule(bundleID: bundleID)
        }
        selection.removeAll()
    }

    private func removeRule(bundleID: String) {
        inputManager.removeAppRule(bundleID: bundleID)
        selection.remove(bundleID)
    }
}

struct AppIconView: NSViewRepresentable {
    let bundleID: String

    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.setAccessibilityElement(false)
        return imageView
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            nsView.image = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            nsView.image = NSImage(systemSymbolName: "app", accessibilityDescription: nil)
        }
    }
}

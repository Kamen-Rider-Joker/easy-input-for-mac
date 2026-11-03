import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct AppRulesView: View {
    @ObservedObject var inputManager: InputSourceManager
    @ObservedObject var localization: LocalizationManager
    @State private var selection: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                Text(localization.string(.appRulesHeadline))
                    .font(.headline)
                Text(localization.string(.appRulesDetail))
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
                        Text(localization.string(.noAppRules))
                            .font(.headline)
                        Text(localization.string(.noAppRulesDetail))
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
                                localization.inputMethodLabel(for: rule.name),
                                selection: inputSourceBinding(for: rule.bundleID)
                            ) {
                                if !inputManager.isSourceAvailable(rule.inputSourceID) {
                                    Text(localization.string(.unavailableInputMethod))
                                        .tag(rule.inputSourceID)
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
                            Button(localization.string(.removeRule), role: .destructive) {
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
                    Label(localization.string(.addApp), systemImage: "plus")
                }
                .help(localization.string(.addAppHelp))

                Button(action: removeSelected) {
                    Label(localization.string(.remove), systemImage: "minus")
                }
                .disabled(selection.isEmpty)
                .help(localization.string(.removeHelp))

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
        localization.appCount(inputManager.appRules.count)
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
        panel.title = localization.string(.addAppRuleTitle)
        panel.message = localization.string(.addAppRuleMessage)
        panel.prompt = localization.string(.addButton)
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

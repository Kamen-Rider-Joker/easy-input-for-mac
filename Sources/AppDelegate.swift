import AppKit
import Combine
import Security
import ServiceManagement
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let inputManager = InputSourceManager()
    let localization = LocalizationManager()

    private let shiftMonitor = ShiftKeyMonitor()
    private var statusItem: NSStatusItem!
    private var cancellable: AnyCancellable?
    private var localizationCancellable: AnyCancellable?
    private var accessibilityAllowed = false
    private var servicesStarted = false
    private var serviceStartFailed = false
    private var onboardingCompleted = false
    private var onboardingStep: ShiftTypeOnboardingStep = .welcome
    private var practiceSucceeded = false
    private var practiceSourceName: String?
    private var systemSettingsDeactivationObserver: NSObjectProtocol?
    private var onboardingModel: ShiftTypeOnboardingModel?
    private var onboardingWindowController: OnboardingWindowController?
    private var appRulesWindow: NSWindow?
    private var statusPopover: NSPopover?
    private var statusPopoverModel: ShiftTypePopoverModel?

    private static let onboardingCompletedKey = "onboardingCompleted"
    private static let onboardingStepKey = "onboardingStep"
    private static let adHocBuildIdentityKey = "adHocBuildIdentity"
    private static let adHocSignatureFlag: UInt32 = 0x0002

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = NSApplication.shared.setActivationPolicy(.accessory)
        prepareOnboardingForCurrentBuild()
        refreshPermissionState()
        loadOnboardingState()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(toggleStatusPopover(_:))
        statusPopoverModel = ShiftTypePopoverModel(state: makeStatusPopoverState())
        updateInterface()

        localizationCancellable = localization.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async {
                self?.updateInterface()
            }
        }

        cancellable = inputManager.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async {
                self?.updateInterface()
            }
        }

        shiftMonitor.onShiftTap = { [weak self] in
            guard let self else { return }
            let result = self.inputManager.cycleInputMethod()
            guard !self.onboardingCompleted,
                  self.onboardingStep == .practice,
                  let result,
                  result.didChange else {
                return
            }
            self.practiceSucceeded = true
            self.practiceSourceName = result.sourceName
            self.updateInterface()
        }

        Diagnostics.event("startup accessibility=\(accessibilityAllowed) \(runtimeSummary)")
        startPermissionObservation()

        if accessibilityAllowed { startServices() }

        if !accessibilityAllowed || !onboardingCompleted {
            DispatchQueue.main.async { [weak self] in
                self?.showPermissionSetup()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopPermissionObservation()
        stopServices()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        refreshPermission()
        localization.refreshSystemLanguage()
        updateInterface()
    }

    // MARK: - Status Item

    private func updateInterface() {
        guard statusItem != nil else { return }
        updateIcon()
        updateStatusPopover()
        onboardingModel?.update(state: makeOnboardingState())
        appRulesWindow?.title = localization.string(.appRulesWindowTitle)
        onboardingWindowController?.setTitle(localization.string(.setUpWindowTitle))
    }

    private func updateIcon() {
        let symbolName = servicesStarted ? "shift.fill" : "shift"
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "ShiftType")
        image?.size = NSSize(width: 18, height: 18)
        image?.isTemplate = true
        statusItem.button?.image = image

        if !accessibilityAllowed || !onboardingCompleted {
            statusItem.button?.toolTip = accessibilityAllowed
                ? localization.string(.finishSetupTooltip)
                : localization.string(.needsPermissionTooltip)
        } else if serviceStartFailed {
            statusItem.button?.toolTip = localization.string(.monitoringTooltip)
        } else if let sourceName = inputManager.currentSourceName {
            statusItem.button?.toolTip = "ShiftType · \(sourceName)"
        } else {
            statusItem.button?.toolTip = "ShiftType"
        }
    }

    private func updateStatusPopover() {
        statusPopoverModel?.update(state: makeStatusPopoverState())
    }

    private func makeStatusPopoverState() -> ShiftTypePopoverState {
        let mode: ShiftTypePopoverMode
        if !accessibilityAllowed || !onboardingCompleted {
            mode = .setup
        } else if serviceStartFailed {
            mode = .serviceUnavailable
        } else {
            mode = .ready
        }

        return ShiftTypePopoverState(
            mode: mode,
            currentSourceName: inputManager.currentSourceName,
            appRuleCount: inputManager.appRules.count,
            launchAtLoginEnabled: isLaunchAtLoginEnabled
        )
    }

    @objc private func toggleStatusPopover(_ sender: NSStatusBarButton) {
        if statusPopover?.isShown == true {
            statusPopover?.performClose(nil)
            return
        }

        inputManager.refreshSources()
        updateStatusPopover()

        let popover = statusPopover ?? makeStatusPopover()
        statusPopover = popover

        NSApplication.shared.activate(ignoringOtherApps: true)
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
    }

    private func makeStatusPopover() -> NSPopover {
        let popoverModel = statusPopoverModel ?? ShiftTypePopoverModel(state: makeStatusPopoverState())
        statusPopoverModel = popoverModel

        let view = ShiftTypePopoverView(
            model: popoverModel,
            localization: localization,
            onSetup: { [weak self] in
                self?.closeStatusPopover()
                self?.showPermissionSetup()
            },
            onRetry: { [weak self] in
                self?.retryServices()
            },
            onAppRules: { [weak self] in
                self?.closeStatusPopover()
                self?.showAppRules()
            },
            onToggleLaunchAtLogin: { [weak self] in
                self?.toggleLaunchAtLogin()
            },
            onLanguageChange: { [weak self] preference in
                self?.localization.select(preference)
            },
            onAbout: { [weak self] in
                self?.closeStatusPopover()
                self?.showAbout()
            },
            onQuit: {
                NSApplication.shared.terminate(nil)
            }
        )
        let hostingController = NSHostingController(rootView: view)
        hostingController.sizingOptions = .preferredContentSize

        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = hostingController
        return popover
    }

    private func closeStatusPopover() {
        statusPopover?.performClose(nil)
    }

    // MARK: - Actions

    @objc private func retryServices() {
        serviceStartFailed = false
        refreshPermissionState()
        if accessibilityAllowed {
            startServices()
        } else {
            updateInterface()
        }
    }

    @objc private func showAppRules() {
        if let appRulesWindow {
            appRulesWindow.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        let view = AppRulesView(
            inputManager: inputManager,
            localization: localization
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 420),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = localization.string(.appRulesWindowTitle)
        window.contentView = NSHostingView(rootView: view)
        window.contentMinSize = NSSize(width: 520, height: 340)
        window.tabbingMode = .disallowed
        window.setFrameAutosaveName("ShiftTypeAppRulesWindow")
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        appRulesWindow = window
    }

    @objc private func showPermissionSetup() {
        if onboardingCompleted && !accessibilityAllowed {
            onboardingStep = .accessibility
        }

        if let onboardingModel {
            onboardingModel.update(state: makeOnboardingState())
        } else {
            let model = ShiftTypeOnboardingModel(state: makeOnboardingState())
            onboardingModel = model
            let view = makeOnboardingView(model: model)
            onboardingWindowController = OnboardingWindowController(
                view: view,
                title: localization.string(.setUpWindowTitle)
            )
        }

        NSApplication.shared.activate(ignoringOtherApps: true)
        onboardingWindowController?.present()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            switch SMAppService.mainApp.status {
            case .enabled:
                try SMAppService.mainApp.unregister()
            case .requiresApproval:
                SMAppService.openSystemSettingsLoginItems()
            case .notRegistered:
                try SMAppService.mainApp.register()
            case .notFound:
                showLaunchAtLoginError(localization.string(.loginItemNotFound))
            @unknown default:
                showLaunchAtLoginError(localization.string(.loginItemUnknownStatus))
            }
        } catch {
            Diagnostics.event("launch-at-login-failed error=\(error)")
            showLaunchAtLoginError(error.localizedDescription)
        }
        updateStatusPopover()
    }

    @objc private func showAbout() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .applicationName: "ShiftType",
            .applicationVersion: version,
            .credits: NSAttributedString(
                string: localization.string(.aboutCredits),
                attributes: [.font: NSFont.systemFont(ofSize: 11)]
            ),
        ])
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func showLaunchAtLoginError(_ details: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = localization.string(.launchAtLoginErrorTitle)
        alert.informativeText = details
        alert.addButton(withTitle: localization.string(.ok))
        NSApplication.shared.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    // MARK: - Permissions

    private func startPermissionObservation() {
        systemSettingsDeactivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didDeactivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier == "com.apple.systempreferences" else {
                return
            }
            self?.refreshPermission()
        }
    }

    private func stopPermissionObservation() {
        if let systemSettingsDeactivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(systemSettingsDeactivationObserver)
        }
        systemSettingsDeactivationObserver = nil
    }

    private func refreshPermissionState() {
        accessibilityAllowed = AXIsProcessTrusted()
    }

    private func refreshPermission() {
        let previousAccessibility = accessibilityAllowed
        refreshPermissionState()

        if accessibilityAllowed {
            if !servicesStarted && !serviceStartFailed {
                startServices()
            }
        } else {
            serviceStartFailed = false
            stopServices()
        }

        guard previousAccessibility != accessibilityAllowed else { return }

        Diagnostics.event("permission-changed accessibility=\(accessibilityAllowed)")
        updateInterface()
        if accessibilityAllowed, onboardingWindowController?.window?.isVisible == true {
            NSApplication.shared.activate(ignoringOtherApps: true)
            onboardingWindowController?.present()
        }
    }

    private func requestAccessibilityPermission() {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true,
        ] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refreshPermission()
    }

    private func openAccessibilitySettings() {
        openSystemSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    private func openKeyboardSettings() {
        openSystemSettings("x-apple.systempreferences:com.apple.Keyboard-Settings.extension")
    }

    private func openSystemSettings(_ path: String) {
        guard let url = URL(string: path) else { return }
        NSWorkspace.shared.open(url)
    }

    private func makeOnboardingState() -> ShiftTypeOnboardingState {
        ShiftTypeOnboardingState(
            step: onboardingStep,
            isRecovery: onboardingCompleted,
            accessibilityAllowed: accessibilityAllowed,
            serviceStartFailed: serviceStartFailed,
            availableSourceCount: inputManager.availableSources.count,
            currentSourceName: inputManager.currentSourceName,
            practiceSucceeded: practiceSucceeded,
            practiceSourceName: practiceSourceName
        )
    }

    private func makeOnboardingView(
        model: ShiftTypeOnboardingModel
    ) -> ShiftTypeOnboardingView {
        ShiftTypeOnboardingView(
            model: model,
            localization: localization,
            onBack: { [weak self] in self?.goBackInOnboarding() },
            onContinue: { [weak self] in self?.advanceOnboarding() },
            onRetryServices: { [weak self] in self?.retryServices() },
            onRequestAccessibility: { [weak self] in self?.requestAccessibilityPermission() },
            onOpenAccessibilitySettings: { [weak self] in self?.openAccessibilitySettings() },
            onOpenKeyboardSettings: { [weak self] in self?.openKeyboardSettings() },
            onLanguageChange: { [weak self] preference in
                self?.localization.select(preference)
            }
        )
    }

    private func loadOnboardingState() {
        let defaults = UserDefaults.standard
        onboardingCompleted = defaults.bool(forKey: Self.onboardingCompletedKey)
        onboardingStep = ShiftTypeOnboardingStep(
            rawValue: defaults.integer(forKey: Self.onboardingStepKey)
        ) ?? .welcome

        if !accessibilityAllowed && (onboardingCompleted || onboardingStep != .welcome) {
            onboardingStep = .accessibility
        }
    }

    private func prepareOnboardingForCurrentBuild() {
        let defaults = UserDefaults.standard
        guard let identity = currentAdHocBuildIdentity() else {
            defaults.removeObject(forKey: Self.adHocBuildIdentityKey)
            return
        }

        guard defaults.string(forKey: Self.adHocBuildIdentityKey) != identity else {
            return
        }

        defaults.set(identity, forKey: Self.adHocBuildIdentityKey)
        defaults.set(false, forKey: Self.onboardingCompletedKey)
        defaults.set(ShiftTypeOnboardingStep.welcome.rawValue, forKey: Self.onboardingStepKey)
    }

    private func currentAdHocBuildIdentity() -> String? {
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(
            Bundle.main.bundleURL as CFURL,
            [],
            &staticCode
        ) == errSecSuccess, let staticCode else {
            return nil
        }

        var signingInformation: CFDictionary?
        guard SecCodeCopySigningInformation(
            staticCode,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &signingInformation
        ) == errSecSuccess, let signingInformation else {
            return nil
        }

        let information = signingInformation as NSDictionary
        guard let flags = information[kSecCodeInfoFlags] as? NSNumber,
              flags.uint32Value & Self.adHocSignatureFlag != 0,
              let codeHash = information[kSecCodeInfoUnique] as? Data else {
            return nil
        }

        return codeHash.map { String(format: "%02x", $0) }.joined()
    }

    private func setOnboardingStep(_ step: ShiftTypeOnboardingStep) {
        onboardingStep = step
        UserDefaults.standard.set(step.rawValue, forKey: Self.onboardingStepKey)
        updateInterface()
    }

    private func goBackInOnboarding() {
        guard let previous = ShiftTypeOnboardingStep(rawValue: onboardingStep.rawValue - 1) else {
            return
        }
        if onboardingStep == .practice {
            practiceSucceeded = false
            practiceSourceName = nil
        }
        setOnboardingStep(previous)
    }

    private func advanceOnboarding() {
        switch onboardingStep {
        case .welcome:
            setOnboardingStep(.accessibility)
        case .accessibility:
            guard accessibilityAllowed else { return }
            if onboardingCompleted {
                onboardingWindowController?.close()
            } else {
                practiceSucceeded = false
                practiceSourceName = nil
                inputManager.refreshSources()
                setOnboardingStep(.practice)
            }
        case .practice:
            guard practiceSucceeded else { return }
            onboardingCompleted = true
            let defaults = UserDefaults.standard
            defaults.set(true, forKey: Self.onboardingCompletedKey)
            defaults.set(ShiftTypeOnboardingStep.practice.rawValue, forKey: Self.onboardingStepKey)
            onboardingWindowController?.close()
            updateInterface()
        }
    }

    // MARK: - Services

    private func startServices() {
        guard accessibilityAllowed, !servicesStarted else { return }

        serviceStartFailed = false
        inputManager.start()
        guard shiftMonitor.start() else {
            Diagnostics.event("event-tap-start-failed")
            inputManager.stop()
            serviceStartFailed = true
            updateInterface()
            return
        }

        servicesStarted = true
        Diagnostics.event("services-started")
        updateInterface()
    }

    private func stopServices() {
        guard servicesStarted else { return }
        shiftMonitor.stop()
        inputManager.stop()
        servicesStarted = false
        Diagnostics.event("services-stopped")
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) === appRulesWindow {
            appRulesWindow = nil
        }
    }

    // MARK: - Runtime

    private var isLaunchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    private var runtimeSummary: String {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "debug"
        return "version=\(version) pid=\(ProcessInfo.processInfo.processIdentifier) bundleURL=\(Bundle.main.bundleURL.path)"
    }
}

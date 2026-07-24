import AppKit
import Carbon
import Combine

struct AppRule: Codable, Identifiable, Hashable {
    let bundleID: String
    let name: String
    var inputSourceID: String
    var id: String { bundleID }
}

struct InputSourceCycleResult {
    let sourceName: String
    let didChange: Bool
}

private struct AppFocusObservation {
    let observer: AXObserver
    let applicationElement: AXUIElement
    let notifications: [CFString]
}

final class InputSourceManager: ObservableObject {
    @Published private(set) var availableSources: [(id: String, name: String)] = []
    @Published private(set) var currentSourceID: String?
    @Published private(set) var appRules: [AppRule] = []

    private var sourceObserver: NSObjectProtocol?
    private var appActivationObserver: NSObjectProtocol?
    private var appLaunchObserver: NSObjectProtocol?
    private var appTerminationObserver: NSObjectProtocol?
    private var debounceWorkItem: DispatchWorkItem?
    private var appFocusObservations: [pid_t: AppFocusObservation] = [:]
    private var isStarted = false
    private var currentFocusedBundleID: String?
    private var rulesByBundleID: [String: AppRule] = [:]
    private let systemWideElement = AXUIElementCreateSystemWide()

    private static let appRulesKey = "appRules"

    deinit { stop() }

    var currentSourceName: String? {
        guard let currentSourceID else { return nil }
        return availableSources.first(where: { $0.id == currentSourceID })?.name
    }

    // MARK: - Lifecycle

    func start() {
        guard !isStarted else { return }
        isStarted = true
        loadAppRules()
        refreshSources()
        refreshCurrentSource()
        currentFocusedBundleID = resolvedFocusedBundleID()
        startSourceMonitoring()
        startAppActivationMonitoring()
        enforceRuleForCurrentApp()
    }

    func stop() {
        guard isStarted else { return }
        isStarted = false
        stopSourceMonitoring()
        stopAppActivationMonitoring()
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
    }

    // MARK: - Input Sources

    func refreshSources() {
        guard let sourceList = selectableSources() else {
            if !availableSources.isEmpty { availableSources = [] }
            return
        }

        let sources = sourceList.compactMap { source -> (id: String, name: String)? in
            guard let id = source.id, let name = source.localizedName else { return nil }
            return (id: id, name: name)
        }

        if sources.map(\.id) != availableSources.map(\.id) {
            availableSources = sources
        }
    }

    @discardableResult
    func cycleInputMethod() -> InputSourceCycleResult? {
        guard isStarted else { return nil }

        refreshSources()
        currentFocusedBundleID = resolvedFocusedBundleID()
        if let rule = activeRule, isSourceAvailable(rule.inputSourceID) {
            if currentKeyboardSourceID() != rule.inputSourceID {
                selectSource(rule.inputSourceID)
            }
            return nil
        }

        guard !availableSources.isEmpty else { return nil }

        let currentID = currentKeyboardSourceID()
        let nextIndex: Int
        if let currentID,
           let currentIndex = availableSources.firstIndex(where: { $0.id == currentID }) {
            nextIndex = availableSources.index(after: currentIndex) % availableSources.count
        } else {
            nextIndex = availableSources.startIndex
        }

        let nextSource = availableSources[nextIndex]
        guard selectSource(nextSource.id) else { return nil }
        return InputSourceCycleResult(
            sourceName: nextSource.name,
            didChange: nextSource.id != currentID
        )
    }

    func isSourceAvailable(_ sourceID: String) -> Bool {
        availableSources.contains { $0.id == sourceID }
    }

    private func selectableSources() -> [TISInputSource]? {
        guard let list = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
            return nil
        }

        return list.filter { source in
            source.isEnabled
            && source.isSelectCapable
            && source.category == kTISCategoryKeyboardInputSource as String
        }
    }

    private func currentKeyboardSourceID() -> String? {
        TISCopyCurrentKeyboardInputSource().takeRetainedValue().id
    }

    private func refreshCurrentSource() {
        let sourceID = currentKeyboardSourceID()
        if sourceID != currentSourceID {
            currentSourceID = sourceID
        }
    }

    @discardableResult
    private func selectSource(_ sourceID: String) -> Bool {
        guard isStarted,
              let target = selectableSources()?.first(where: { $0.id == sourceID }) else {
            return false
        }

        let status = TISSelectInputSource(target)
        guard status == noErr else {
            Diagnostics.event("source-selection-failed sourceID=\(sourceID) status=\(status)")
            return false
        }

        if currentSourceID != sourceID {
            currentSourceID = sourceID
        }
        return true
    }

    // MARK: - Source Monitoring

    private func startSourceMonitoring() {
        sourceObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleSourceChange()
        }
    }

    private func stopSourceMonitoring() {
        if let sourceObserver {
            DistributedNotificationCenter.default().removeObserver(sourceObserver)
        }
        sourceObserver = nil
    }

    private func handleSourceChange() {
        refreshSources()
        refreshCurrentSource()
        guard let rule = activeRule, isSourceAvailable(rule.inputSourceID) else { return }

        debounceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.currentFocusedBundleID = self.resolvedFocusedBundleID()
            guard let currentRule = self.activeRule,
                  currentRule.bundleID == rule.bundleID,
                  self.currentKeyboardSourceID() != currentRule.inputSourceID else {
                return
            }
            self.selectSource(currentRule.inputSourceID)
        }
        debounceWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
    }

    // MARK: - App Focus

    private func startAppActivationMonitoring() {
        appActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }
            self.currentFocusedBundleID = app.bundleIdentifier
            self.refreshSources()
            self.enforceRuleForCurrentApp()
        }

        appLaunchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshRuleAppFocusObservers()
            self?.handleObservedFocusChange()
        }

        appTerminationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }
            self.removeRuleAppFocusObserver(processIdentifier: app.processIdentifier)
            self.handleObservedFocusChange()
        }

        refreshRuleAppFocusObservers()
    }

    private func stopAppActivationMonitoring() {
        if let appActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(appActivationObserver)
        }
        if let appLaunchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(appLaunchObserver)
        }
        if let appTerminationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(appTerminationObserver)
        }
        appActivationObserver = nil
        appLaunchObserver = nil
        appTerminationObserver = nil
        removeAllRuleAppFocusObservers()
    }

    fileprivate func handleObservedFocusChange() {
        guard isStarted, let bundleID = resolvedFocusedBundleID() else { return }
        currentFocusedBundleID = bundleID
        refreshSources()
        enforceRuleForCurrentApp()
    }

    private func refreshRuleAppFocusObservers() {
        guard isStarted else { return }

        let ruleBundleIDs = Set(appRules.map(\.bundleID))
        let runningRuleApps = NSWorkspace.shared.runningApplications.filter { app in
            guard let bundleID = app.bundleIdentifier else { return false }
            return ruleBundleIDs.contains(bundleID)
        }
        let activeProcessIdentifiers = Set(runningRuleApps.map(\.processIdentifier))

        for processIdentifier in Array(appFocusObservations.keys)
            where !activeProcessIdentifiers.contains(processIdentifier) {
            removeRuleAppFocusObserver(processIdentifier: processIdentifier)
        }

        for app in runningRuleApps where appFocusObservations[app.processIdentifier] == nil {
            addRuleAppFocusObserver(processIdentifier: app.processIdentifier)
        }
    }

    private func addRuleAppFocusObserver(processIdentifier: pid_t) {
        var rawObserver: AXObserver?
        guard AXObserverCreate(processIdentifier, shiftTypeAppFocusCallback, &rawObserver) == .success,
              let observer = rawObserver else {
            return
        }

        let applicationElement = AXUIElementCreateApplication(processIdentifier)
        let notifications = [
            kAXFocusedWindowChangedNotification as CFString,
            kAXFocusedUIElementChangedNotification as CFString,
        ].filter { notification in
            AXObserverAddNotification(
                observer,
                applicationElement,
                notification,
                Unmanaged.passUnretained(self).toOpaque()
            ) == .success
        }

        guard !notifications.isEmpty else { return }

        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .commonModes
        )
        appFocusObservations[processIdentifier] = AppFocusObservation(
            observer: observer,
            applicationElement: applicationElement,
            notifications: notifications
        )
    }

    private func removeRuleAppFocusObserver(processIdentifier: pid_t) {
        guard let observation = appFocusObservations.removeValue(forKey: processIdentifier) else {
            return
        }

        for notification in observation.notifications {
            AXObserverRemoveNotification(
                observation.observer,
                observation.applicationElement,
                notification
            )
        }
        CFRunLoopRemoveSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observation.observer),
            .commonModes
        )
    }

    private func removeAllRuleAppFocusObservers() {
        for processIdentifier in Array(appFocusObservations.keys) {
            removeRuleAppFocusObserver(processIdentifier: processIdentifier)
        }
    }

    private func enforceRuleForCurrentApp() {
        guard let rule = activeRule,
              isSourceAvailable(rule.inputSourceID),
              currentKeyboardSourceID() != rule.inputSourceID else {
            return
        }
        selectSource(rule.inputSourceID)
    }

    private var activeRule: AppRule? {
        guard let currentFocusedBundleID else { return nil }
        return rulesByBundleID[currentFocusedBundleID]
    }

    private func resolvedFocusedBundleID() -> String? {
        focusedBundleID(for: kAXFocusedWindowAttribute as CFString)
        ?? focusedBundleID(for: kAXFocusedApplicationAttribute as CFString)
        ?? focusedBundleID(for: kAXFocusedUIElementAttribute as CFString)
        ?? NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    private func focusedBundleID(for attribute: CFString) -> String? {
        var rawElement: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWideElement, attribute, &rawElement) == .success,
              let element = rawElement else {
            return nil
        }

        var pid: pid_t = 0
        guard AXUIElementGetPid(element as! AXUIElement, &pid) == .success else { return nil }
        return NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
    }

    // MARK: - App Rules

    private func loadAppRules() {
        guard let data = UserDefaults.standard.data(forKey: Self.appRulesKey),
              let rules = try? JSONDecoder().decode([AppRule].self, from: data) else {
            return
        }
        appRules = rules
        rebuildRuleCache()
    }

    private func saveAppRules() {
        guard let data = try? JSONEncoder().encode(appRules) else { return }
        UserDefaults.standard.set(data, forKey: Self.appRulesKey)
        rebuildRuleCache()
        refreshRuleAppFocusObservers()
        enforceRuleForCurrentApp()
    }

    private func rebuildRuleCache() {
        rulesByBundleID = Dictionary(uniqueKeysWithValues: appRules.map { ($0.bundleID, $0) })
    }

    func addAppRule(bundleID: String, name: String) {
        guard rulesByBundleID[bundleID] == nil,
              let inputSourceID = currentKeyboardSourceID() ?? availableSources.first?.id else {
            return
        }
        appRules.append(AppRule(bundleID: bundleID, name: name, inputSourceID: inputSourceID))
        saveAppRules()
    }

    func removeAppRule(bundleID: String) {
        appRules.removeAll { $0.bundleID == bundleID }
        saveAppRules()
    }

    func updateAppRule(bundleID: String, inputSourceID: String) {
        guard let index = appRules.firstIndex(where: { $0.bundleID == bundleID }) else { return }
        appRules[index].inputSourceID = inputSourceID
        saveAppRules()
    }
}

private func shiftTypeAppFocusCallback(
    observer: AXObserver,
    element: AXUIElement,
    notification: CFString,
    refcon: UnsafeMutableRawPointer?
) {
    guard let refcon else { return }
    let manager = Unmanaged<InputSourceManager>.fromOpaque(refcon).takeUnretainedValue()
    DispatchQueue.main.async { [weak manager] in
        manager?.handleObservedFocusChange()
    }
}

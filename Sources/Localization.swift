import Combine
import Foundation
import ShiftTypeCore

enum LocalizationKey {
    case ready
    case appRules
    case noAppsLocked
    case appLockedFormat
    case launchAtLogin
    case launchAtLoginDetail
    case language
    case followSystem
    case accessibilityRequired
    case accessibilityRequiredDetail
    case setUpShiftType
    case keyboardMonitoringUnavailable
    case keyboardMonitoringUnavailableDetail
    case retryShiftType
    case aboutShiftType
    case quit
    case quitHelp
    case inputMethodUnavailable
    case needsAttention
    case tapShiftToSwitch
    case cycleInputMethodsDetail
    case inputMethodPaused
    case finishSetupTooltip
    case needsPermissionTooltip
    case monitoringTooltip
    case appRulesWindowTitle
    case appRulesHeadline
    case appRulesDetail
    case noAppRules
    case noAppRulesDetail
    case unavailableInputMethod
    case inputMethodForAppFormat
    case removeRule
    case addApp
    case addAppHelp
    case remove
    case removeHelp
    case addAppRuleTitle
    case addAppRuleMessage
    case addButton
    case setUpWindowTitle
    case back
    case done
    case startUsing
    case continueButton
    case welcomeTitle
    case welcomeDetail
    case allowAccessibility
    case allowAccessibilityDetail
    case keyboardMonitoringFailed
    case allowed
    case allowAccessibilityButton
    case openSystemSettings
    case tryShiftType
    case tryShiftTypeDetail
    case currentInputMethod
    case needsTwoInputMethods
    case openKeyboardSettings
    case waitingForShiftTap
    case switchedToFormat
    case inputMethodSwitched
    case loginItemNotFound
    case loginItemUnknownStatus
    case launchAtLoginErrorTitle
    case ok
    case aboutCredits
}

final class LocalizationManager: ObservableObject {
    @Published private(set) var preference: ShiftTypeLanguagePreference
    @Published private(set) var language: ShiftTypeLanguage

    private static let preferenceKey = "appLanguage"
    private let defaults: UserDefaults

    init(
        defaults: UserDefaults = .standard,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) {
        self.defaults = defaults

        let storedPreference = defaults.string(forKey: Self.preferenceKey)
            .flatMap(ShiftTypeLanguagePreference.init(rawValue:))
        let preference = storedPreference ?? .system
        self.preference = preference
        language = ShiftTypeLanguageResolver.resolve(
            preference: preference,
            preferredLanguages: preferredLanguages
        )
    }

    func select(_ preference: ShiftTypeLanguagePreference) {
        guard preference != self.preference else { return }

        if preference == .system {
            defaults.removeObject(forKey: Self.preferenceKey)
        } else {
            defaults.set(preference.rawValue, forKey: Self.preferenceKey)
        }

        self.preference = preference
        language = ShiftTypeLanguageResolver.resolve(
            preference: preference,
            preferredLanguages: Locale.preferredLanguages
        )
    }

    func refreshSystemLanguage() {
        guard preference == .system else { return }
        let resolved = ShiftTypeLanguageResolver.resolve(
            preference: .system,
            preferredLanguages: Locale.preferredLanguages
        )
        guard resolved != language else { return }
        language = resolved
    }

    func string(_ key: LocalizationKey) -> String {
        switch language {
        case .english:
            return key.english
        case .simplifiedChinese:
            return key.simplifiedChinese
        }
    }

    func displayName(for option: ShiftTypeLanguagePreference) -> String {
        switch option {
        case .system:
            return string(.followSystem)
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        }
    }

    func appCount(_ count: Int) -> String {
        switch language {
        case .english:
            return "\(count) \(count == 1 ? "app" : "apps")"
        case .simplifiedChinese:
            return "\(count) 个应用"
        }
    }

    func lockedAppCount(_ count: Int) -> String {
        if count == 0 {
            return string(.noAppsLocked)
        }
        if count == 1, language == .english {
            return "1 app locked"
        }
        return String(format: string(.appLockedFormat), count)
    }

    func inputMethodLabel(for appName: String) -> String {
        String(format: string(.inputMethodForAppFormat), appName)
    }

    func switchedTo(_ sourceName: String) -> String {
        String(format: string(.switchedToFormat), sourceName)
    }

}

private extension LocalizationKey {
    var english: String {
        switch self {
        case .ready:
            return "Ready"
        case .appRules:
            return "App Rules"
        case .noAppsLocked:
            return "No apps locked"
        case .appLockedFormat:
            return "%d apps locked"
        case .launchAtLogin:
            return "Launch at Login"
        case .launchAtLoginDetail:
            return "Keep ShiftType ready after you sign in."
        case .language:
            return "Language"
        case .followSystem:
            return "Follow System"
        case .accessibilityRequired:
            return "Accessibility is required"
        case .accessibilityRequiredDetail:
            return "Allow ShiftType to recognize a standalone Shift tap and apply app rules."
        case .setUpShiftType:
            return "Set Up ShiftType…"
        case .keyboardMonitoringUnavailable:
            return "Keyboard monitoring is unavailable"
        case .keyboardMonitoringUnavailableDetail:
            return "ShiftType could not start its event monitor. Retry to begin watching for Shift taps."
        case .retryShiftType:
            return "Retry ShiftType"
        case .aboutShiftType:
            return "About ShiftType"
        case .quit:
            return "Quit"
        case .quitHelp:
            return "Quit ShiftType"
        case .inputMethodUnavailable:
            return "Input method unavailable"
        case .needsAttention:
            return "ShiftType needs attention"
        case .tapShiftToSwitch:
            return "Tap Shift to switch."
        case .cycleInputMethodsDetail:
            return "Cycle input methods with one Shift tap."
        case .inputMethodPaused:
            return "Input method switching is paused."
        case .finishSetupTooltip:
            return "Finish setting up ShiftType"
        case .needsPermissionTooltip:
            return "ShiftType needs permission"
        case .monitoringTooltip:
            return "ShiftType couldn’t start keyboard monitoring"
        case .appRulesWindowTitle:
            return "App Rules"
        case .appRulesHeadline:
            return "Lock an input method in specific apps."
        case .appRulesDetail:
            return "A rule switches to that input method when the app gains focus and blocks Shift cycling until you leave."
        case .noAppRules:
            return "No App Rules"
        case .noAppRulesDetail:
            return "Add an app to keep one input method locked while you use it."
        case .unavailableInputMethod:
            return "Unavailable Input Method"
        case .inputMethodForAppFormat:
            return "Input method for %@"
        case .removeRule:
            return "Remove Rule"
        case .addApp:
            return "Add App…"
        case .addAppHelp:
            return "Add an app rule"
        case .remove:
            return "Remove"
        case .removeHelp:
            return "Remove the selected app rules"
        case .addAppRuleTitle:
            return "Add App Rule"
        case .addAppRuleMessage:
            return "Choose one or more apps whose input method ShiftType should lock."
        case .addButton:
            return "Add"
        case .setUpWindowTitle:
            return "Set Up ShiftType"
        case .back:
            return "Back"
        case .done:
            return "Done"
        case .startUsing:
            return "Start Using ShiftType"
        case .continueButton:
            return "Continue"
        case .welcomeTitle:
            return "Switch input methods with Shift"
        case .welcomeDetail:
            return "Tap either Shift key by itself to cycle through every enabled input method. Shift still behaves normally while typing, selecting, clicking, or scrolling."
        case .allowAccessibility:
            return "Allow Accessibility"
        case .allowAccessibilityDetail:
            return "ShiftType uses Accessibility to detect a standalone Shift tap and apply app-specific input method rules."
        case .keyboardMonitoringFailed:
            return "ShiftType couldn’t start keyboard monitoring."
        case .allowed:
            return "Allowed"
        case .allowAccessibilityButton:
            return "Allow Accessibility"
        case .openSystemSettings:
            return "Open System Settings"
        case .tryShiftType:
            return "Try ShiftType"
        case .tryShiftTypeDetail:
            return "Tap either Shift key by itself. Your input method should change."
        case .currentInputMethod:
            return "Current input method"
        case .needsTwoInputMethods:
            return "ShiftType needs at least two enabled input methods."
        case .openKeyboardSettings:
            return "Open Keyboard Settings"
        case .waitingForShiftTap:
            return "Waiting for a Shift tap…"
        case .switchedToFormat:
            return "Switched to %@"
        case .inputMethodSwitched:
            return "Input method switched"
        case .loginItemNotFound:
            return "macOS could not find ShiftType as a login item. Install it in Applications, then try again."
        case .loginItemUnknownStatus:
            return "macOS returned an unknown Launch at Login status."
        case .launchAtLoginErrorTitle:
            return "Couldn’t Change Launch at Login"
        case .ok:
            return "OK"
        case .aboutCredits:
            return "Tap Shift to cycle input methods. Lock one wherever it belongs."
        }
    }

    var simplifiedChinese: String {
        switch self {
        case .ready:
            return "就绪"
        case .appRules:
            return "应用规则"
        case .noAppsLocked:
            return "尚未锁定应用"
        case .appLockedFormat:
            return "已锁定 %d 个应用"
        case .launchAtLogin:
            return "登录时启动"
        case .launchAtLoginDetail:
            return "登录后让 ShiftType 自动准备好。"
        case .language:
            return "语言"
        case .followSystem:
            return "跟随系统"
        case .accessibilityRequired:
            return "需要辅助功能权限"
        case .accessibilityRequiredDetail:
            return "允许 ShiftType 识别单独的 Shift 轻按，并应用应用规则。"
        case .setUpShiftType:
            return "设置 ShiftType…"
        case .keyboardMonitoringUnavailable:
            return "无法监控键盘"
        case .keyboardMonitoringUnavailableDetail:
            return "ShiftType 无法启动事件监控。请重试以继续检测 Shift 轻按。"
        case .retryShiftType:
            return "重试 ShiftType"
        case .aboutShiftType:
            return "关于 ShiftType"
        case .quit:
            return "退出"
        case .quitHelp:
            return "退出 ShiftType"
        case .inputMethodUnavailable:
            return "输入法不可用"
        case .needsAttention:
            return "ShiftType 需要处理"
        case .tapShiftToSwitch:
            return "轻按 Shift 切换。"
        case .cycleInputMethodsDetail:
            return "轻按一次 Shift 即可循环切换输入法。"
        case .inputMethodPaused:
            return "输入法切换已暂停。"
        case .finishSetupTooltip:
            return "完成 ShiftType 设置"
        case .needsPermissionTooltip:
            return "ShiftType 需要权限"
        case .monitoringTooltip:
            return "ShiftType 无法启动键盘监控"
        case .appRulesWindowTitle:
            return "应用规则"
        case .appRulesHeadline:
            return "在指定应用中锁定输入法。"
        case .appRulesDetail:
            return "应用获得焦点时会切换到规则指定的输入法，并在离开前阻止 Shift 切换。"
        case .noAppRules:
            return "没有应用规则"
        case .noAppRulesDetail:
            return "添加应用后，可在使用该应用时锁定一个输入法。"
        case .unavailableInputMethod:
            return "输入法不可用"
        case .inputMethodForAppFormat:
            return "%@ 的输入法"
        case .removeRule:
            return "移除规则"
        case .addApp:
            return "添加应用…"
        case .addAppHelp:
            return "添加应用规则"
        case .remove:
            return "移除"
        case .removeHelp:
            return "移除选中的应用规则"
        case .addAppRuleTitle:
            return "添加应用规则"
        case .addAppRuleMessage:
            return "选择一个或多个需要锁定输入法的应用。"
        case .addButton:
            return "添加"
        case .setUpWindowTitle:
            return "设置 ShiftType"
        case .back:
            return "返回"
        case .done:
            return "完成"
        case .startUsing:
            return "开始使用 ShiftType"
        case .continueButton:
            return "继续"
        case .welcomeTitle:
            return "轻按 Shift 切换输入法"
        case .welcomeDetail:
            return "单独轻按任意一个 Shift 键，即可循环切换所有已启用的输入法。输入、选择、点击或滚动时，Shift 仍保持正常行为。"
        case .allowAccessibility:
            return "允许辅助功能"
        case .allowAccessibilityDetail:
            return "ShiftType 使用辅助功能识别单独的 Shift 轻按，并应用各个应用的输入法规则。"
        case .keyboardMonitoringFailed:
            return "ShiftType 无法启动键盘监控。"
        case .allowed:
            return "已允许"
        case .allowAccessibilityButton:
            return "允许辅助功能"
        case .openSystemSettings:
            return "打开系统设置"
        case .tryShiftType:
            return "试用 ShiftType"
        case .tryShiftTypeDetail:
            return "单独轻按任意一个 Shift 键，输入法应该会切换。"
        case .currentInputMethod:
            return "当前输入法"
        case .needsTwoInputMethods:
            return "ShiftType 至少需要启用两个输入法。"
        case .openKeyboardSettings:
            return "打开键盘设置"
        case .waitingForShiftTap:
            return "等待轻按 Shift…"
        case .switchedToFormat:
            return "已切换到 %@"
        case .inputMethodSwitched:
            return "输入法已切换"
        case .loginItemNotFound:
            return "macOS 找不到作为登录项安装的 ShiftType。请先安装到“应用程序”文件夹后重试。"
        case .loginItemUnknownStatus:
            return "macOS 返回了未知的登录项状态。"
        case .launchAtLoginErrorTitle:
            return "无法更改登录时启动"
        case .ok:
            return "好"
        case .aboutCredits:
            return "轻按 Shift 循环切换输入法，让每个应用记住自己的选择。"
        }
    }
}

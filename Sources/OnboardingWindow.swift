import AppKit
import ShiftTypeCore
import SwiftUI

enum ShiftTypeOnboardingStep: Int, CaseIterable {
    case welcome
    case accessibility
    case practice
}

struct ShiftTypeOnboardingState: Equatable {
    let step: ShiftTypeOnboardingStep
    let isRecovery: Bool
    let accessibilityAllowed: Bool
    let serviceStartFailed: Bool
    let availableSourceCount: Int
    let currentSourceName: String?
    let practiceSucceeded: Bool
    let practiceSourceName: String?
}

final class ShiftTypeOnboardingModel: ObservableObject {
    @Published private(set) var state: ShiftTypeOnboardingState

    init(state: ShiftTypeOnboardingState) {
        self.state = state
    }

    func update(state: ShiftTypeOnboardingState) {
        guard state != self.state else { return }
        self.state = state
    }
}

final class OnboardingWindowController: NSWindowController {
    private let hostingController: NSHostingController<ShiftTypeOnboardingView>

    init(view: ShiftTypeOnboardingView, title: String) {
        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hostingController)
        window.title = title
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 600, height: 500))
        window.center()

        self.hostingController = hostingController
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    func setTitle(_ title: String) {
        window?.title = title
    }
}

struct ShiftTypeOnboardingView: View {
    @ObservedObject var model: ShiftTypeOnboardingModel
    @ObservedObject var localization: LocalizationManager

    let onBack: () -> Void
    let onContinue: () -> Void
    let onRetryServices: () -> Void
    let onRequestAccessibility: () -> Void
    let onOpenAccessibilitySettings: () -> Void
    let onOpenKeyboardSettings: () -> Void
    let onLanguageChange: (ShiftTypeLanguagePreference) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ForEach(ShiftTypeOnboardingStep.allCases, id: \.rawValue) { item in
                    Capsule()
                        .fill(item.rawValue <= model.state.step.rawValue
                              ? Color.accentColor
                              : Color.secondary.opacity(0.2))
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 24)

            Group {
                switch model.state.step {
                case .welcome:
                    WelcomeStep(localization: localization)
                case .accessibility:
                    AccessibilityStep(
                        localization: localization,
                        isAllowed: model.state.accessibilityAllowed,
                        serviceStartFailed: model.state.serviceStartFailed,
                        onAllow: onRequestAccessibility,
                        onOpenSettings: onOpenAccessibilitySettings,
                        onRetry: onRetryServices
                    )
                case .practice:
                    PracticeStep(
                        localization: localization,
                        availableSourceCount: model.state.availableSourceCount,
                        currentSourceName: model.state.currentSourceName,
                        succeeded: model.state.practiceSucceeded,
                        switchedSourceName: model.state.practiceSourceName,
                        onOpenKeyboardSettings: onOpenKeyboardSettings
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(36)

            Divider()

            HStack {
                if model.state.step != .welcome
                    && !(model.state.isRecovery && model.state.step == .accessibility) {
                    Button(localization.string(.back), action: onBack)
                }

                Picker(
                    localization.string(.language),
                    selection: Binding(
                        get: { localization.preference },
                        set: { onLanguageChange($0) }
                    )
                ) {
                    ForEach(ShiftTypeLanguagePreference.allCases) { option in
                        Text(localization.displayName(for: option))
                            .tag(option)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
                .help(localization.string(.language))

                Spacer()

                Button(primaryButtonTitle, action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canContinue)
            }
            .padding(20)
        }
        .frame(width: 600, height: 500)
    }

    private var canContinue: Bool {
        switch model.state.step {
        case .welcome:
            true
        case .accessibility:
            model.state.accessibilityAllowed && !model.state.serviceStartFailed
        case .practice:
            model.state.practiceSucceeded
        }
    }

    private var primaryButtonTitle: String {
        if model.state.isRecovery && model.state.step == .accessibility {
            return localization.string(.done)
        }
        if model.state.step == .practice {
            return localization.string(.startUsing)
        }
        return localization.string(.continueButton)
    }
}

private struct WelcomeStep: View {
    @ObservedObject var localization: LocalizationManager

    var body: some View {
        OnboardingPage(
            icon: "shift.fill",
            title: localization.string(.welcomeTitle),
            detail: localization.string(.welcomeDetail)
        )
    }
}

private struct AccessibilityStep: View {
    @ObservedObject var localization: LocalizationManager

    let isAllowed: Bool
    let serviceStartFailed: Bool
    let onAllow: () -> Void
    let onOpenSettings: () -> Void
    let onRetry: () -> Void

    var body: some View {
        OnboardingPage(
            icon: "accessibility",
            title: localization.string(.allowAccessibility),
            detail: localization.string(.allowAccessibilityDetail)
        ) {
            if serviceStartFailed {
                Text(localization.string(.keyboardMonitoringFailed))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button(localization.string(.retryShiftType), action: onRetry)
                    .buttonStyle(.borderedProminent)
            } else if isAllowed {
                Label(localization.string(.allowed), systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.headline)
            } else {
                Button(localization.string(.allowAccessibilityButton), action: onAllow)
                    .buttonStyle(.borderedProminent)
                Button(localization.string(.openSystemSettings), action: onOpenSettings)
                    .buttonStyle(.link)
            }
        }
    }
}

private struct PracticeStep: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ObservedObject var localization: LocalizationManager

    let availableSourceCount: Int
    let currentSourceName: String?
    let succeeded: Bool
    let switchedSourceName: String?
    let onOpenKeyboardSettings: () -> Void

    var body: some View {
        OnboardingPage(
            icon: "shift.fill",
            title: localization.string(.tryShiftType),
            detail: localization.string(.tryShiftTypeDetail)
        ) {
            Label(displayedSourceName, systemImage: "keyboard")
                .font(.headline)
                .contentTransition(.opacity)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.06))
                .clipShape(Capsule())

            if availableSourceCount < 2 {
                Text(localization.string(.needsTwoInputMethods))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button(localization.string(.openKeyboardSettings), action: onOpenKeyboardSettings)
                    .buttonStyle(.link)
            } else {
                if succeeded {
                    Label(successMessage, systemImage: "checkmark.circle.fill")
                        .font(.callout)
                        .foregroundStyle(.green)
                        .transition(successTransition)
                } else {
                    Text(localization.string(.waitingForShiftTap))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .transition(successTransition)
                }
            }
        }
        .animation(successAnimation, value: succeeded)
        .animation(successAnimation, value: displayedSourceName)
    }

    private var displayedSourceName: String {
        switchedSourceName ?? currentSourceName ?? localization.string(.currentInputMethod)
    }

    private var successMessage: String {
        switchedSourceName.map(localization.switchedTo)
            ?? localization.string(.inputMethodSwitched)
    }

    private var successAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.3, dampingFraction: 1)
    }

    private var successTransition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96))
    }
}

private struct OnboardingPage<Actions: View>: View {
    let icon: String
    let title: String
    let detail: String
    @ViewBuilder let actions: Actions

    init(
        icon: String,
        title: String,
        detail: String,
        @ViewBuilder actions: () -> Actions
    ) {
        self.icon = icon
        self.title = title
        self.detail = detail
        self.actions = actions()
    }

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: icon)
                .font(.system(size: 52))
                .foregroundStyle(Color.accentColor)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)

            Text(title)
                .font(.largeTitle.bold())

            Text(detail)
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 450)

            actions
        }
    }
}

private extension OnboardingPage where Actions == EmptyView {
    init(icon: String, title: String, detail: String) {
        self.init(icon: icon, title: title, detail: detail) { EmptyView() }
    }
}

import Combine
import ShiftTypeCore
import SwiftUI

enum ShiftTypePopoverMode: Equatable {
    case ready
    case setup
    case serviceUnavailable
}

struct ShiftTypePopoverState: Equatable {
    let mode: ShiftTypePopoverMode
    let currentSourceName: String?
    let appRuleCount: Int
    let launchAtLoginEnabled: Bool
}

final class ShiftTypePopoverModel: ObservableObject {
    @Published private(set) var state: ShiftTypePopoverState

    init(state: ShiftTypePopoverState) {
        self.state = state
    }

    func update(state: ShiftTypePopoverState) {
        guard state != self.state else { return }
        self.state = state
    }
}

struct ShiftTypePopoverView: View {
    @ObservedObject var model: ShiftTypePopoverModel
    @ObservedObject var localization: LocalizationManager

    let onSetup: () -> Void
    let onRetry: () -> Void
    let onAppRules: () -> Void
    let onToggleLaunchAtLogin: () -> Void
    let onLanguageChange: (ShiftTypeLanguagePreference) -> Void
    let onAbout: () -> Void
    let onQuit: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPresented = false

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()
                .opacity(0.55)
                .padding(.vertical, 14)

            switch model.state.mode {
            case .ready:
                readyContent
            case .setup:
                setupContent
            case .serviceUnavailable:
                serviceUnavailableContent
            }

            if model.state.mode != .ready {
                languageCard
                    .padding(.top, 10)
            }

            Divider()
                .opacity(0.55)
                .padding(.vertical, 12)

            footer
        }
        .padding(16)
        .frame(width: 332)
        .background(panelBackground)
        .opacity(isPresented ? 1 : 0)
        .scaleEffect(
            isPresented || reduceMotion ? 1 : 0.97,
            anchor: .top
        )
        .offset(y: isPresented || reduceMotion ? 0 : -4)
        .onAppear {
            withAnimation(entranceAnimation) {
                isPresented = true
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.accentColor.opacity(colorScheme == .dark ? 0.46 : 0.30),
                                Color.accentColor.opacity(colorScheme == .dark ? 0.18 : 0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.22), lineWidth: 0.5)

                Image(systemName: headerSymbol)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .symbolRenderingMode(.hierarchical)
            }
            .frame(width: 42, height: 42)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(headerTitle)
                    .font(.headline)
                    .lineLimit(1)

                Text(headerDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if model.state.mode == .ready {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text(localization.string(.ready))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.055), in: Capsule())
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var readyContent: some View {
        VStack(spacing: 0) {
            Button(action: onAppRules) {
                PopoverRow(
                    symbol: "app.badge.checkmark",
                    title: localization.string(.appRules),
                    detail: appRulesDetail,
                    trailingSymbol: "chevron.right"
                )
            }
            .buttonStyle(PopoverRowButtonStyle())

            rowDivider

            languageRow

            rowDivider

            launchAtLoginRow
        }
        .padding(.vertical, 4)
        .background(cardFill, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(cardBorder, lineWidth: 0.5)
        }
    }

    private var launchAtLoginRow: some View {
        HStack(spacing: 10) {
            PopoverLabel(
                symbol: "power",
                title: localization.string(.launchAtLogin),
                detail: localization.string(.launchAtLoginDetail)
            )

            Spacer(minLength: 8)

            Toggle(
                localization.string(.launchAtLogin),
                isOn: Binding(
                    get: { model.state.launchAtLoginEnabled },
                    set: { _ in onToggleLaunchAtLogin() }
                )
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .popoverRowLayout()
    }

    private var rowDivider: some View {
        Divider()
            .padding(.leading, 40)
            .padding(.trailing, 10)
    }

    private var setupContent: some View {
        VStack(spacing: 12) {
            NoticeCard(
                symbol: "hand.raised.fill",
                title: localization.string(.accessibilityRequired),
                detail: localization.string(.accessibilityRequiredDetail)
            )

            Button(action: onSetup) {
                Text(localization.string(.setUpShiftType))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private var serviceUnavailableContent: some View {
        VStack(spacing: 12) {
            NoticeCard(
                symbol: "exclamationmark.triangle.fill",
                title: localization.string(.keyboardMonitoringUnavailable),
                detail: localization.string(.keyboardMonitoringUnavailableDetail)
            )

            Button(action: onRetry) {
                Text(localization.string(.retryShiftType))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Button(localization.string(.aboutShiftType), action: onAbout)
                .buttonStyle(PopoverFooterButtonStyle())

            Spacer(minLength: 4)

            Button(localization.string(.quit), action: onQuit)
                .buttonStyle(PopoverFooterButtonStyle())
                .keyboardShortcut("q", modifiers: .command)
                .help(localization.string(.quitHelp))
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var languageCard: some View {
        languageRow
            .background(cardFill, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(cardBorder, lineWidth: 0.5)
            }
    }

    private var languageRow: some View {
        HStack(spacing: 10) {
            PopoverLabel(
                symbol: "globe",
                title: localization.string(.language),
                detail: effectiveLanguageName
            )

            Spacer(minLength: 8)

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
            .controlSize(.small)
            .fixedSize()
        }
        .popoverRowLayout()
    }

    private var headerSymbol: String {
        switch model.state.mode {
        case .ready:
            return "shift.fill"
        case .setup:
            return "hand.raised.fill"
        case .serviceUnavailable:
            return "exclamationmark.triangle.fill"
        }
    }

    private var headerTitle: String {
        switch model.state.mode {
        case .ready:
            return model.state.currentSourceName ?? localization.string(.inputMethodUnavailable)
        case .setup:
            return "ShiftType"
        case .serviceUnavailable:
            return localization.string(.needsAttention)
        }
    }

    private var headerDetail: String {
        switch model.state.mode {
        case .ready:
            return localization.string(.tapShiftToSwitch)
        case .setup:
            return localization.string(.cycleInputMethodsDetail)
        case .serviceUnavailable:
            return localization.string(.inputMethodPaused)
        }
    }

    private var appRulesDetail: String {
        localization.lockedAppCount(model.state.appRuleCount)
    }

    private var effectiveLanguageName: String {
        switch localization.language {
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        }
    }

    private var panelBackground: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: Color.accentColor.opacity(colorScheme == .dark ? 0.30 : 0.34), location: 0.0),
                    .init(color: Color.accentColor.opacity(colorScheme == .dark ? 0.12 : 0.13), location: 0.38),
                    .init(color: Color.accentColor.opacity(colorScheme == .dark ? 0.03 : 0.03), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    Color.white.opacity(colorScheme == .dark ? 0.05 : 0.20),
                    Color.clear
                ],
                center: .init(x: 0.08, y: -0.12),
                startRadius: 0,
                endRadius: 120
            )
        }
    }

    private var cardFill: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.06)
            : Color.white.opacity(0.58)
    }

    private var cardBorder: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.06)
    }

    private var entranceAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.15)
            : .spring(response: 0.3, dampingFraction: 1)
    }
}

private struct NoticeCard: View {
    let symbol: String
    let title: String
    let detail: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            colorScheme == .dark
                ? Color.white.opacity(0.06)
                : Color.black.opacity(0.045),
            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(
                    colorScheme == .dark
                        ? Color.white.opacity(0.08)
                        : Color.black.opacity(0.06),
                    lineWidth: 0.5
                )
        }
    }
}

private struct PopoverRow: View {
    let symbol: String
    let title: String
    let detail: String
    let trailingSymbol: String

    var body: some View {
        HStack(spacing: 10) {
            PopoverLabel(symbol: symbol, title: title, detail: detail)

            Spacer(minLength: 8)

            Image(systemName: trailingSymbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .popoverRowLayout()
        .contentShape(Rectangle())
    }
}

private extension View {
    func popoverRowLayout() -> some View {
        self
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PopoverLabel: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 20)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

private struct PopoverRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed
                    ? Color.primary.opacity(0.065)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

private struct PopoverFooterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.55 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

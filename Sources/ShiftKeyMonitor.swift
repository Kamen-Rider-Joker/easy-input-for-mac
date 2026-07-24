import CoreGraphics
import ShiftTypeCore

final class ShiftKeyMonitor {
    var onShiftTap: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var recognizer = ShiftTapRecognizer()
    private var pressedMouseButtons: Set<Int64> = []

    deinit { stop() }

    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }

        let eventTypes: [CGEventType] = [
            .flagsChanged,
            .keyDown,
            .leftMouseDown,
            .leftMouseUp,
            .rightMouseDown,
            .rightMouseUp,
            .otherMouseDown,
            .otherMouseUp,
            .scrollWheel,
        ]
        let eventMask = eventTypes.reduce(CGEventMask(0)) { mask, type in
            mask | (CGEventMask(1) << type.rawValue)
        }
        let context = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: shiftTypeEventCallback,
            userInfo: context
        ) else {
            return false
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            return false
        }

        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        recognizer.reset()
        pressedMouseButtons.removeAll()

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }

        runLoopSource = nil
        eventTap = nil
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            recognizer.reset()
            pressedMouseButtons.removeAll()
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }

        case .flagsChanged:
            let flags = event.flags
            let otherModifiers: CGEventFlags = [
                .maskCommand,
                .maskControl,
                .maskAlternate,
                .maskSecondaryFn,
            ]
            let shouldCycle = recognizer.handleFlagsChanged(
                shiftIsDown: flags.contains(.maskShift),
                hasOtherModifiers: !flags.intersection(otherModifiers).isEmpty
                    || !pressedMouseButtons.isEmpty
            )
            if shouldCycle {
                DispatchQueue.main.async { [weak self] in
                    self?.onShiftTap?()
                }
            }

        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            pressedMouseButtons.insert(event.getIntegerValueField(.mouseEventButtonNumber))
            recognizer.cancel()

        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            pressedMouseButtons.remove(event.getIntegerValueField(.mouseEventButtonNumber))

        case .keyDown, .scrollWheel:
            recognizer.cancel()

        default:
            break
        }
    }
}

private func shiftTypeEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let monitor = Unmanaged<ShiftKeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()
    monitor.handle(type: type, event: event)
    return Unmanaged.passUnretained(event)
}

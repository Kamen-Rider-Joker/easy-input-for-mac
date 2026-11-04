import AppKit
import ApplicationServices

enum TextCompositionMonitor {
    private static let systemWideElement: AXUIElement = {
        let element = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(element, 0.1)
        return element
    }()

    static func hasActiveComposition() -> Bool {
        var rawFocusedElement: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &rawFocusedElement
        ) == .success,
        let rawFocusedElement,
        CFGetTypeID(rawFocusedElement) == AXUIElementGetTypeID() else {
            return false
        }

        let focusedElement = rawFocusedElement as! AXUIElement
        var rawRange: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            focusedElement,
            NSAccessibility.Attribute.textInputMarkedRangeAttribute.rawValue as CFString,
            &rawRange
        ) == .success,
        let rawRange else {
            return false
        }

        if let value = rawRange as? NSValue {
            let range = value.rangeValue
            return range.location != NSNotFound && range.length > 0
        }

        guard CFGetTypeID(rawRange) == AXValueGetTypeID() else {
            return false
        }

        var range = CFRange()
        guard AXValueGetValue(rawRange as! AXValue, .cfRange, &range) else {
            return false
        }
        return range.location != kCFNotFound && range.length > 0
    }
}

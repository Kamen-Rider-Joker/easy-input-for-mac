public struct ShiftTapRecognizer {
    public private(set) var isShiftDown = false
    private var isTapCandidate = false

    public init() { }

    public var canCompleteAsStandaloneTap: Bool {
        isShiftDown && isTapCandidate
    }

    public mutating func handleFlagsChanged(
        shiftIsDown: Bool,
        hasOtherModifiers: Bool,
        hasActiveTextComposition: Bool = false
    ) -> Bool {
        if shiftIsDown {
            if isShiftDown {
                // A second modifier event while Shift remains down means this is
                // part of a chord, not a standalone tap.
                isTapCandidate = false
            } else {
                isShiftDown = true
                isTapCandidate = !hasOtherModifiers && !hasActiveTextComposition
            }
            return false
        }

        guard isShiftDown else { return false }

        // Switching input sources while an input method has marked text can leave
        // its candidate window orphaned. Let the current composition finish first.
        let shouldCycle = isTapCandidate && !hasActiveTextComposition
        reset()
        return shouldCycle
    }

    public mutating func cancel() {
        if isShiftDown {
            isTapCandidate = false
        }
    }

    public mutating func reset() {
        isShiftDown = false
        isTapCandidate = false
    }
}

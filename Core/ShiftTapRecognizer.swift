public struct ShiftTapRecognizer {
    public private(set) var isShiftDown = false
    private var isTapCandidate = false

    public init() { }

    public mutating func handleFlagsChanged(
        shiftIsDown: Bool,
        hasOtherModifiers: Bool
    ) -> Bool {
        if shiftIsDown {
            if isShiftDown {
                // A second modifier event while Shift remains down means this is
                // part of a chord, not a standalone tap.
                isTapCandidate = false
            } else {
                isShiftDown = true
                isTapCandidate = !hasOtherModifiers
            }
            return false
        }

        guard isShiftDown else { return false }

        let shouldCycle = isTapCandidate
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

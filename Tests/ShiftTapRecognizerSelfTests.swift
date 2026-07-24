import ShiftTypeCore

@main
struct ShiftTapRecognizerSelfTests {
    static func main() {
        var failures: [String] = []

        func check(_ condition: @autoclosure () -> Bool, _ name: String) {
            if !condition() {
                failures.append(name)
            }
        }

        var standalone = ShiftTapRecognizer()
        check(
            !standalone.handleFlagsChanged(shiftIsDown: true, hasOtherModifiers: false),
            "standalone press waits for release"
        )
        check(
            standalone.handleFlagsChanged(shiftIsDown: false, hasOtherModifiers: false),
            "standalone release cycles"
        )

        var typing = ShiftTapRecognizer()
        _ = typing.handleFlagsChanged(shiftIsDown: true, hasOtherModifiers: false)
        typing.cancel()
        check(
            !typing.handleFlagsChanged(shiftIsDown: false, hasOtherModifiers: false),
            "typing with Shift does not cycle"
        )

        var chord = ShiftTapRecognizer()
        check(
            !chord.handleFlagsChanged(shiftIsDown: true, hasOtherModifiers: true),
            "modifier chord press does not cycle"
        )
        check(
            !chord.handleFlagsChanged(shiftIsDown: false, hasOtherModifiers: false),
            "modifier chord release does not cycle"
        )

        var secondModifier = ShiftTapRecognizer()
        _ = secondModifier.handleFlagsChanged(shiftIsDown: true, hasOtherModifiers: false)
        _ = secondModifier.handleFlagsChanged(shiftIsDown: true, hasOtherModifiers: false)
        check(
            !secondModifier.handleFlagsChanged(shiftIsDown: false, hasOtherModifiers: false),
            "second modifier event cancels tap"
        )

        var unmatchedRelease = ShiftTapRecognizer()
        check(
            !unmatchedRelease.handleFlagsChanged(shiftIsDown: false, hasOtherModifiers: false),
            "unmatched release does nothing"
        )

        guard failures.isEmpty else {
            fatalError("Shift tap self-tests failed: \(failures.joined(separator: ", "))")
        }

        print("Shift tap self-tests passed (7 checks)")
    }
}

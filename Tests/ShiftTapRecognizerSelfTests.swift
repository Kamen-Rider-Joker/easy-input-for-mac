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

        var composingAtPress = ShiftTapRecognizer()
        _ = composingAtPress.handleFlagsChanged(
            shiftIsDown: true,
            hasOtherModifiers: false,
            hasActiveTextComposition: true
        )
        check(
            !composingAtPress.handleFlagsChanged(
                shiftIsDown: false,
                hasOtherModifiers: false,
                hasActiveTextComposition: true
            ),
            "composition at press does not cycle"
        )

        var composingAtRelease = ShiftTapRecognizer()
        _ = composingAtRelease.handleFlagsChanged(
            shiftIsDown: true,
            hasOtherModifiers: false,
            hasActiveTextComposition: false
        )
        check(
            !composingAtRelease.handleFlagsChanged(
                shiftIsDown: false,
                hasOtherModifiers: false,
                hasActiveTextComposition: true
            ),
            "composition at release does not cycle"
        )

        check(
            ShiftTypeLanguageResolver.resolve(
                preference: .system,
                preferredLanguages: ["zh-Hans-CN", "en-US"]
            ) == .simplifiedChinese,
            "system preference follows Chinese"
        )
        check(
            ShiftTypeLanguageResolver.resolve(
                preference: .system,
                preferredLanguages: ["en-US", "zh-Hans-CN"]
            ) == .english,
            "system preference follows English"
        )
        check(
            ShiftTypeLanguageResolver.resolve(
                preference: .english,
                preferredLanguages: ["zh-Hans-CN"]
            ) == .english,
            "explicit English overrides system"
        )
        check(
            ShiftTypeLanguageResolver.resolve(
                preference: .simplifiedChinese,
                preferredLanguages: ["en-US"]
            ) == .simplifiedChinese,
            "explicit Chinese overrides system"
        )

        guard failures.isEmpty else {
            fatalError("Shift tap self-tests failed: \(failures.joined(separator: ", "))")
        }

        print("ShiftType self-tests passed (13 checks)")
    }
}

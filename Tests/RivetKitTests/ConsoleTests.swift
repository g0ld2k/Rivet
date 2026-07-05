import Testing
@testable import RivetKit

@Suite struct ConsoleTests {
    @Test func colorRequiresTTY() {
        #expect(Console(isTTY: false, environment: [:]).isColored == false)
        #expect(Console(isTTY: true, environment: [:]).isColored == true)
    }

    @Test func noColorEnvironmentDisablesColor() {
        #expect(Console(isTTY: true, environment: ["NO_COLOR": "1"]).isColored == false)
        // Per no-color.org, an empty value does not activate NO_COLOR.
        #expect(Console(isTTY: true, environment: ["NO_COLOR": ""]).isColored == true)
    }

    @Test func dumbTerminalDisablesColor() {
        #expect(Console(isTTY: true, environment: ["TERM": "dumb"]).isColored == false)
    }

    @Test func paintWrapsWithANSICodesOnlyWhenColored() {
        let colored = Console(isTTY: true, environment: [:])
        let plain = Console(isTTY: false, environment: [:])
        #expect(colored.paint("ok", .green) == "\u{1B}[32mok\u{1B}[0m")
        #expect(plain.paint("ok", .green) == "ok")
    }
}

import Foundation

public enum ANSIColor: String, Sendable {
    case red = "31"
    case green = "32"
    case yellow = "33"
    case dim = "2"
}

public struct Console: Sendable {
    public let isColored: Bool

    public init(
        isTTY: Bool = isatty(fileno(stderr)) != 0,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        let noColor = environment["NO_COLOR"].map { !$0.isEmpty } ?? false
        isColored = isTTY && !noColor && environment["TERM"] != "dumb"
    }

    public func paint(_ text: String, _ color: ANSIColor) -> String {
        isColored ? "\u{1B}[\(color.rawValue)m\(text)\u{1B}[0m" : text
    }

    public func error(_ message: String) {
        writeLine(paint("rivet: ", .red) + message)
    }

    public func note(_ message: String) {
        writeLine(message)
    }

    public func status(_ message: String) {
        writeLine(paint(message, .dim))
    }

    public func writeLine(_ line: String) {
        FileHandle.standardError.write(Data((line + "\n").utf8))
    }
}

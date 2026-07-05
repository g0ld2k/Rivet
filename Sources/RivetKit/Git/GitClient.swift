import Foundation
import Synchronization

public struct GitResult: Equatable, Sendable {
    public let status: Int32
    public let stdout: String
    public let stderr: String

    public init(status: Int32, stdout: String, stderr: String) {
        self.status = status
        self.stdout = stdout
        self.stderr = stderr
    }
}

private final class PipeReadBuffer: Sendable {
    private let data = Mutex(Data())

    func replace(with newData: Data) {
        data.withLock { storedData in
            storedData = newData
        }
    }

    func value() -> Data {
        data.withLock { storedData in
            storedData
        }
    }
}

public struct GitClient: Sendable {
    public let workingDirectory: URL

    public init(workingDirectory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)) {
        self.workingDirectory = workingDirectory
    }

    @discardableResult
    public func run(_ arguments: [String]) throws -> GitResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-c", "core.quotePath=false"] + arguments
        process.currentDirectoryURL = workingDirectory
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        try process.run()
        let outputGroup = DispatchGroup()
        let stdoutHandle = stdoutPipe.fileHandleForReading
        let stderrHandle = stderrPipe.fileHandleForReading
        let stdoutData = PipeReadBuffer()
        let stderrData = PipeReadBuffer()

        outputGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async { [stdoutHandle, stdoutData, outputGroup] in
            defer { outputGroup.leave() }
            stdoutData.replace(with: stdoutHandle.readDataToEndOfFile())
        }
        outputGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async { [stderrHandle, stderrData, outputGroup] in
            defer { outputGroup.leave() }
            stderrData.replace(with: stderrHandle.readDataToEndOfFile())
        }

        process.waitUntilExit()
        outputGroup.wait()
        return GitResult(
            status: process.terminationStatus,
            stdout: String(decoding: stdoutData.value(), as: UTF8.self),
            stderr: String(decoding: stderrData.value(), as: UTF8.self)
        )
    }
}

import Foundation
import FoundationModels
import Testing
@testable import RivetKit

@Suite struct DoctorTests {
    @Test func macOSVersionCheck() {
        let old = OperatingSystemVersion(majorVersion: 26, minorVersion: 4, patchVersion: 0)
        #expect(DoctorChecks.macOSVersion(old).passed == false)
        let new = OperatingSystemVersion(majorVersion: 27, minorVersion: 0, patchVersion: 0)
        #expect(DoctorChecks.macOSVersion(new).passed == true)
    }

    @Test func availabilityCheckUsesModelGateText() {
        let ok = DoctorChecks.modelAvailability(.available)
        #expect(ok.passed && ok.detail == "available")
        let off = DoctorChecks.modelAvailability(.unavailable(.appleIntelligenceNotEnabled))
        #expect(!off.passed)
        #expect(off.detail.contains("System Settings"))
    }

    @Test func humanLinesMarkPassAndFail() {
        let console = Console(isTTY: false, environment: [:])
        let lines = DoctorReport.humanLines([
            DoctorCheck(name: "A", passed: true, detail: "fine"),
            DoctorCheck(name: "B", passed: false, detail: "broken"),
        ], console: console)
        #expect(lines == ["✓ A: fine", "✗ B: broken"])
    }

    @Test func jsonReportRoundTrips() throws {
        let json = try DoctorReport.json([DoctorCheck(name: "A", passed: true, detail: "fine")])
        let decoded = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [[String: Any]]
        #expect(decoded?.first?["check"] as? String == "A")
        #expect(decoded?.first?["passed"] as? Bool == true)
    }

    @Test func tokenizerFailureDetailIsSingleLineAndCompact() {
        let error = NSError(
            domain: "DoctorTokenizer",
            code: 42,
            userInfo: [
                NSLocalizedDescriptionKey: "Primary failure\nSecondary detail with extra context",
                "debug": "UserInfo debug blob\nwith multiple lines\nand noisy implementation detail",
            ]
        )

        let check = DoctorChecks.tokenizer(.failure(error))

        #expect(check.passed == false)
        #expect(check.detail.starts(with: "failed: Primary failure"))
        #expect(!check.detail.contains("\n"))
        #expect(!check.detail.contains("UserInfo"))
        #expect(check.detail.count <= 120)
    }
}

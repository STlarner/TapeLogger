import Foundation
import Testing
@testable import TapeLogger

@Suite("TapeConsoleCapabilities")
struct TapeConsoleCapabilitiesTests {
    @Test("A pipe gets emoji badges")
    func pipeUsesEmoji() {
        let capabilities = TapeConsoleCapabilities.detect(
            environment: ["TERM": "xterm-256color"],
            isTerminal: false
        )

        #expect(capabilities.mode == .emoji)
    }

    @Test("A real terminal gets ANSI colors")
    func terminalUsesANSI() {
        let capabilities = TapeConsoleCapabilities.detect(
            environment: ["TERM": "xterm-256color"],
            isTerminal: true
        )

        #expect(capabilities.mode == .ansi)
    }

    @Test(
        "The Xcode console gets emoji badges",
        arguments: [
            "XCODE_VERSION_ACTUAL",
            "XCODE_PRODUCT_BUILD_VERSION",
            "XCODE_RUNNING_FOR_PREVIEWS",
            "__XCODE_BUILT_PRODUCTS_DIR_PATHS",
            "IDE_DISABLED_OS_ACTIVITY_DT_MODE",
            "XCTestConfigurationFilePath",
        ]
    )
    func xcodeConsoleUsesEmoji(marker: String) {
        let capabilities = TapeConsoleCapabilities.detect(
            environment: ["TERM": "xterm-256color", marker: "1"],
            isTerminal: true
        )

        #expect(capabilities.mode == .emoji)
        #expect(TapeConsoleCapabilities.isXcodeConsole(environment: [marker: "1"]))
    }

    @Test("A terminal without TERM gets emoji badges")
    func missingTermUsesEmoji() {
        let capabilities = TapeConsoleCapabilities.detect(
            environment: [:],
            isTerminal: true
        )

        #expect(capabilities.mode == .emoji)
    }

    @Test("Dumb TERM is rejected even in a terminal")
    func dumbTermUsesEmoji() {
        let capabilities = TapeConsoleCapabilities.detect(
            environment: ["TERM": "dumb"],
            isTerminal: true
        )

        #expect(capabilities.mode == .emoji)
    }
}

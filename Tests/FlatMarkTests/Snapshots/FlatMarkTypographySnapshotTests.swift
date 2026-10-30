import FlatMark
import Foundation
import SwiftUI
import Testing

@Suite(.serialized)
@MainActor
struct FlatMarkTypographySnapshotTests {
    private static let sampler = """
    # Heading one
    ## Heading two
    ### Heading three
    #### Heading four
    ##### Heading five
    ###### Heading six

    **Bold**, *italic*, ~~struck~~, and `inline code`.

    ```swift
    let ready = true
    render(ready)
    ```

    ---

    Hard break first.\u{0020}\u{0020}
    Hard break second.
    Soft break continues here.
    """

    private static let mentions = """
    Plain @jane and split @ja*ne*.

    Emphasized *@jane* and struck ~~@jane~~.

    Email jane@example.com, code `@jane`, and [@jane](https://example.invalid/mention).
    """

    private static let wrapping = """
    ## Heading wraps with neighbors

    Before @ja*ne* and *@jane*, with `inline code` after.

    ```swift
    let greeting = "hello neighbor"
    print(greeting)
    ```

    ---

    After ~~@jane~~ the final words wrap too.
    """

    @Test func lightSampler() async throws {
        try await capture(Self.sampler, environment: Self.environment(), testName: #function)
    }

    @Test func darkSampler() async throws {
        try await capture(Self.sampler, environment: Self.environment(appearance: .dark), testName: #function)
    }

    @Test func mentionsEnabled() async throws {
        try await capture(Self.mentions, detectMentions: true, environment: Self.environment(height: 500), testName: #function)
    }

    @Test func mentionsDisabled() async throws {
        try await capture(Self.mentions, detectMentions: false, environment: Self.environment(height: 500), testName: #function)
    }

    @Test func narrowWrapping() async throws {
        try await capture(Self.wrapping, detectMentions: true,
                          environment: Self.environment(column: 180, height: 900), testName: #function)
    }

    @Test func enlargedWrapping() async throws {
        try await capture(Self.wrapping, detectMentions: true,
                          environment: Self.environment(height: 1600, textSize: .enlarged), testName: #function)
    }

    private static func environment(
        column: CGFloat = 320, height: CGFloat = 800,
        appearance: FlatMarkSnapshotEnvironment.Appearance = .light,
        textSize: FlatMarkSnapshotEnvironment.TextSize = .body
    ) -> FlatMarkSnapshotEnvironment {
        FlatMarkSnapshotEnvironment(
            captureSize: CGSize(width: 520, height: height), columnWidth: column, contentInset: 80,
            pixelScale: 2, appearance: appearance, localeIdentifier: "en_US",
            layoutDirection: .leftToRight, textSize: textSize
        )
    }

    private func capture(
        _ markdown: String, detectMentions: Bool = false,
        environment: FlatMarkSnapshotEnvironment, testName: String
    ) async throws {
        let image = try await flatMarkSnapshotImage(
            of: FlatMarkView(markdown: markdown, detectMentions: detectMentions)
                .fixedSize(horizontal: false, vertical: true),
            environment: environment
        )
        assertFlatMarkSnapshot(image, suite: .typography, named: "document",
                               environment: environment, testName: testName)
    }
}

import FlatMark
import Foundation
import SwiftUI
import Testing

@Suite(.serialized)
@MainActor
struct FlatMarkUnsupportedPolicySnapshotTests {
    private static let styled = """
    Before the policies.

    **Bold <u>middle</u> end** and *italic neighbor*.

    [Link <u>label</u> end](https://example.invalid/link)

    <div>whole block</div>

    After the policies.
    """

    private static let empty = """
    Before empty output.

    a<u></u>b

    <u></u>

    <div>whole block</div>

    After empty output.
    """

    @Test func literal() async throws {
        try await capture(Self.styled, policy: .literal, testName: #function)
    }

    @Test func custom() async throws {
        try await capture(Self.styled, policy: .custom { payload in
            var marker = AttributedString(payload.hasPrefix("<div>") ? "BLOCK" : payload == "<u>" ? "OPEN ▶" : "◀ CLOSE")
            marker.font = .system(size: 12, weight: .regular, design: .monospaced)
            marker.foregroundColor = .white
            marker.backgroundColor = payload == "<u>" ? .indigo : .orange
            return marker
        }, testName: #function)
    }

    @Test func omit() async throws {
        try await capture(Self.styled, policy: .omit, testName: #function)
    }

    @Test func emptyLiteral() async throws {
        try await capture(Self.empty, policy: .literal, testName: #function)
    }

    @Test func emptyCustom() async throws {
        let dispatch = EmptyPolicyDispatch()
        try await capture(Self.empty, policy: .custom { payload in
            dispatch.payloads.insert(payload)
            return AttributedString()
        }, testName: #function)
        // Re-evaluation counts are not a contract; every distinct parser payload must reach the host.
        #expect(dispatch.payloads == ["<u>", "</u>", "<div>whole block</div>\n"])
    }

    @Test func emptyOmit() async throws {
        try await capture(Self.empty, policy: .omit, testName: #function)
    }

    @Test func enabledHost() async throws { try await captureHost(disabled: false, testName: #function) }
    @Test func disabledHost() async throws { try await captureHost(disabled: true, testName: #function) }

    private func captureHost(disabled: Bool, testName: String) async throws {
        try await capture("Before the host control.\n\n<div>host control</div>\n\nAfter the host control.", policy: .custom(
            inline: { _ in AttributedString("INLINE") },
            block: { _ in AnyView(PolicyEnvironmentControl()) }
        ), disabled: disabled, testName: testName)
    }

    private func capture(
        _ markdown: String, policy: FlatMarkUnsupportedContentPolicy,
        disabled: Bool = false, testName: String
    ) async throws {
        let environment = FlatMarkSnapshotEnvironment(
            captureSize: CGSize(width: 640, height: 550), columnWidth: 400, contentInset: 80,
            pixelScale: 2, appearance: .light, localeIdentifier: "en_US",
            layoutDirection: .leftToRight, textSize: .body
        )
        let image = try await flatMarkSnapshotImage(
            of: FlatMarkView(markdown: markdown, unsupportedContentPolicy: policy)
                .disabled(disabled).fixedSize(horizontal: false, vertical: true),
            environment: environment
        )
        assertFlatMarkSnapshot(image, suite: .unsupportedPolicies, named: "document",
                               environment: environment, testName: testName)
    }
}

@MainActor
private final class EmptyPolicyDispatch {
    var payloads: Set<String> = []
}

private struct PolicyEnvironmentControl: View {
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(isEnabled ? "ENABLED" : "DISABLED") {}
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .regular, design: .monospaced))
            .foregroundStyle(isEnabled ? .white : .black)
            .padding(4)
            .background(isEnabled ? Color.indigo : Color.gray.opacity(0.3))
    }
}

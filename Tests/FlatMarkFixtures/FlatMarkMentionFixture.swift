import FlatMark
import SwiftUI

/// Backend-free mention rendering sample for the fixture runner (`--mentions`).
public struct FlatMarkMentionFixture: View {
    @State private var detectMentions = true

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle("Detect mentions", isOn: $detectMentions)
            FlatMarkView(markdown: Self.markdown, detectMentions: detectMentions)
        }
        .padding()
        .frame(maxWidth: 600, alignment: .leading)
    }

    private static let markdown = """
    # Mention rendering

    Before @jane, @jane.doe and @unknown-user after.
    Formatting splits @ja*ne*. Whole *@other* and ~~@third~~ keep their styles.
    Plain email@example.com and a@jane are not mentions.
    Formatting resets detection: *email*@example.com bolds the handle after italics.

    - List row before @jane_2 after.

    | Person | Notes |
    | --- | --- |
    | @jane | Before @other after |

    Inline `@jane` and [@jane](https://example.com) stay unchanged.
    [Normal link](https://example.com) remains a link.

    ```
    @jane is code, not a mention
    ```

    Long surrounding text with @jane.doe in the middle should wrap naturally without changing order or selection.
    """
}

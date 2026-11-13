import Foundation

// MARK: - FlatMarkOmissionSample

/// One source that puts every omission shape on screen at once — a dropped HTML block, a quote
/// whose only content was a tag, a task row, a nested quote continuation, an emptied ordered item,
/// and an emptied table cell — each with supported wording either side of it.
///
/// Four readings of the same Markdown, so a mounted check and a projection check can be compared
/// without either one defining the other: ``markdown`` as authored, ``referenceMarkdown`` as that
/// document typed by hand with the unsupported content left out, and the wording a reader is given
/// under each built-in policy, which is what the mounted renderer is held to.
///
/// The displayed oracles are the selectable wording of every native text region in document order,
/// region after region, with nothing added between them. The pieces are spelled one region per line
/// to be read, and joined, because which regions SwiftUI produces is its own business: what a reader
/// gets is the join. Two consequences are worth stating where they are easy to misread: an image
/// contributes nothing, because an image is not a text region, so `Supported image` never appears;
/// and a row whose only wording was a tag still contributes its marker (`7.`), because omission
/// empties a row rather than removing it.
enum FlatMarkOmissionSample {
    static let markdown = """
    Before

    <div>hidden block</div>

    > > <u></u>

    - [x] Keep checked
    - [ ] <u></u>

      > <u></u>

      > Supported continuation

    ![Supported image](image.png)

    7. <u></u>
    8. keep

    | A | B |
    | --- | --- |
    | <u></u> | keep |

    [Details](details)

    After
    """

    /// The same document with the unsupported content left out by hand, for the projection oracle.
    static let referenceMarkdown = """
    Before

    - [x] Keep checked
    - [ ] <u></u>

      > Supported continuation

    ![Supported image](image.png)

    7.
    8. keep

    | A | B |
    | --- | --- |
    | | keep |

    [Details](details)

    After
    """

    /// What a reader gets under `.literal`: every tag shown as the inert wording it was authored as.
    static let displayedLiterally = [
        "Before",
        "<div>hidden block</div>\n",
        "<u></u>",
        "Keep checked",
        "<u></u>",
        "<u></u>",
        "Supported continuation",
        "7.",
        "<u></u>",
        "8.",
        "keep",
        "A",
        "B",
        "<u></u>",
        "keep",
        "Details",
        "After",
    ].joined()

    /// What a reader gets under `.omit`: the same supported wording in the same order, every tag gone.
    static let displayedOmitted = [
        "Before",
        "Keep checked",
        "Supported continuation",
        "7.",
        "8.",
        "keep",
        "A",
        "B",
        "keep",
        "Details",
        "After",
    ].joined()
}

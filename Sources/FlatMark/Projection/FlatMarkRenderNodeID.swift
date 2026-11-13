/// The structural position of one rendered element inside the currently projected Markdown document.
///
/// Identity is the element's path through the parsed tree: index of each child from its
/// container, so `path` alone determines equality and hashing. Two values are the same identity
/// exactly when they address the same position in the same document. Synthetic table padding
/// uses indices after the parent's real children, under that same header or body-row path.
///
/// Identity is document-local. It is unique and stable within the currently projected document,
/// and FlatMark makes no promise about it across a structural edit, an inserted sibling, or a
/// replaced document. A source edit that shifts coordinates without changing the tree leaves
/// identities unchanged; one that changes the tree may change them.
struct FlatMarkRenderNodeID: Hashable, Sendable {
    let path: [Int]
}

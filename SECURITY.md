# Security policy

## Reporting privately

Report vulnerabilities privately by email to [flatmark@pm.me](mailto:flatmark@pm.me).
Do not open a public issue, PR, or discussion thread for a vulnerability.

Include the affected version or commit, platform, a minimal Markdown sample or call site, what you
expected, and what an attacker gains. FlatMark is maintained best-effort by one person: expect an
acknowledgement and first assessment as soon as practicable; there is no fixed SLA. Fixes ship per
the [versioning policy](Documentation/Versioning.md) and are credited in [CHANGELOG.md](CHANGELOG.md) on request.

## Threat model

Treat every Markdown string as untrusted input from anywhere. The library performs no networking of
its own, stores nothing, and runs no scripts. The host owns fetching and navigation, which is where
most risk lands. Contract details live in
[Documentation/Usage.md](Documentation/Usage.md); this page states the assumptions and host duties.

### HTML

FlatMark builds no HTML DOM. It never executes HTML, applies HTML attributes as styling, navigates
from them, or fetches a resource named by them.

**FlatMark is not a sanitizer.** `.omit` is a layout decision, not redaction: do not rely on it to hide
markup that must be removed. Scrub or reject such documents before rendering. See
[unsupported content](Documentation/Usage.md#unsupported-content) for literal and omission behavior.

### Links

There is **no scheme allowlist and no same-origin restriction**. Any nonempty absolute URL that
Foundation resolves — `http(s)`, `mailto`, `file`, or a custom scheme — can reach the inherited SwiftUI
`openURL` action on activation. Relative destinations resolve against `baseURL`, and a network-path
reference (`//host/x`) can change the host.

- Rendering never opens a URL; only activation attempts to, with no guarantee of success and no
  fallback UI. A rejected link can still look actionable before activation.
- An embedded `javascript:` destination cannot execute inside FlatMark, which has no web view. It
  becomes a risk only when a host hands the URL to its own web view or handler.
- Hosts must decide policy in `linkActivationAction` and return `.handled` or `.rejected` for anything
  they do not want opened. Do not rely on `.useDefaultOpening` for untrusted documents.
- Granting navigation does not authorize image fetching, and vice versa.

### Images

Without a `FlatMarkImageLoader`, images are deterministic, network-free alt-text placeholders. With a
loader, **host code fetches the URL**, so these are host responsibilities:

- Server-side request forgery: a Markdown image can name an internal or metadata address.
  `FlatMarkImageURLPolicy.webOnly` gates schemes to HTTP(S) before the loader runs, but it is a
  scheme check only. Re-validate the resolved host in the loader if the document is untrusted.
- Authentication, redirects, response size, decoding limits, and cache lifetime and scope.
- Preventing obsolete loader requests from updating host-owned caches or causing other host-side
  effects. FlatMark's loading and cancellation contract is in the [image guide](Documentation/Usage.md#images).

Relative image sources use `baseURL`; the same host-revalidation point applies.

### Task edits

Authorize and validate returned task edits before writing them, and prevent a deferred result from
overwriting newer content. See [interactive tasks](Documentation/Usage.md#interactive-tasks) for the
source-update contract.

### Not security issues

Not rendering or fetching HTML, the absence of a default link scheme allowlist, GFM extended autolinks
being off, and unparsed constructs shown as inert text are documented design behavior. Report them as
ordinary issues if you disagree with the design.

### Privacy of captured artifacts

Capture and benchmark outputs must not carry machine identifiers.
[`scripts/log_sanitizer.py`](scripts/log_sanitizer.py) strips developer-home paths, machine-local Xcode
paths, and terminal escapes from recorded tool output, and capture scripts record a device name rather
than a simulator UUID. Route new capture tooling's tool output through the sanitizer.

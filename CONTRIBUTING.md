# Contributing to SwiftKLine

**English** | [简体中文](CONTRIBUTING.zh-CN.md)

Contributions are welcome: reproducible bug reports, focused fixes, new examples, documentation, and translations. For a substantial feature or public API change, open an issue describing the use case before investing in a large implementation.

## Report a bug or request a feature

Use [GitHub Issues](https://github.com/zhwayne/SwiftKLine/issues). For a bug, include:

- A minimal reproduction and expected versus actual behavior.
- Device or simulator, OS version, Xcode version, and Swift version.
- Data source, candle period, enabled indicators, and relevant configuration.
- Steps to reproduce, useful logs, and screenshots or traces when relevant.

Remove credentials and account data from attachments. For a feature, explain the use case, current workaround, and proposed API behavior. English and Chinese reports are welcome.

## Set up the repository

```sh
git clone https://github.com/zhwayne/SwiftKLine.git
cd SwiftKLine
open SwiftKLineExample.xcodeproj
```

Use Swift 6 and Xcode 16 or newer; repository checks currently use Xcode 26.2. Install an iPhone simulator runtime through Xcode for UI tests. The library supports iOS 13+, while the example requires iOS 18+. Core tests and benchmarks run on macOS.

## Build and test

| Command | Purpose |
|---|---|
| `swift test` | Host tests for Foundation code |
| `./script/test-ios.sh` | Package tests, including UIKit and example lifecycle paths, on an iPhone simulator |
| `./script/build-example.sh` | Example app build for a generic iOS Simulator |
| `./script/validate-docs.py` | Local links, heading anchors, bilingual page coverage, and executable-snippet parity |

`test-ios.sh` selects an available iPhone automatically; override it with `SWIFTKLINE_DESTINATION`, such as `platform=iOS Simulator,name=iPhone 17`. Both shell scripts accept `SWIFTKLINE_DERIVED_DATA` for build output.

Run the suites relevant to your change. Use Core tests for formula or merge changes and simulator tests for UI, plugin, session, and lifecycle behavior. Record the commands and results in the pull request.

## Code and API conventions

- Keep Core Foundation-only. Put UIKit coordination and rendering in `SwiftKLineUI`, and keep SwiftUI integration in application/example code.
- Keep calculations, network transport, and rendering separate. Exchange authentication, account models, and execution semantics belong to applications.
- Respect `MainActor`, `Sendable`, and structured cancellation; avoid unchecked annotations that hide ownership problems.
- Preserve semantic identities across updates. Source IDs describe data and calendar meaning; plugin IDs describe stable features.
- Follow existing Swift formatting and English API comments. Preserve the original creation date when moving a source file.
- Add regression coverage for identity, paging, cancellation, and publication changes.

See [Architecture](docs/architecture.md) for ownership rules and [Performance](docs/performance.md) for measurement expectations.

## Documentation and translations

Update both language editions when behavior or public APIs change:

| English | 简体中文 |
|---|---|
| `README.md` | `README.zh-CN.md` |
| `CONTRIBUTING.md` | `CONTRIBUTING.zh-CN.md` |
| `CHANGELOG.md` | `CHANGELOG.zh-CN.md` |
| `docs/*.md` | `docs/zh-CN/*.md` |

Keep the top-of-page language switch pointing to the equivalent page, and keep internal guide navigation in the same language. Keep Swift snippets identical across translations so both editions teach the same API. Snippets that use trade-marker types belong to the example app, not the public library.

After editing links or examples, run `./script/validate-docs.py`. Compile usage examples in an iOS app target against the current library with Swift 6 concurrency checking. Documentation examples do not replace runtime tests.

## Submit a pull request

1. Create a topic branch and keep the change focused.
2. Explain the problem, resulting behavior, and any API impact.
3. Update affected guides and add an entry under `Unreleased` in both changelogs.
4. Run relevant checks and include their results and any limitations.
5. Review the diff for generated files, DerivedData, credentials, and unrelated edits.

Use the repository's existing commit style, for example `feat(indicator): ...`, `fix(loader): ...`, or `docs: ...`. For performance work, include hardware, build mode, data size, and method; distinguish algorithm benchmarks from device interaction measurements.

Keep discussions respectful and focused on the work. Review may request changes to module boundaries, lifecycle cleanup, API scope, or documentation accuracy.

## License

Contributions are distributed under the project's [MIT License](LICENSE).

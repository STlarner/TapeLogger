# Maintaining the documentation

## Source of truth

- Public API descriptions belong in Swift `///` comments, including default
  implementations and methods added to external types.
- Module overviews and workflow guides belong in `Sources/<module>/<module>.docc`.
- The README contains the introduction, screenshots and a quick start. Do not
  duplicate the API reference or usage guide there or in `docs/Guide.md`.
- Generated HTML, archives and symbol graphs are build artifacts, not sources.

The published entry point is
**https://stlarner.github.io/TapeLogger/api/**. GitHub Pages uses the repository's
case-sensitive `TapeLogger` path. The default site follows **main**, not the
latest release. Each module overview says so, and source links point to the
exact commit used by the build. Released versions remain available as source
comments in their Git tags; a separate versioned website is not generated yet.

## When CI runs

| Event | Checks | Deployment |
| --- | --- | --- |
| Pull request targeting `main` | Tests, iOS DocC builds, comment coverage, Swift examples | Downloadable preview artifact only |
| Push to `main` | The same checks | Publish after all checks pass |
| Manual run on `main` | The same checks | Publish after all checks pass |
| Manual run on another branch | The same checks | No deployment |

PRs do not get deployment credentials. The workflow uses `pull_request`, not
`pull_request_target`. Fork code can be checked without publishing it.
Superseded runs on the same ref are cancelled. Releases and tag pushes do not
replace `main` documentation with a different version.

## Local checks

Requires Xcode with an iOS Simulator SDK and DocC's archive-merging command.
CI uses Xcode 26.2 on macOS 15. No package or runtime dependencies are added.

From the repository root:

```sh
swift test
python3 Scripts/build_documentation.py
python3 Scripts/check_examples.py
```

Outputs are under `.build/documentation`:

- `derived-data/`: iOS builds, symbol graphs and per-module archives.
- `TapeLogger.doccarchive/`: merged, locally browsable documentation archive.
- `site/`: GitHub Pages artifact, with the documentation under `api/`.

Open the merged archive in Xcode to browse locally. The static site's asset
paths target `/TapeLogger/api/`; serve it under that prefix when previewing
HTML rather than opening files directly.

For builds outside the checkout, pass `--output <directory>` to the builder
and `--documentation-build <directory>` to the example checker. No simulator
needs to be booted to generate docs or compile examples.

## What fails the build

1. DocC warnings, including unresolved symbol links and inconsistent parameter
   documentation, are treated as errors.
2. The coverage script reads compiler-generated **iOS** symbol graphs and
   requires a nonempty comment for every source-declared public/open symbol
   in all three modules. This includes UIKit-conditional APIs and extensions
   of SwiftUI, Swift and core types. Compiler-synthesized conformances and
   imported framework declarations are excluded.
3. Every `swift` code fence in the README, source comments and DocC articles
   is compiled for iOS in Swift 6 mode, not merely parsed. The harness imports
   Foundation, UIKit, SwiftUI and all package modules for API-comment snippets.
   Keep README examples explicit about the imports an app needs. Package
   dependency fragments are validated as actual SwiftPM manifests.
4. Package tests must pass before publishing.

Comment coverage is not a quality score: explain behavior, defaults, lifetime,
concurrency, errors and privacy where relevant. Don't satisfy the check with
empty restatements of a declaration. Examples are compiled, not executed;
runtime behavior still requires tests.

## Editing DocC

Use double-backtick symbol links for API references and `<doc:ArticleName>`
for articles in a catalog. Prefer links over repeating an API's behavior in
several pages. Update tests and comments together when behavior changes.

For normal API changes, add documentation in the same commit. Check the CI
preview artifact before merging. Never edit generated JSON or HTML to fix a
page; change the Swift comment or DocC source and rebuild.

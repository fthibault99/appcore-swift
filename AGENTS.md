# AppCoreSwift Agent Guidance

This file applies to the entire AppCoreSwift repository. `README.md` remains the source of truth for supported capabilities, installation, and public usage examples.

## Before changing code

1. Inspect `Package.swift`, the relevant files under `Sources/AppCoreSwift`, and nearby tests under `Tests/AppCoreSwiftTests`.
2. Check `git status` and preserve unrelated or pre-existing worktree changes.
3. Read the relevant `README.md` section and update it when a public API or supported capability changes.
4. Establish the current AppCore backend contract before adding or changing an endpoint. When the AppCore Java repository is available, inspect its controller, DTOs, validation, error mapping, security rules, and tests rather than inferring the contract from an application client.

## Client boundaries

- Keep `AppCoreClient` typed and authenticated. All AppCore requests use the existing `X-API-Key` mechanism unless the backend contract explicitly defines another boundary.
- Preserve endpoint paths, HTTP methods, field names, nullability, enum raw values, multipart field names, response shapes, and centralized AppCore error decoding.
- Keep prompts, OpenAI/provider configuration, model settings, server IDs, timestamps, and secrets out of this package. Clients send business input only.
- Never hardcode, print, log, or commit real API keys. Tests must use obvious non-production values.
- Do not introduce a second networking layer or duplicate an existing client method. Extend the current `AppCoreClient` helpers and feature models.
- Keep public request and response models `Codable`, `Equatable`, and `Sendable` where the surrounding contract follows that convention.
- Preserve Swift 6 concurrency safety and the platform minimums declared in `Package.swift`.

## Networking details

- For JSON endpoints, verify authentication, URL, method, encoded body, response decoding, and structured server errors.
- For multipart endpoints, send raw image data with the exact media type and backend field names. Do not move server-owned prompts into the client or convert images to Base64 unless the backend contract explicitly requires it.
- For SSE streaming, parse raw bytes using complete event-frame separators (`\n\n` and `\r\n\r\n`). Do not rely on line-by-line iteration when it can lose frame boundaries or delay deltas.
- Preserve cancellation and error propagation for `AsyncThrowingStream` APIs.

## Tests and verification

- Add or update focused XCTest coverage for every public contract change.
- Use the existing `URLProtocolStub` pattern for network tests; tests must not call AppCore or any external service.
- When inspecting streamed or multipart requests, account for `URLRequest.httpBodyStream` as the existing tests do.
- Run `swift test` after source changes. For documentation-only changes, `git diff --check` is sufficient unless the documentation describes a changed API.
- Before handing off, run `git diff --check` and report exactly which tests, builds, and live integration checks were or were not completed.
- Do not claim compatibility with a deployed AppCore environment from package tests alone; verify the live server separately when required and available.

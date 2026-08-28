# NOTICE

## Egakium product code

Egakium is an Apple-first product overlay maintained in
`/Users/vita/Vitemis/Volans/Egakium`. Product-owned code and assets are original unless an upstream source is
identified below or in `ThirdPartyNotices/`.

Egakium does not use leaked or private source code or prompts, and does not adopt third-party names, logos,
screenshots, UI assets, trademarks or brand copy as its identity. Open-source reuse does not bypass the product's
permission, workspace, secret, EventLog or Apple-platform boundaries.

## First-party Intatis source dependency

Egakium directly compiles the single first-party Intatis checkout at `/Users/vita/Vitemis/Intatis` through the
SwiftPM local dependency `../../Intatis`. Intatis supplies the shared Core, Protocol, Providers, Conversation,
Artifacts, SharedUI, Tools, Knowledge, Skills, Permission, MCP, AgentKernel, Cowork and Codex Runtime host
implementations. Egakium no longer vendors or republishes copied `Egakium*` versions of those implementations.

Intatis itself incorporates compatible third-party dependencies. Their exact provenance, versions, modification
scope and license texts are maintained in `/Users/vita/Vitemis/Intatis/NOTICE.md` and
`/Users/vita/Vitemis/Intatis/ThirdPartyNotices/`. Xcode copies that complete `ThirdPartyNotices` directory into the
Egakium App resources; this preserves attribution without creating a second source snapshot. Notices present in an
iOS bundle do not imply that every described optional runtime is linked into the iOS target.

The official Codex executable distributed with the macOS App is copied from the validated Intatis runtime kit into
`Contents/Resources/CodexRuntime/arm64`. It remains subject to the Apache License 2.0 and the exact runtime SPDX/
license closure shipped beside it. The runtime is verified for version, architecture and derivation before and after
embedding; no ambient PATH/Homebrew executable is a release fallback.

## Chromium Embedded Framework Canvas dependency

The macOS Session Canvas directly uses the official Chromium Embedded Framework `151.3.17` ARM64 Standard
Distribution (Chromium `151.0.7922.138`), fixed at CEF commit
`f059e67fa6aad5e8cce8bebea5df706ffddfb174`. The archive identity, SHA-256, integration scope and distribution
obligations are recorded in `ThirdPartyNotices/ChromiumEmbeddedFramework.md`.

CEF's BSD-style license is reproduced at `ThirdPartyNotices/Licenses/CEF-151.3.17-LICENSE.txt`. Built macOS Apps
also include the official distribution's complete `LICENSE.txt` and `CREDITS.html` under
`Contents/Resources/ThirdPartyNotices/CEF/`. CEF is the sole Canvas renderer; no WebKit Canvas backend or fallback
is linked.

The minimal `NSApplication` event and orderly-termination wiring derives from the official JCEF category/swizzling
pattern at commit `6d3e8ca02cd3ec0af163086f9a79281beb0cc60e`. Its BSD-style license is reproduced at
`ThirdPartyNotices/Licenses/JCEF-6d3e8ca0-LICENSE.txt`. Egakium does not link or distribute Java, AWT or JNI JCEF
runtime code.

## OpenAI Codex Skill Creator derivative

The project-local `.agents/skills/egakium-skill-creator/` Skill is a modified derivative of the public OpenAI Codex
`skill-creator` sample from release `rust-v0.145.0`, fixed at commit
`25af12f7e61572b0bc18ddb1008be543b91519b0`.

- Upstream: `openai/codex`, Apache License 2.0, Copyright 2025 OpenAI.
- Reuse type: vendored and derived project-maintenance Skill; it is not an application runtime or product UI asset.
- Egakium adapts the instructions and validation resources for its project-local paths, permission semantics,
  secret scanning and bounded resource rules.
- Exact provenance and modification scope are in `ThirdPartyNotices/OpenAICodexSkillCreator.md`; the complete
  Apache-2.0 text is at `ThirdPartyNotices/Licenses/Codex-61a44880-Apache-2.0.txt`.

## Source-reuse and release rule

New or upgraded dependencies must satisfy `/Users/vita/Vitemis/docs/DEPENDENCY_POLICY.md` and
`docs/OPEN_SOURCE_REUSE.md`. A local build is not a distribution claim: Developer ID signing, notarization,
stapling, Gatekeeper, exact runtime closure and license inventory must all pass before release.

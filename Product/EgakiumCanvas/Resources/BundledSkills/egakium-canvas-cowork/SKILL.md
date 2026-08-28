---
name: egakium-canvas-cowork
description: Coordinate the current Egakium Cowork Session Canvas and its isolated child HTML element documents.
---

# Egakium Canvas Cowork

Use this Skill only for the current Egakium Cowork Session Canvas.

- The host creates the exact Session `index.html` once. The root `@main` owns
  subsequent whole-page HTML/CSS/JavaScript coordination through ordinary
  workspace tools and approvals.
- Read the exact Canvas path supplied in the current user-context block before
  editing it. Do not infer a Session ID or use another Session's Canvas.
- The main page keeps `#canvas` as its direct element container. Each card is a
  direct `.egakium-element` child with a safe unique `data-element-id`, source
  `data-x`, `data-y`, `data-width`, `data-height`, optional `data-z`, a title,
  and a relative `iframe sandbox="allow-scripts"`.
- CEF renders source HTML directly. Do not create another drag/resize runtime,
  renderer adapter, network fallback, or Web-storage layout authority.
- Native Codex child agents receive a host-provisioned, deterministic element
  document path in their thread instructions. Wait for a successful child
  result before integrating its relative iframe into the shared `index.html`.
- A child edits only its assigned element document and local assets. It must
  not edit the shared Session `index.html` or another child's element.
- Agent↔element association is task-scoped provenance, not permanent ownership
  or a capability. Read-only children still cannot edit their file.
- Keep all resources local. The child template forbids network connections and
  nested frames; do not loosen CSP or add a native execution bridge.

The outer Canvas owns card layout. Each child document owns only its internal
content below `#element` and `#content`.

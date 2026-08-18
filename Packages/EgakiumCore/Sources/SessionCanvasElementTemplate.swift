/// The one host-authored starting document for a fresh Canvas element task.
///
/// A successful `spawn_agent` admission materializes these exact bytes in a
/// fresh, host-chosen element path before the agent becomes durable. Legacy or
/// manually attached Cowork workers may still receive the identity-free bytes
/// as a trusted prompt fallback. The template itself intentionally contains no
/// AgentID, ElementID, SessionID, or destination, so it cannot create permanent
/// Agent/Element ownership or grant filesystem authority.
public enum SessionCanvasElementTemplate {
  public static let templateVersion = 1

  public static let html = #"""
    <!doctype html>
    <html lang="en" data-egakium-element-template="1">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <meta http-equiv="Content-Security-Policy" content="default-src 'self' data: blob:; connect-src 'none'; img-src 'self' data: blob:; media-src 'self' data: blob:; font-src 'self' data:; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline'; frame-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'">
      <title>Untitled Canvas Element</title>
      <style>
        :root {
          color-scheme: light dark;
          font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
          color: CanvasText;
          background: Canvas;
          --element-muted: color-mix(in srgb, CanvasText 62%, transparent);
          --element-separator: color-mix(in srgb, CanvasText 14%, transparent);
          --element-accent: AccentColor;
        }

        * { box-sizing: border-box; }

        html, body {
          width: 100%;
          min-width: 100%;
          min-height: 100%;
          margin: 0;
        }

        body {
          min-height: 100vh;
          overflow: auto;
          color: CanvasText;
          background: Canvas;
        }

        #element {
          display: flex;
          flex-direction: column;
          width: 100%;
          min-height: 100vh;
          padding: clamp(18px, 4vw, 32px);
        }

        .element-header {
          display: grid;
          gap: 8px;
          padding-bottom: 18px;
          border-bottom: 1px solid var(--element-separator);
        }

        .element-eyebrow {
          margin: 0;
          color: var(--element-accent);
          font-size: 12px;
          font-weight: 700;
          letter-spacing: 0.08em;
          text-transform: uppercase;
        }

        .element-title {
          margin: 0;
          font-size: clamp(22px, 6vw, 36px);
          line-height: 1.08;
          text-wrap: balance;
        }

        .element-summary {
          max-width: 62ch;
          margin: 0;
          color: var(--element-muted);
          font-size: 14px;
          line-height: 1.5;
        }

        #content {
          flex: 1;
          min-width: 0;
          padding-top: 20px;
        }

        .element-empty-state {
          display: grid;
          place-items: center;
          min-height: 100px;
          padding: 16px;
          border: 1px dashed var(--element-separator);
          border-radius: 14px;
          color: var(--element-muted);
          text-align: center;
        }

        .element-empty-state p {
          max-width: 42ch;
          margin: 0;
          line-height: 1.55;
        }
      </style>
    </head>
    <body>
      <!--
        The outer Session Canvas source owns card placement and dimensions.
        CEF renders this document directly without a host-injected DOM runtime.
        This document owns only this element's internal content. Preserve
        #element and #content as stable integration boundaries.
      -->
      <main id="element" data-egakium-element-document="1">
        <header class="element-header">
          <p class="element-eyebrow">Canvas element</p>
          <h1 class="element-title">Untitled element</h1>
          <p class="element-summary">
            Replace this starter copy with the assigned element content.
          </p>
        </header>
        <section id="content" aria-live="polite">
          <div class="element-empty-state">
            <p>This fresh element template is ready for HTML, CSS, JavaScript, and local assets.</p>
          </div>
        </section>
      </main>
    </body>
    </html>
    """#
}

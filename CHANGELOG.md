# Changelog

All notable changes to the `site-to-prompt` skill are documented here.
This project follows [Semantic Versioning](https://semver.org/): `MAJOR.MINOR.PATCH`.

## [1.2.0] — 2026-06-26

### Added
- **Update notifier:** a plugin SessionStart hook (`hooks/check-update.sh`) compares the
  installed version against the latest on GitHub and, at most once per 24h, surfaces a
  one-line "vX.Y.Z is available — update with …" notice. Network-failure-safe, silent when
  already current, and it only reads the public `package.json` (sends no data). Notifier
  only, never auto-updates — the user stays in control of when to pull. (Plugin installs
  only; `npx skills` / manual users update via the README's Updating section.)

## [1.1.0] — 2026-06-26

Multi-page scope and QA verification — the two biggest fidelity gaps from real use.

### Added
- **Scope gate (Step 1.5):** enumerate the site's pages (nav + footer links, `sitemap.xml`)
  and ask the user up front whether to parse just the entry page, the whole site, or a
  specific page/section — instead of silently parsing only the home page. One prompt per page.
- **Prompt QA (Step 6):** a fresh-context QA subagent audits the prompt against the live
  source for scope match, section completeness, fabrication/vagueness, `[inspect:]` count,
  and capture of the hard stuff (WebGL, scroll formulas, section heights) before handoff.
- **Build QA gate:** after building, a dedicated QA agent screenshots build vs original
  (every page in scope) and fails on blank canvases, missing/empty sections, missing pages,
  or signature visuals that don't match — so an incomplete build (e.g. a WebGL render that
  came out blank) is caught and reported, not shipped as "done."

### Changed
- Build Phase now builds every page in the chosen scope and wires up navigation.
- A build is "done" only after QA passes or its open gaps are explicitly accepted by the user.

## [1.0.0] — 2026-06-26

First tagged release. The skill takes a URL, reverse-engineers the live site from
its real source, and writes a reconstruction prompt as a Markdown file — and can
optionally build the site from that prompt.

### Added
- URL → reconstruction-prompt workflow with a fixed, fielded output format.
- `curl`-based source extraction (raw HTML/CSS/JS) instead of summarized fetches.
- Lazy-chunk mining: follows code-split Vite/webpack chunks to the real animation logic.
- Live-DOM measurement step — computed styles, per-section viewport-fraction heights,
  grid/flex placement, and scroll-linked transform sampling (rendered proportions,
  not just source formulas).
- Parallel subagent fan-out for reading large bundles, keeping the main context clean.
- Optional Build Phase: generate the working site from the prompt, section by section,
  and verify it in a browser.
- Output is written to a Markdown file the same (or another) agent can build from.
- Non-negotiable fidelity rules (no fabricated values; gaps marked `[inspect: …]`).

[1.0.0]: https://github.com/dhernz/site-to-prompt/releases/tag/v1.0.0

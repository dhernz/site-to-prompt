# Changelog

All notable changes to the `site-to-prompt` skill are documented here.
This project follows [Semantic Versioning](https://semver.org/): `MAJOR.MINOR.PATCH`.

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

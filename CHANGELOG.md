# Changelog

All notable changes to the `site-to-prompt` skill are documented here.
This project follows [Semantic Versioning](https://semver.org/): `MAJOR.MINOR.PATCH`.

## [1.4.0] — 2026-06-27

Motion-first reconstruction — stop flattening animated sites into static skins.

### Added
- **"Motion is content" principle** in the Overview: a site's signature animation is the
  primary deliverable, not decoration.
- **Section classification (Step 3):** every section is tagged motion-critical or
  content-critical via the forcing question "if I removed the animation, does it still
  deliver its point?"
- **Motion-first capture (Step 4):** motion-critical sections require a `Signature motion`
  spec — behavior not asset (pin/parallax/reveal, scroll runway, frame vs full-bleed,
  overlays/cues, 0/50/100% choreography). Output Format tags each section and leads
  motion-critical ones with the motion spec.
- **QA verifies motion by scrolling:** Step 6 prompt-QA gains a top-priority motion-fidelity
  check, and the Build-Phase QA gate now drives the page — a static reproduction of a
  motion-critical section is an automatic FAIL even if the still frame matches.
- **Named anti-patterns** in Common Mistakes: flattening an animated section into a static
  image with text on top, and passing QA on a static screenshot of an animated section.

## [1.3.1] — 2026-06-26

### Changed
- Simplified the up-front heads-up to the user: it gives the time estimate and outlines the
  plan — "first I'll analyze the site, then ask which pages or sections you want parsed, then
  create the prompt."

## [1.3.0] — 2026-06-26

### Added
- **In-run version nudge (Step 0):** the skill now carries its own version stamp and, at the
  start of a run, quietly checks the latest published version. If the installed copy is older,
  it adds one line to its final message — `you're on vX, latest is vY — update with …`. This
  reaches `npx skills` and manual-copy users, who don't get the plugin SessionStart hook.
  Silent when current/offline; never blocks the task.
- **`bin/bump-version.sh`:** one command bumps the version across all manifests and both
  SKILL.md stamps so they can't drift.

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

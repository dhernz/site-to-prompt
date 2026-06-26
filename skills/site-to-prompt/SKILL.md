---
name: site-to-prompt
description: Use when given a website URL and asked to reverse-engineer it — to produce a detailed reconstruction prompt and/or rebuild the site in HTML/CSS or React/Tailwind. Covers animated, scroll-driven, and WebGL sites.
---

# site-to-prompt

## Overview
Visit a live website, analyze it completely from its real source, and produce a reconstruction prompt — covering fonts, colors, animations, sections, components, assets, and responsive rules — that enables another agent to rebuild the site from scratch without ever visiting the original. Optionally, hand the prompt to a builder and generate the site (see Build Phase).

The full flow: **URL → confirm scope → analyze → reconstruction prompt → (optional) build → QA verify.**

A site is more than its home page, and a parse is worthless if the build doesn't match it. So two gates are non-negotiable: **confirm scope before analyzing** (don't silently parse only the home page — Step 1.5), and **run a QA pass that compares the result against the original** (don't silently ship something incomplete — the prompt is QA'd in Step 6, the built site in the Build Phase QA step).

### How this runs (and what it costs)
This skill reads the site's real CSS/HTML/JS source, which is large — so it **dispatches parallel subagents** to do the heavy reading (one per bundle: CSS, HTML, JS, plus the live-DOM measurement dump). Each subagent reads in its own context and reports back only the exact values, keeping the main context clean.

**The more animations the page has, the more tokens it takes to run the skill.** A mostly-static page is cheap and quick. A scroll-driven, WebGL, or heavily animated site means more JS to read, more scroll-linked transforms to sample, and more per-section DOM measurement — each subagent can run 40–60k+ tokens, and several run in parallel. **Depending on animation complexity, a full run can take 5–15 minutes or more.** Tell the user this up front so the time and token budget are expected, not a surprise.

## Analysis Workflow

### Step 1: Capture the Site (source first, screenshots second)

**`WebFetch` cannot return raw HTML/CSS/JS — it summarizes. Use `curl` instead.** The real source is the highest-fidelity signal; screenshots are secondary confirmation.

1. **Fetch the raw HTML** with a real browser User-Agent:
   ```bash
   UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36"
   curl -sL -A "$UA" "<URL>" -o index.html
   ```
2. **Inspect `<head>`** for `<title>`, meta/OG tags, `@font-face`/font imports, and every CSS/JS `<link>`/`<script>` src.
3. **Fetch the linked CSS and JS bundles** with the same `curl`. Save them locally so subagents/greps can read them.
4. **Map the body structure** — grep for `<section>`, `<header>`, `<footer>`, class names, and `data-*` attributes (these usually drive the animations).
5. **Screenshots (confirmation):** use a headless browser (e.g. the `browse` skill) to capture top / 25% / 50% / 75% / bottom. NOTE: headless WebGL often fails to initialize, and scroll-driven content frequently sits at `opacity:0` / off-canvas until JS animates it — so screenshots of heavily animated sites may render blank. When that happens, **trust the source code**, not the blank screenshot, and say so.
6. **Measure the rendered DOM (do this even when screenshots are blank).** WebGL failing does NOT stop the DOM from laying out — `getComputedStyle` and `getBoundingClientRect` still return real values. Source CSS gives you animation *formulas* but NOT the rendered *proportions*, and those proportions decide how an animation feels. For every key element capture:
   - Computed `font-size`, `color`, `font-family`, `font-variation-settings` — the resolved px/hex, not the `var()` token.
   - `getBoundingClientRect()` height **as a fraction of the viewport** (`innerHeight`). A section's height drives how fast scroll-progress changes: a tall section makes a scroll-linked transform crawl; a short one makes it pop. This is the single most common reconstruction miss.
   - `position` (static / relative / absolute / sticky / fixed) and stacking.
   - **Grid/flex placement of every positioned child.** Editorial layouts hand-place each item with explicit `grid-row` / `grid-column` (and `margin-top` nudges) — a scattered look that an auto-flow `span N` will NEVER reproduce, and that is invisible in a quick CSS skim. Dump `gridRowStart/End`, `gridColumnStart/End`, `marginTop`, `alignSelf` for each child of any grid. This is more reliable than reading the source CSS, because source rules carry responsive duplicates that flatten ambiguously when grepped — the computed value at a known viewport is unambiguous.
   - **Inner-element structure and animation.** A word like `<span><span>Word</span></span>` often wraps an inner element that masks/reveals/transforms independently. Check the inner element's computed `transform`/`transition`/`overflow`, not just the outer.
   - **Sample scroll-linked transforms at 2-3 scroll offsets** to record the parallax rate (how many px an element drifts per px of scroll). Caveat: sites using smooth-scroll libraries (Lenis, Locomotive) ignore programmatic `window.scrollTo`, so their scroll-driven values won't update under a scripted scroll — note the rate from the source formula + section height instead.

   Do this for **every section, top to bottom** — not just the one you happen to be debugging. A scripted dump (loop over sections → JSON of per-child computed layout) is the reliable way; eyeballing one section at a time guarantees you miss the others. Put these measured numbers in the prompt (e.g. "manifesto title: span1 row1/col1-13, span2 row2/col4-8 …; section height ≈ 55vh; body 19px mono #858585").

For large files, fan out: dispatch parallel subagents to read the local CSS, HTML, and JS — one each — and report exact values. Keeps your context clean and is faster.

### Step 1.5: Confirm Scope — which pages? (DO THIS BEFORE DEEP EXTRACTION)

**The default failure is parsing only the entry page and stopping.** Most sites have more: `Projects`, `About`, `Playground`, `Contact`, etc. The entry page's `<nav>` / `<header>` / `<footer>` and any `sitemap.xml` tell you what else exists. Discover them, then **ask the user how much to do** — do not assume.

1. **Enumerate the pages.** From the entry HTML you already captured, list every internal link (nav, footer, in-body). Also try `curl -sL "<origin>/sitemap.xml"`. Produce a concrete list, e.g. `/` (home), `/projects`, `/about`, `/playground`, `/contact`.
2. **Ask the user to pick scope** before going further:
   - **Just this page** (the one in the URL) — fastest, cheapest.
   - **The whole site** — every page found above. Warn that cost/time multiplies per page (each page is its own full analysis: 5–15 min and 40–60k+ tokens each on animated sites).
   - **Specific page(s) or one section** — let them name what they want (e.g. "just the Projects page" or "only the hero").
3. **Record the chosen scope** and run the rest of the workflow (Steps 2–6) **per page in scope.** Capture each page's own HTML/CSS/JS (Step 1) — pages often share a bundle but have different DOM, sections, and per-page chunks.
4. **One prompt file per page** (e.g. `<site>-home-reconstruction-prompt.md`, `<site>-projects-…`), or a single file with a clear `# PAGE: /projects` heading per page. Make multi-page structure explicit so the builder knows it's building more than one page.

If the user is absent or says "you decide," default to **the entry page only** and state clearly in the output that other pages (list them) were found but not parsed — never imply full-site coverage when you did one page.

### Step 2: Identify Tech Stack
Look for these signals in source/network tab:
- **React / Next.js**: `__NEXT_DATA__`, `_next/`, `__react`, Vite bundles
- **Framer Motion**: `data-framer-*` attrs, `motion.div`, `useScroll`, `useTransform`
- **GSAP**: `gsap`, `ScrollTrigger`, `TweenMax`
- **CSS-only**: `@keyframes` in stylesheets, `animation:` properties
- **Three.js / WebGL**: `<canvas>`, `THREE`, spline-viewer web components
- **Spline**: `<spline-viewer>` tag or `@splinetool/react-spline`
- **Video**: `<video>` tags, Vimeo/YouTube embeds, `.mp4` URLs

### Step 3: Map Sections Top to Bottom
List every visual section in the order it appears:
- Hero (full-viewport intro)
- Marquee / ticker / horizontal scroll rows
- About / mission / intro text
- Services / features / capabilities
- Projects / work / portfolio / case studies
- Testimonials / social proof
- Pricing
- CTA / contact
- Footer

Name each section by what you observe, not by generic labels.

### Step 3.5: Read JS Source for Animations
You cannot scroll or interact with the page — so you cannot observe scroll-triggered animations visually. Instead:
- Fetch the main JS bundle or linked script files
- Search for: `useScroll`, `useTransform`, `ScrollTrigger`, `scrollY`, `translateY`, `opacity`, `delay`, `duration`, `stagger`, `easing`
- Extract animation values directly from source code (not from visual inference)
- For Framer Motion: look for `initial`, `animate`, `whileInView`, `transition` props
- For GSAP: look for `gsap.to`, `gsap.from`, `ScrollTrigger.create` calls
- For CSS animations: fetch linked `.css` files and extract `@keyframes` and `animation:` rules
- **Follow code-split chunks.** Modern Vite/webpack bundles keep the entry file thin — the actual per-effect logic lives in lazy chunks loaded on demand. If the main bundle only contains a registry mapping selectors/`data-*` attrs to chunk filenames (e.g. `[data-quadtree]→quadtree-COINQ5Zj.js`), `curl` those chunk files from the same `/assets/` path and read them. They are usually small and contain the real durations, easings, thresholds, and scroll offsets.
- Many sites also expose tuning via `data-*` attributes in the HTML (e.g. `data-quadtree-depth="5"`, `data-in-start="top bottom"`). Cross-reference the HTML attributes against the chunk that parses them to get both the defaults and the per-element values.
- If you can't find the animation code, write `[inspect: check JS bundle / lazy chunk for scroll animation logic]`

### Step 4: Per-Section Deep Extract
For EVERY section, capture all of the following:

**Layout**
- Container type: flex, grid, absolute positioning
- Direction, alignment, justify, wrap
- Padding and margin (all sides, all breakpoints)
- Z-index layering if relevant
- overflow behavior

**Background**
- Solid color (hex), gradient (type + stops), image URL, video URL
- Border radius on section corners

**Typography**
- Font family and weight for every text element
- Font size: exact value or `clamp(min, preferred, max)` or `[N]vw`
- Color (hex), text-transform, letter-spacing, line-height
- Exact copy — every word, exactly as it appears on screen

**Images and Media**
- Full URL of every image, GIF, video
- Display dimensions (width, height)
- Border-radius
- `object-fit` behavior
- Lazy loading

**Animations** (see Animation Reference below)
- Type, direction, initial state → final state
- Delay (seconds), duration (seconds), easing curve
- Trigger: page load, scroll into viewport, scroll position, hover
- For scroll-driven: scroll offset formula (e.g. `scrollY * 0.3`)

**Responsive overrides**
- Explicit values at mobile (< 640px), tablet (640–1024px), desktop (> 1024px)
- Font size changes, layout direction changes, element visibility changes

### Step 5: Extract Reusable Components
For every repeating UI element, capture:
- **Buttons**: gradient, border, box-shadow, border-radius, padding, font, hover state
- **Cards**: dimensions, border, background, border-radius, shadow, inner layout
- **Navigation**: layout style, link colors, font, sticky behavior, mobile menu
- **Custom cursors / scroll indicators / loaders**

### Step 6: QA the Prompt (parse completeness — before handoff)

Before declaring the prompt done, **dispatch a QA subagent** (fresh context, so it isn't biased by what you think you wrote) to audit the prompt *against the live source*, not against your memory. The QA agent checks:

- **Scope match:** every page the user asked for (Step 1.5) has its own complete section in the prompt. No page silently dropped.
- **Section completeness:** every section found when mapping the DOM (Step 3) appears in the prompt, top to bottom, none skipped.
- **No fabrication / no vagueness:** every color is a hex, every font-size a real value, every image a real URL, every animation has delay+duration+easing+states. Flag any "dark background"-style hand-waving.
- **`[inspect:]` accounting:** list every unresolved marker so the gap count is explicit, not buried.
- **The hard stuff is actually captured:** WebGL/canvas effects, scroll formulas, smooth-scroll, and section heights — the things most likely to be skipped — each have real values or an honest `[inspect:]`.

The QA agent returns a pass/fail with a list of gaps. **Fix the gaps (re-run the relevant step) before handoff.** Report the residual gaps to the user instead of implying the prompt is complete when it isn't.

---

## Output Format

**Write the reconstruction prompt to a Markdown file** (e.g. `<site-name>-reconstruction-prompt.md`) so it's a durable artifact the user can read, save, or hand to any agent — including this same one for the optional Build Phase. Tell the user the file path when done.

Generate the reconstruction prompt using this exact structure. Every field must have a real value — no placeholders, no vague descriptions.

```
Build a [type] [site/page/app] for "[Name]" using [tech stack]. [One-sentence description]. The page title is "[Title]".

GLOBAL STYLES
Background: [hex value]
Font family: [font name], [fallback]
Global reset: [list reset rules]
CSS class .[className]: [complete CSS definition]
[List all other global CSS rules]

SECTION ORDER
[Section1Name]
[Section2Name]
[...]

1. [SECTION NAME]
[One paragraph describing the full layout and purpose of the section]

[Subsection label]: [Complete spec — layout, exact copy, hex colors, font details, exact URLs, animation timing]
[Subsection label]: [Complete spec]
[...]

2. [SECTION NAME]
[...]

REUSABLE COMPONENTS
[ComponentName]: [Complete spec — all CSS values, variants, sizes, hover states, exact prop values]

KEY DEPENDENCIES
[package-name] ([version])
[package-name] ([version])

RESPONSIVE BREAKPOINTS
[Describe the overall responsive strategy and list explicit overrides]
```

---

## Build Phase (optional — generate the site)

After the reconstruction prompt is written, you can build the site from it. Do this when the user asks for the site itself (not just the prompt), or when the flow is "give URL → make prompt → generate site."

1. **Confirm target stack and scope.** Default to a single static `index.html` + CSS + a JS module unless the user specifies React/Tailwind/Next. Ask once if unclear; otherwise pick the stack named in the prompt's first line. **Build every page in the chosen scope** (Step 1.5) — if the prompt covers `/`, `/projects`, `/about`, build all of them and wire up the nav between them, not just the home page.
2. **Resolve `[inspect: …]` markers before building.** Each marker is a known gap. For each one, either fetch the missing source (re-run Step 1/3.5 on the specific file), or make an explicit, labeled approximation — never silently invent.
3. **Build section by section, in document order**, following the prompt as the spec. Reuse the exact tokens (colors, fonts, spacing vars), exact copy, and the documented animation values. Recreate the CSS-variable + scroll-progress driver pattern rather than hardcoding transforms.
4. **Assets:** reference the original CDN/media URLs from the prompt directly, OR download them locally if the user wants a self-contained build. Don't substitute stock placeholders.
5. **Reproduce, don't import blindly.** If the original uses GSAP/Lenis/Three.js, you may use the same libs, or reimplement the documented behavior with `IntersectionObserver` + `requestAnimationFrame` + CSS. Match the *behavior and numbers* in the prompt.
6. **Verify in a real browser.** Use the `browse` skill (or run a local server) to load the built site, screenshot it, check the console for errors. Fix obvious breakage before the QA gate.
7. **QA gate — dispatch a QA agent to compare BUILD vs ORIGINAL vs PROMPT (do not skip).** This is the step that catches "I spent 30 minutes and the build came out blank." Spin up a dedicated QA subagent that:
   - **Loads the built site AND the original side by side** (screenshot both at the same viewport, top→bottom, for every page in scope).
   - **Confirms every section/page from the prompt is actually present and rendered** — not just in the code, but visible. A `<canvas>` that renders blank, a section that's `opacity:0` and never animates in, a missing page → all FAIL.
   - **Checks the signature visuals specifically:** WebGL/canvas effects (e.g. a dithered/point-cloud render), hero animation, scroll behavior, fonts, colors, layout proportions. Compare the built render to the original's real appearance — if the original shows a vivid red halftone cat and the build shows a dark blank canvas, that is a FAIL to report, not "done."
   - **Verifies scope:** what was built == what the user asked for (Step 1.5). No page missing, nothing extra invented.
   - **Returns a pass/fail report** listing each mismatch with a screenshot. **Fix and re-run QA until it passes, or until the remaining gaps are explicitly surfaced to the user and accepted.** Never report "built ✓" while QA shows a blank/empty/missing section.

**Fidelity carries into the build:** an approximation in the generated site must be called out to the user, exactly like an `[inspect:]` marker in the prompt. **A build is "done" only after the QA agent passes or its open gaps are explicitly accepted by the user** — never on your own say-so.

---

## Fidelity Rules (Non-Negotiable)

Every color → hex value. Never "dark blue", "light gray", "off-white".
Every font size → exact value (px, rem, vw, or clamp()).
Every animation → delay + duration + easing + initial state + final state.
Every image → full URL from the actual site. Never a placeholder or invented path.
Every copy → exact words from the site. Never paraphrase or rewrite.
Every responsive rule → explicit per breakpoint, not "scales down".
Every section → its rendered height as a fraction of the viewport. A scroll-linked animation's *feel* depends on it: copy the formula AND the proportion, or the motion comes out wrong.

**NEVER FABRICATE.** If you cannot confirm a value from source code, network requests, or page source — write `[inspect: <what to look for>]`. Do not guess, invent, or estimate. This applies to:
- Award/date data that isn't in the source
- Card-to-image mappings you can't confirm in the DOM
- Feature list items you're unsure about
- Exact copy you can't read from the page
- Font names when only a fallback stack is visible

It is better to have 10 `[inspect: ...]` markers than one fabricated value. The next agent will know exactly what to verify.

---

## Animation Reference

| Name | Description | Required fields |
|---|---|---|
| FadeIn | Element fades + slides into view | opacity range, y/x offset, delay, duration, easing, trigger |
| Marquee | Row scrolls horizontally continuously | direction, speed/scrollY formula, item count, gap, row count |
| CharacterReveal | Text reveals per character on scroll | opacity range, scroll offset start/end, chars per segment |
| StickyStack | Cards stack + scale down as you scroll | sticky top value, scale formula, container height, card count |
| Magnetic | Element follows cursor within radius | padding radius, strength, active transition, inactive transition |
| ParallaxRow | Row moves opposite to scroll direction | translateX formula, direction (left/right), multiplier |
| ScaleOnScroll | Element grows/shrinks with scroll | scale range, scroll range, anchor element |
| ScrollReveal | Element enters viewport once | trigger margin, amount visible before trigger, once flag |

---

## Common Mistakes

- Writing "dark background" instead of `#0C0C0C`
- Writing "fades in" instead of `opacity 0→1, y: 40px→0, delay 0.3s, duration 0.7s`
- Using placeholder image paths instead of actual CDN URLs from the site
- Paraphrasing copy instead of using exact words
- Skipping mobile breakpoints
- Assuming React when the site might be plain HTML/CSS
- Missing the scroll formula for scroll-driven animations
- Forgetting box-shadow and outline details on buttons
- Missing border-radius values on images and cards
- Using `WebFetch` (which summarizes) instead of `curl` for raw source
- Stopping at the main JS bundle when the real animation logic is in lazy-loaded chunks
- Trusting a blank headless screenshot over the source on a WebGL/scroll-driven site
- Copying an animation formula but not the section's rendered height — a too-tall section makes a scroll-linked transform crawl and look frozen (the #1 "the animation doesn't work" cause)
- Leaving colors/font-sizes as `var()` tokens instead of resolving the computed px/hex from the live DOM
- Reproducing a hand-placed editorial grid (explicit per-item `grid-row`/`grid-column`) as generic auto-flow `span N` — the scattered positions never line up
- Treating a nested `<span><span>` as decorative when the inner element masks or animates independently
- Debugging one section at a time and shipping, instead of dumping every section's computed layout up front and fixing them all in one pass
- Giant display type that overflows its (often short) section bleeding into and overlapping adjacent sections. The original may use `overflow:visible` and rely on background/colour to mask the bleed (e.g. black letters over a dark neighbour); if your neighbour can't mask it, clip the section (`overflow:hidden`) — the in-section parallax still works. Always check title height vs section height (a title taller than its section WILL overflow).
- Shipping native scroll when the original uses a smooth-scroll library (Lenis, Locomotive). The inertial easing defines the entire feel of a scroll-driven site — transitions read as deliberate "wait for the scroll" instead of abrupt jumps. Reproduce it: intercept `wheel`, accumulate a target, lerp the real scroll toward it each RAF (ease ~0.1), and gate on `prefers-reduced-motion`. Also match section heights to the original (in px/vh) so the scroll *runway* between sections matches — too-short sections make transitions arrive too fast.
- Parsing only the entry/home page and implying full-site coverage — confirm scope (Step 1.5) and parse every page the user picked, or state plainly which pages you skipped
- Declaring the build "done" without the QA agent comparing it against the original — the #1 way a blank canvas / missing WebGL / empty section ships unnoticed after a long parse
- In the Build Phase: substituting placeholder assets, or silently approximating instead of flagging it
- In the Build Phase: skipping the side-by-side check of computed values (height/font/color) against the original before declaring it done

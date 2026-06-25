---
name: site-to-prompt
description: Use when given a website URL and asked to reverse-engineer it — to produce a detailed reconstruction prompt and/or rebuild the site in HTML/CSS or React/Tailwind. Covers animated, scroll-driven, and WebGL sites.
---

# site-to-prompt

## Overview
Visit a live website, analyze it completely from its real source, and produce a reconstruction prompt — covering fonts, colors, animations, sections, components, assets, and responsive rules — that enables another agent to rebuild the site from scratch without ever visiting the original. Optionally, hand the prompt to a builder and generate the site (see Build Phase).

The full flow: **URL → analyze → reconstruction prompt → (optional) build the site.**

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

For large files, fan out: dispatch parallel subagents to read the local CSS, HTML, and JS — one each — and report exact values. Keeps your context clean and is faster.

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

---

## Output Format

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

1. **Confirm target stack and scope.** Default to a single static `index.html` + CSS + a JS module unless the user specifies React/Tailwind/Next. Ask once if unclear; otherwise pick the stack named in the prompt's first line.
2. **Resolve `[inspect: …]` markers before building.** Each marker is a known gap. For each one, either fetch the missing source (re-run Step 1/3.5 on the specific file), or make an explicit, labeled approximation — never silently invent.
3. **Build section by section, in document order**, following the prompt as the spec. Reuse the exact tokens (colors, fonts, spacing vars), exact copy, and the documented animation values. Recreate the CSS-variable + scroll-progress driver pattern rather than hardcoding transforms.
4. **Assets:** reference the original CDN/media URLs from the prompt directly, OR download them locally if the user wants a self-contained build. Don't substitute stock placeholders.
5. **Reproduce, don't import blindly.** If the original uses GSAP/Lenis/Three.js, you may use the same libs, or reimplement the documented behavior with `IntersectionObserver` + `requestAnimationFrame` + CSS. Match the *behavior and numbers* in the prompt.
6. **Verify in a real browser.** Use the `browse` skill (or run a local server) to load the built site, screenshot it, check the console for errors, and compare against the original's screenshots/source. Fix and re-verify. Report what matches and what's approximated.

**Fidelity carries into the build:** an approximation in the generated site must be called out to the user, exactly like an `[inspect:]` marker in the prompt.

---

## Fidelity Rules (Non-Negotiable)

Every color → hex value. Never "dark blue", "light gray", "off-white".
Every font size → exact value (px, rem, vw, or clamp()).
Every animation → delay + duration + easing + initial state + final state.
Every image → full URL from the actual site. Never a placeholder or invented path.
Every copy → exact words from the site. Never paraphrase or rewrite.
Every responsive rule → explicit per breakpoint, not "scales down".

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
- In the Build Phase: substituting placeholder assets, or silently approximating instead of flagging it

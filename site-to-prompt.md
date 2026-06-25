---
name: site-to-prompt
description: Use when given an animated website URL and tasked with generating a detailed reconstruction prompt that another agent can use to build the site in HTML/CSS or React/Tailwind.
---

# site-to-prompt

## Overview
Visit a live website, analyze it completely, and produce a reconstruction prompt — covering fonts, colors, animations, sections, components, assets, and responsive rules — that enables another agent to rebuild the site from scratch without ever visiting the original.

## Analysis Workflow

### Step 1: Capture the Site
- Use browser/screenshot tools to render the page at full resolution
- Take screenshots at scroll positions: top, 25%, 50%, 75%, and bottom of page
- Inspect `<head>` for: font imports (Google Fonts, Adobe, custom), CSS links, `<title>`, meta tags
- Scan network requests for asset URLs: images, GIFs, videos, WebGL assets, CDN resources
- Read page source for: class names, inline styles, data attributes, animation libraries

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
- If you can't find the animation code, write `[inspect: check JS bundle for scroll animation logic]`

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

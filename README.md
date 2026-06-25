# site-to-prompt

A skill for AI agents that analyzes a live animated website and generates a detailed reconstruction prompt — enabling another agent to rebuild the site from scratch.

## What it does

Give an agent a URL. It visits the site, analyzes everything, and outputs a structured prompt covering:

- Tech stack and fonts
- Global styles and CSS variables
- Every section top to bottom (layout, copy, colors, images, animations)
- Reusable components with exact CSS
- All asset URLs (images, GIFs, videos, CDN resources)
- Animation timing (delay, duration, easing, initial → final state)
- Responsive breakpoints

The output prompt is detailed enough that a second agent can build the site in React/Tailwind or plain HTML/CSS without ever visiting the original.

## Skill file

[`site-to-prompt.md`](./site-to-prompt.md) — drop this into your Claude Code skills directory or any agent runtime that supports skill files.

## How to use

1. Copy `site-to-prompt.md` into your skills directory
2. Give your agent a URL and tell it to use the `site-to-prompt` skill
3. The agent outputs a reconstruction prompt
4. Pass that prompt to a second agent to build the site

## Tested on

- Portfolio sites with scroll-driven animations (GSAP, Lenis)
- Editorial landing pages with canvas/WebGL (Stripe Press)
- SaaS landing pages with video sections and sticky scroll (save.design)

## Output format

```
Build a [type] [site] for "[Name]" using [tech stack]. [One sentence]. The page title is "[Title]".

GLOBAL STYLES
...

SECTION ORDER
...

1. [SECTION NAME]
...

REUSABLE COMPONENTS
...

KEY DEPENDENCIES
...

RESPONSIVE BREAKPOINTS
...
```

## Fidelity standard

Every value in the output must be confirmed from page source or network requests — never guessed. Unverifiable values are marked `[inspect: what to look for]` so the next agent knows exactly what to check.

# site-to-prompt

A skill for AI agents that analyzes a live animated website and generates a detailed reconstruction prompt — enabling another agent to rebuild the site from scratch.

## Why use it

You found a landing page you love and want your agent to mimic some of its sections. Or you saw one specific animation on a site and want to implement that exact effect in your own project.

site-to-prompt parses the whole page — every section, layout, and animation (timing, easing, initial → final state) — and writes it all up as a structured prompt. Hand that prompt to your own agent, and it generates a page that captures what you liked.

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

## How it works (and what it costs)

To stay faithful, the skill reads the site's real CSS/HTML/JS source instead of guessing from a screenshot. Those bundles are large, so it **dispatches parallel subagents** — one to read the CSS, one the HTML, one the JS, plus a live-DOM measurement pass — each working in its own context and reporting back only the exact values.

That means **the more animations the page has, the more tokens it takes to run the skill.** A mostly-static page is cheap and quick. A scroll-driven, WebGL, or heavily animated site has far more to read and measure — individual subagents can run 40–60k+ tokens, and several run at once. **Depending on animation complexity, a full run can take 5–15 minutes or more.**

## Installation

Claude Code discovers each skill as a directory containing a `SKILL.md` file. Copy [`site-to-prompt.md`](./site-to-prompt.md) into a skill directory and rename it to `SKILL.md`.

**Personal install** (available in every project on your machine):

```bash
mkdir -p ~/.claude/skills/site-to-prompt
cp site-to-prompt.md ~/.claude/skills/site-to-prompt/SKILL.md
```

**Project install** (available only in the current repo):

```bash
mkdir -p .claude/skills/site-to-prompt
cp site-to-prompt.md .claude/skills/site-to-prompt/SKILL.md
```

Restart Claude Code (or start a new session) so it picks up the skill. It registers as `/site-to-prompt` from the `name:` field in the frontmatter.

> For other agent runtimes that support skill files, drop `site-to-prompt.md` wherever that runtime loads skills from.

## How to use

1. Install the skill (see above)
2. Run `/site-to-prompt <url>`, or give your agent a URL and tell it to use the `site-to-prompt` skill
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

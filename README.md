# site-to-prompt

A skill for AI agents that analyzes a live animated website and generates a detailed reconstruction prompt — enabling another agent to rebuild the site from scratch. Optionally, the same agent can go one step further and build the site for you directly from that prompt.

## Why use it

You found a landing page you love and want your agent to mimic some of its sections. Or you saw one specific animation on a site and want to implement that exact effect in your own project.

site-to-prompt parses the whole page — every section, layout, and animation (timing, easing, initial → final state) — and writes it all up as a structured prompt. Hand that prompt to your own agent, and it generates a page that captures what you liked.

## What it does

Give an agent a URL. It asks which pages you want (just this one, the whole site, or a specific page/section), analyzes everything, and outputs a structured prompt covering:

- Tech stack and fonts
- Global styles and CSS variables
- Every section top to bottom (layout, copy, colors, images, animations)
- Reusable components with exact CSS
- All asset URLs (images, GIFs, videos, CDN resources)
- Animation timing (delay, duration, easing, initial → final state)
- Responsive breakpoints

It writes one prompt per page in scope, then runs a QA pass that checks the prompt against the live source so nothing gets silently dropped. The output is detailed enough that a second agent can build the site in React/Tailwind or plain HTML/CSS without ever visiting the original.

## How it works (and what it costs)

To stay faithful, the skill reads the site's real CSS/HTML/JS source instead of guessing from a screenshot. Those bundles are large, so it **dispatches parallel subagents** — one to read the CSS, one the HTML, one the JS, plus a live-DOM measurement pass — each working in its own context and reporting back only the exact values.

That means **the more animations the page has, the more tokens it takes to run the skill.** A mostly-static page is cheap and quick. A scroll-driven, WebGL, or heavily animated site has far more to read and measure — individual subagents can run 40–60k+ tokens, and several run at once. **Depending on animation complexity, a full run can take 5–15 minutes or more — and that's per page**, so choosing "the whole site" multiplies the cost and time by the number of pages (which is why the skill asks you to pick a scope first).

## Installation

### Quickest — the `skills` CLI (one command)

```bash
npx skills add dhernz/site-to-prompt
```

One terminal command, no restart needed, and it works across Claude Code, Codex, and Cursor. The skill registers as `/site-to-prompt`.

### As a Claude Code plugin

This repo is also a Claude Code **plugin marketplace**, so you can install it natively (gives versioning + auto-update):

```text
/plugin marketplace add dhernz/site-to-prompt
/plugin install site-to-prompt
```

Then start a new session. The agent auto-loads the skill whenever a task matches its description.

### Manual install (copy the file)

The skill is a single self-contained file, so you can also just copy it in:

```bash
mkdir -p ~/.claude/skills/site-to-prompt
curl -sL https://raw.githubusercontent.com/dhernz/site-to-prompt/main/skills/site-to-prompt/SKILL.md \
  -o ~/.claude/skills/site-to-prompt/SKILL.md
```

Use `.claude/skills/...` instead of `~/.claude/skills/...` to install into the current project only. Restart Claude Code so it picks up the skill.

> For other agent runtimes that support skill files, drop [`skills/site-to-prompt/SKILL.md`](./skills/site-to-prompt/SKILL.md) wherever that runtime loads skills from.

## How to use

1. Install the skill (see above)
2. Run `/site-to-prompt <url>`, or give your agent a URL and tell it to use the `site-to-prompt` skill
3. **Pick your scope** — the agent lists the site's pages and asks whether you want just the entry page, the whole site, or a specific page/section
4. It analyzes each page in scope, QA-checks the parse, and saves the reconstruction prompt as a Markdown (`.md`) file (one per page) — then tells you the path

Then either:

- **Just want the prompt?** You're done — the `.md` file is yours to read, save, or feed to any agent later.
- **Want the site built?** Just ask the same agent to build it from that `.md` file (optional build phase). It builds every page in scope — section by section, with the documented animations — then runs a QA agent that screenshots the build against the original and reports any mismatch (blank canvas, missing section, etc.) instead of declaring it done. You can also hand the `.md` to a separate agent if you prefer.

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

## License

[GPL-3.0-or-later](./LICENSE). You may use, modify, and redistribute this skill under the terms of the GNU General Public License v3.0 or later.

#!/usr/bin/env bash
# Bump the version everywhere it lives, in one shot, so they never drift.
# Usage: bin/bump-version.sh X.Y.Z
set -euo pipefail

new="${1:-}"
case "$new" in
  [0-9]*.[0-9]*.[0-9]*) ;;
  *) echo "usage: bin/bump-version.sh X.Y.Z" >&2; exit 1 ;;
esac

root="$(cd "$(dirname "$0")/.." && pwd)"

# JSON manifests — each has exactly one "version" key.
for f in package.json .claude-plugin/plugin.json .claude-plugin/marketplace.json; do
  new="$new" perl -0pi -e 's/("version"\s*:\s*")[^"]+(")/$1.$ENV{new}.$2/e' "$root/$f"
done

# SKILL.md carries two version stamps (HTML comment + visible line).
sk="$root/skills/site-to-prompt/SKILL.md"
new="$new" perl -pi -e 's/(SKILL_VERSION:\s*)\d+\.\d+\.\d+/$1.$ENV{new}/e' "$sk"
new="$new" perl -pi -e 's/(\*\*Skill version:\*\*\s*`)\d+\.\d+\.\d+(`)/$1.$ENV{new}.$2/e' "$sk"

echo "Bumped to $new:"
grep -h '"version"' "$root/package.json" "$root/.claude-plugin/plugin.json" "$root/.claude-plugin/marketplace.json"
grep -n 'Skill version\|SKILL_VERSION' "$sk"
echo "Next: update CHANGELOG.md, commit, tag v$new, and 'gh release create'."

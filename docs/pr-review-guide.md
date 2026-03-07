# PR Review Guide — Team Reference

## Why We Review PRs

A PR review is a second pair of eyes before code merges into the main project. It catches convention violations before they become patterns, shares knowledge across the team, and keeps the codebase consistent.

## What a Good Review Looks Like

### Do
- Check against the stack conventions (zero npm, CDN-only, Montreal region, etc.)
- Test the change locally if it touches UI or routing
- Be specific: cite file, line number, and what should change
- Acknowledge good patterns — reinforcement matters
- Ask questions when intent is unclear rather than assuming

### Don't
- Nitpick formatting that doesn't affect readability
- Block on subjective style preferences
- Rewrite the PR in your review — suggest, don't dictate
- Rubber-stamp without actually reading the diff

## The Review Process

1. **Proposing Changes**: Developer works on a branch, opens a PR to merge into main
2. **The Review**: Reviewers check for bugs, readability, and convention adherence
3. **Feedback**: Reviewers respond with one of:
   - **Approve** — ready to merge
   - **Request Changes** — specific issues must be fixed first
   - **Comment** — general feedback without formal verdict

## Key Areas to Watch

1. **CDN compliance** — any npm/build tooling is an instant blocker
2. **Region compliance** — any GCP resource not in `northamerica-northeast1` is a blocker
3. **HTMX/Alpine boundary** — misuse of Alpine directives in HTMX-swapped content causes silent failures
4. **Template integrity** — f-string HTML fragments instead of Jinja partials cause drift
5. **Secret hygiene** — service account JSON, API secrets, `.env` files must never be committed

## Severity Levels

| Level | Meaning | Action |
|-------|---------|--------|
| **BLOCKER** | Breaks a golden rule, security issue, data loss risk | Must fix before merge |
| **WARNING** | Convention violation, potential bug, missing test | Should fix, discuss if disagreement |
| **NIT** | Style preference, minor improvement | Author's discretion |

## Using Claude Code for Reviews

Run `/review:pr-review` in Claude Code. It will:
1. Diff the branch against main
2. Check every changed file against the stack conventions
3. Produce a structured review with severity ratings
4. Highlight what was done well

The full automated checklist is in `.claude/commands/review/pr-review.md`. Use it as a reference or let Claude run it for you.

This is a starting point, not a substitute for human judgment. Use Claude's review to catch mechanical violations, then add your own insights about design, intent, and context.

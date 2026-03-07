# Claude Code Project Template

A ready-to-copy template folder for new projects using the FastAPI + HTMX + Alpine.js + Tailwind stack with Claude Code as the AI coding assistant.

## What's Inside

### CLAUDE.md (Auto-loaded)
Golden rules and conventions that Claude Code reads on every session start. Keeps every interaction aligned without loading the full references.

### Slash Commands (`.claude/commands/`)

Invocable skills that Claude Code loads on demand:

| Command | Purpose |
|---------|---------|
| `/core_skills:stack-conventions` | Full stack reference (CDN, FastAPI, HTMX, Alpine, Tailwind, LLM, GCP) |
| `/core_skills:agentic-loop` | AI agent iteration pattern |
| `/core_skills:firebase-auth` | Firebase auth implementation end-to-end |
| `/core_skills:ui-safety-nets` | HTMX/Alpine UI safety patterns |
| `/review:pr-review` | PR review checklist and process |

### Team Docs (`docs/`)
- `claude-code-operations.md` — How to use Claude Code (model switching, rate limits, session management)
- `pr-review-guide.md` — What good PR reviews look like for this team

## Usage

1. Copy this folder into your new project root
2. Claude Code auto-reads `CLAUDE.md` on startup
3. Use slash commands for deep-dive references as needed
4. Customize `CLAUDE.md` golden rules for your project's specific constraints

## Stack

FastAPI | Jinja2 | SQLite | HTMX | Alpine.js | Tailwind (CDN) | Firebase Auth | Ollama | Vertex AI | GCP Montreal

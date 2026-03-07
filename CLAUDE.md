# Project Conventions

## Stack
FastAPI (Python 3.12) + Jinja2 | HTMX 2.x | Alpine.js 3.x | Tailwind 3.x (all CDN)
SQLite + SQLAlchemy 2.0 | Firebase Auth (CDN JS SDK + Python Admin SDK)
Ollama (fast/cheap LLM) | Vertex AI Gemini 2.5 (hard problems) | GCP northamerica-northeast1

## Golden Rules — Violating These Is Always Wrong
1. **Zero npm. Zero build step.** All frontend libs via CDN `<script>` tags. No webpack, no vite, no node_modules.
2. **All GCP resources in `northamerica-northeast1` (Montreal).** PIPEDA/PHIPA data residency. Non-negotiable.
3. **Ollama for fast/cheap. Vertex AI for hard problems.** Route by capability, not sensitivity — both stay in Canada.
4. **No arbitrary Tailwind values** (`w-[347px]`). CDN build only — use the default palette.
5. **HTMX-swapped content: use `onclick`, not Alpine `@click`**, unless inside a pre-existing `x-data` scope.
6. **Inline updates return full Jinja2 template partials**, never f-string HTML fragments.
7. **Curl-test every new route** against the live dev server before considering work done.

## Architecture Patterns
- Routes return partials for `HX-Request`, full pages for direct navigation
- Jinja → Alpine data transfer via JSON data islands, not attribute interpolation
- Modals use `<dialog class="ws-modal">` + `wsOpenModal(id)` — safety nets auto-apply
- Auth resolves to `user_id: int` before any service call — services never see auth objects
- LLM calls go through `llm_service.py`, never directly to Ollama/Vertex

## Slash Commands — Deep-Dive References
Load these when you need detailed implementation guidance:
- `/core_skills:stack-conventions` — Full stack reference (CDN, FastAPI, HTMX, Alpine, Tailwind, LLM, GCP, auth, security)
- `/core_skills:agentic-loop` — AI agent iteration pattern (retrieve → score → gap-detect → synthesize)
- `/core_skills:firebase-auth` — Firebase auth end-to-end (JS SDK, Admin SDK, session cookies, RBAC, dev mode)
- `/core_skills:ui-safety-nets` — HTMX/Alpine UI safety patterns (modals, collapse, orphan watchdog)
- `/review:pr-review` — PR review checklist and process

## File Conventions
- Templates: `templates/base.html` owns all CDN script tags. Page-specific libs at bottom of individual pages.
- Config: `settings.py` with `BaseSettings`, env prefix per project, Pydantic validation.
- Storage: file bytes in filesystem/GCS, never in SQLite. Metadata in SQLite.
- Credentials: ADC / env vars only. Never hardcoded. Never committed.

## start.sh — Every Project Gets One
When creating a new FastAPI app, always generate a `start.sh` at the project root with:
- **argparse-style flags**: `--port`, `--host`, `--dev` (dev mode), `--no-reload`, etc.
- **Auto port finding**: if the requested port is busy, scan upward until a free one is found
- **Hot reload on by default**: uses `uvicorn --reload` in dev mode
- **Venv activation**: auto-activates `./venv` if it exists
- **Clear startup banner**: prints the URL, mode, and active flags so the user knows what's running
The user runs `bash start.sh` (or `./start.sh`) and the app just works. See `start.sh.template` for the reference implementation.

## Git Workflow
- Commit after each logical unit of work
- Run tests before committing if tests exist
- PR reviews follow the checklist in `/review:pr-review`

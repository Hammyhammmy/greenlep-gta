# PR Review Process

You are reviewing a pull request. Follow this process step by step.

## Step 1: Understand the Change
- Read the PR title, description, and any linked issues
- Run `git diff main...HEAD` (or the appropriate base branch) to see all changes
- Identify: Is this a new feature, bug fix, refactor, or config change?
- List every file changed and categorize them (Python, template, JS, config, test)

## Step 2: Check Stack Compliance

For each changed file, verify against the project's golden rules.

### Python / FastAPI
- [ ] Routes return partials for `HX-Request`, full pages for direct navigation
- [ ] POST/PUT routes return Jinja2 template partials, not f-string HTML
- [ ] Auth dependency (`CurrentProvider` or equivalent) used on all authenticated routes
- [ ] Services receive `user_id: int`, never auth objects or request objects
- [ ] LLM calls route through the LLM service layer, never directly to Ollama/Vertex
- [ ] No hardcoded credentials, secrets, or API keys
- [ ] GCP resources specify `northamerica-northeast1`

### Frontend (HTML / Jinja2 / JS)
- [ ] No npm packages, no build tools, no node_modules references
- [ ] New JS libraries loaded from CDN with pinned version
- [ ] CDN libs added in `base.html` (global) or at bottom of specific page (page-specific)
- [ ] Tailwind classes from default CDN palette only — no arbitrary values like `w-[347px]`
- [ ] HTMX-swapped content uses `onclick`, not Alpine `@click` (unless in existing `x-data` scope)
- [ ] Jinja → Alpine data via JSON data islands, not attribute interpolation
- [ ] Modals use `<dialog class="ws-modal">` + `wsOpenModal(id)` pattern
- [ ] Collapse panels in HTMX content use `wsToggleCollapse()`, not Alpine `x-show`
- [ ] Loading indicators on async HTMX actions
- [ ] Toast feedback via `Alpine.store('toast')`, not `alert()`

### Database
- [ ] File bytes stored in filesystem/GCS, not in SQLite
- [ ] Indexes on columns used in WHERE clauses
- [ ] Migrations run against both dev + app databases if dual-DB pattern is used

### Security
- [ ] No committed secrets, API keys, or service account JSON
- [ ] Session cookies: `httponly=True`, `samesite="lax"`, `secure` based on environment
- [ ] Input validation on user-facing endpoints
- [ ] Firebase client config is fine to expose; service account credentials are not

## Step 3: Code Quality
- [ ] Functions are focused — single responsibility
- [ ] Error handling is explicit, not silently swallowed
- [ ] No duplicated logic that should be extracted
- [ ] Variable names are descriptive
- [ ] Comments explain "why", not "what"
- [ ] No over-engineering — solution matches the complexity of the problem

## Step 4: Testing
- [ ] New routes curl-tested against the live dev server
- [ ] Existing tests still pass (if tests exist)
- [ ] Edge cases considered: missing IDs, empty forms, no auth cookie, invalid input

## Step 5: Write Review Summary

Format your review as follows:

### Overview
One-sentence summary of what the PR does.

### Verdict: [APPROVE / REQUEST_CHANGES / COMMENT]

### Issues Found
For each issue:
- **File**: `path/to/file.py`, line N
- **Severity**: `BLOCKER` / `WARNING` / `NIT`
- **Issue**: What is wrong
- **Fix**: What should change

Severity definitions:
- **BLOCKER**: Breaks a golden rule, security issue, data loss risk — must fix before merge
- **WARNING**: Convention violation, potential bug, missing test — should fix
- **NIT**: Style preference, minor improvement — author's discretion

### What Looks Good
Note 1-2 things done well. Reinforcing good patterns matters.

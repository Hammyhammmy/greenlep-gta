# Stack Conventions — Portable Reference

This is the single, self-contained reference for the full stack. It covers every layer
from CDN libraries to GCP deployment. Designed to be dropped into any new project that
uses this stack. No external doc references required.

---

## The Stack at a Glance

```
Backend      FastAPI (Python 3.12)  +  Jinja2 templates  +  SQLite (SQLAlchemy 2.0)
Interaction  HTMX 2.x (CDN)          — server-driven partials, no client-side routing
Reactivity   Alpine.js 3.x (CDN)     — lightweight client-side state, no framework
Styling      Tailwind CSS 3.x (CDN)  — utility classes, no PostCSS, no purge step
Auth         Firebase Auth (CDN JS SDK + Python Admin SDK)  — when auth is needed
Infra        GCP northamerica-northeast1 (Montréal)  — PIPEDA/PHIPA data residency
Storage      SQLite (dual-DB: main + audit), local filesystem dev, GCS prod
LLM (fast)   Ollama  — cheap, local, instant, good for routine inference
LLM (hard)   Vertex AI (Gemini 2.5) + Instructor  — heavy reasoning, structured output
```

### Golden Rules

1. **Zero npm. Zero build step.** All frontend libs via CDN `<script>` tags. No webpack,
   no vite, no node_modules, no package.json.
2. **All GCP resources in `northamerica-northeast1` (Montréal).** Non-negotiable.
   This includes Vertex AI, Cloud Run, GCS, Cloud SQL, Firebase — everything.
3. **Simple data → JSON files in folders. Relational data → SQLite.**
4. **Ollama for fast/cheap. Vertex AI for hard problems.** The choice is about
   capability and cost, not about data sensitivity — both stay in Canada.

---

## 1. CDN Library Management

All frontend libraries loaded in `templates/base.html`. No other file loads libraries.

```html
<!-- base.html — canonical CDN versions, pinned to major.minor.patch -->
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/tailwindcss@3.4.17/dist/tailwind.min.css">

<script src="https://unpkg.com/htmx.org@2.0.4/dist/htmx.min.js"></script>
<script src="https://unpkg.com/htmx-ext-sse@2.2.2/sse.js"></script>
<script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.14.9/dist/cdn.min.js"></script>

<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.8/dist/chart.umd.min.js"></script>
```

Page-specific libraries go at the bottom of the page that needs them, NOT in base.html:

```html
<!-- Only on schedule page -->
<script src="https://cdn.jsdelivr.net/npm/fullcalendar@6.1.15/index.global.min.js"></script>

<!-- Only on drag-and-drop pages -->
<script src="https://cdn.jsdelivr.net/npm/sortablejs@1.15.6/Sortable.min.js"></script>
```

### Rules

- Pin `major.minor.patch`. Never `@latest`, never bare `@3`.
- When updating a version, update base.html only — all pages inherit the change.
- If a library isn't on a CDN (jsdelivr, unpkg, cdnjs), find an alternative that is,
  or write the functionality in plain JS.
- **DO NOT** add npm, webpack, vite, rollup, esbuild, or any build tool.

---

## 2. Tailwind CSS (CDN)

Using the CDN build (`tailwind.min.css`) — the full Tailwind stylesheet. All utility
classes are available without a purge/JIT step. ~400KB, cached after first load.

### What Works

All core utilities: layout, spacing, typography, colour, flexbox, grid,
responsive prefixes (`sm:`, `md:`, `lg:`), state variants (`hover:`, `focus:`, `active:`).

### What Does NOT Work (no JIT compiler)

- `tailwind.config.js` custom config — no config file exists
- `@apply` directives — no PostCSS pipeline to process them
- Arbitrary values like `w-[347px]` or `bg-[#1a2b3c]` — these require JIT
- Custom theme extensions — use the default Tailwind palette only

### Standard Component Classes

```html
<!-- Card -->
<div class="bg-white border border-gray-200 rounded-lg shadow-sm p-4">

<!-- Primary button -->
<button class="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 text-sm font-medium">

<!-- Danger button -->
<button class="px-4 py-2 bg-red-600 text-white rounded hover:bg-red-700 text-sm font-medium">

<!-- Ghost button -->
<button class="px-4 py-2 border border-gray-300 text-gray-700 rounded hover:bg-gray-50 text-sm">

<!-- Form input -->
<input class="block w-full rounded border border-gray-300 px-3 py-2 text-sm
              focus:outline-none focus:ring-2 focus:ring-blue-500">

<!-- Table -->
<table class="min-w-full divide-y divide-gray-200 text-sm">
<thead class="bg-gray-50">
<th class="px-4 py-3 text-left font-medium text-gray-500 uppercase tracking-wider text-xs">

<!-- Alert banner -->
<div class="rounded-md bg-yellow-50 border border-yellow-200 p-3 text-sm text-yellow-800">
```

Desktop-first responsive. Use `md:` for tablet overrides, `sm:` sparingly.

---

## 3. FastAPI Conventions

### Dual-Response Routes (HTMX + Direct Nav)

Every route that serves UI must handle both HTMX partial requests and direct
browser navigation:

```python
from fastapi import APIRouter, Request
from fastapi.templating import Jinja2Templates

router = APIRouter()
templates = Jinja2Templates(directory="templates")

@router.get("/items/{item_id}/details")
async def item_details(item_id: int, request: Request):
    """Returns partial for HTMX, full page for direct nav."""
    item = await item_service.get(item_id)
    ctx = {"request": request, "item": item}

    if request.headers.get("HX-Request"):
        return templates.TemplateResponse("partials/item_detail.html", ctx)

    return templates.TemplateResponse("pages/item.html", {**ctx, "active_tab": "details"})
```

### HTMX Response Headers

Trigger client-side behaviour from the server without writing JavaScript:

```python
import json
from fastapi.responses import HTMLResponse

# Toast notification after an action
response = templates.TemplateResponse("partials/row_updated.html", ctx)
response.headers["HX-Trigger"] = json.dumps({"showToast": "Item saved"})
return response

# Full-page redirect (e.g., after login)
response = HTMLResponse("")
response.headers["HX-Redirect"] = "/dashboard"
return response

# Multiple triggers at once
response.headers["HX-Trigger"] = json.dumps({
    "refreshBadgeCount": True,
    "showToast": "Document filed"
})
```

### Error Responses to HTMX

Return HTML fragments, not JSON, so HTMX can swap them into the page:

```python
from fastapi.responses import HTMLResponse

@router.post("/items/{id}/save")
async def save_item(id: int, ...):
    try:
        item = await svc.save(...)
        return templates.TemplateResponse("partials/save_ok.html", ctx)
    except ValidationError as e:
        return HTMLResponse(
            f'<div class="text-red-600 text-sm p-2">{e.message}</div>',
            status_code=422
        )
```

Global HTMX error handler in base.html:
```javascript
document.body.addEventListener('htmx:responseError', function(evt) {
    if (evt.detail.xhr.status >= 500) {
        Alpine.store('toast').show('Server error — please try again', 'error');
    }
});
```

### App Setup

```python
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware

app = FastAPI()

app.mount("/static", StaticFiles(directory="frontend/static"), name="static")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"] if settings.dev_mode else [settings.app_url],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PATCH", "DELETE"],
    allow_headers=["*"],
)

if not settings.dev_mode:
    app.add_middleware(TrustedHostMiddleware, allowed_hosts=[settings.app_domain])
```

---

## 4. HTMX Patterns

These six patterns cover ~95% of HTMX use cases in this stack.

### Pattern 1: Tab Content Loading

```html
<div role="tablist">
  <button hx-get="/items/123/overview" hx-target="#tab-content" hx-push-url="true"
          class="tab">Overview</button>
  <button hx-get="/items/123/history" hx-target="#tab-content" hx-push-url="true"
          class="tab">History</button>
</div>
<div id="tab-content"><!-- HTMX swaps content here --></div>
```

FastAPI returns a bare HTML partial for `HX-Request`, or a full page that includes
the partial inline for direct browser navigation.

### Pattern 2: Live Search

```html
<input type="search" name="q" placeholder="Search..."
       hx-get="/search/items"
       hx-trigger="keyup changed delay:300ms"
       hx-target="#search-results"
       hx-indicator="#search-spinner">
<span id="search-spinner" class="htmx-indicator">Loading...</span>
<div id="search-results"></div>
```

### Pattern 3: Inline Actions (Acknowledge, Approve, Delete)

```html
<div id="item-42" class="list-item">
  <span>Item description</span>
  <button hx-post="/items/42/acknowledge"
          hx-target="#item-42"
          hx-swap="outerHTML swap:0.3s"
          hx-confirm="Acknowledge this item?">
    Acknowledge
  </button>
</div>
```

Endpoint returns a replacement element (e.g., a "Done" badge) or empty div. HTMX
swaps it in with a CSS transition.

### Pattern 4: Slide-Over Panel (Detail Without Leaving Page)

```html
<button hx-get="/items/42/detail"
        hx-target="#slide-panel-content"
        hx-swap="innerHTML"
        @click="slideOpen = true">
  Review
</button>

<div x-data="{ slideOpen: false }"
     x-show="slideOpen" x-transition
     @keydown.escape.window="slideOpen = false"
     class="fixed right-0 top-0 w-1/2 h-full bg-white shadow-xl z-50"
     id="slide-panel-content">
</div>
```

### Pattern 5: SSE for Real-Time Updates

```html
<div hx-ext="sse" sse-connect="/sse/updates" sse-swap="message">
  <!-- Server pushes HTML fragment updates here -->
</div>

<!-- Badge count that auto-refreshes -->
<span hx-ext="sse" sse-connect="/sse/inbox-count" sse-swap="message"
      id="inbox-badge">7</span>
```

```python
from sse_starlette.sse import EventSourceResponse

@router.get("/sse/inbox-count")
async def inbox_count_stream(request: Request):
    async def event_generator():
        while True:
            count = await inbox_service.get_pending_count(request.state.user_id)
            yield {"data": f'<span id="inbox-badge">{count}</span>'}
            await asyncio.sleep(30)
    return EventSourceResponse(event_generator())
```

### Pattern 6: Form with Auto-Save

```html
<form hx-post="/items/456/save"
      hx-trigger="keyup changed delay:5000ms, submit"
      hx-indicator="#save-status"
      hx-swap="none">
  <textarea name="content">...</textarea>
  <span id="save-status" class="htmx-indicator text-gray-400 text-xs">Saving...</span>
  <button type="submit">Save Now</button>
</form>
```

Auto-saves 5 seconds after last keystroke. Manual save button for immediate save.

### Loading Indicators

```html
<!-- Global progress bar (top of page, in base.html) -->
<div id="global-loading" class="fixed top-0 left-0 w-full h-1 bg-blue-600 htmx-indicator"></div>

<!-- Per-button spinner -->
<button hx-post="/items/42/action" hx-indicator="#spinner-42">
  Do Thing
  <span id="spinner-42" class="htmx-indicator ml-1 inline-block animate-spin">&#8635;</span>
</button>
```

In base.html:
```html
<style>
  .htmx-indicator { display: none; }
  .htmx-request .htmx-indicator { display: inline-block; }
  .htmx-request.htmx-indicator { display: block; }
</style>
```

---

## 5. Jinja2 Template Conventions

### The Non-Negotiable Rule

**Never interpolate Python/Jinja variables directly into Alpine.js attributes.**
Always use `<script type="application/json">` data islands.

```html
<!-- WRONG — quote collision, Jinja + JS + HTML in one attribute -->
<div x-data="editor({ id: {{ item.id }}, locked: {{ item.locked }} })">

<!-- CORRECT — Jinja writes clean JSON, Alpine reads it -->
<script type="application/json" id="editor-opts">
  {{ {"id": item.id, "locked": item.locked} | tojson }}
</script>
<div x-data="editor('editor-opts')">
```

### `tojson` Filter — Always for JS Consumption

```html
<script>
const chartData = {{ data | tojson }};     // CORRECT: properly escaped
const chartData = "{{ data }}";            // WRONG: never do this
</script>
```

### `| safe` Filter — Only for Trusted HTML

Disables autoescaping. Use ONLY for HTML you constructed server-side (e.g., rendered
markdown). Never on user input.

```html
{{ rendered_markdown | safe }}       <!-- OK if you generated it -->
{{ user_input | safe }}              <!-- XSS vulnerability -->
```

### Template Directory Structure

```
templates/
├── base.html                    # Full page skeleton: <html>, nav, CDN scripts
├── base_bare.html               # Minimal base for login/public pages
├── components/                  # Jinja {% include %} snippets (shared UI)
│   ├── nav.html
│   ├── modal.html
│   ├── slide_panel.html
│   ├── pagination.html
│   └── alert_banner.html
├── pages/                       # Full pages (extend base.html)
│   ├── dashboard.html
│   ├── item.html
│   ├── settings.html
│   └── login.html
└── partials/                    # HTMX fragments (NO <html>/<body>, NO base extension)
    ├── item/
    │   ├── detail_tab.html
    │   ├── history_tab.html
    │   └── edit_form.html
    ├── search/
    │   └── results.html
    └── settings/
        └── preferences.html
```

**Rules**:
- **Pages** extend `base.html`, include `<html>/<body>`.
- **Partials** are bare HTML fragments — no base extension. Returned for HTMX requests.
- **Components** are Jinja2 `{% include %}` snippets for shared UI (nav, modal, etc).
- Every route checks `HX-Request` header: HTMX → partial, direct nav → full page.

---

## 6. Alpine.js Conventions

### Registration: `Alpine.data()` for Anything with Methods

Never register components on `window`. Use `Alpine.data()`:

```html
<!-- SPA: ES module import, manual start -->
<script type="module">
  import Alpine from 'https://cdn.jsdelivr.net/npm/alpinejs@3.14.9/dist/module.esm.js';
  import { itemList } from './js/items.js';

  Alpine.data('itemList', () => itemList());
  Alpine.start();
</script>
<div x-data="itemList">
```

```html
<!-- Server templates: CDN auto-start, register via alpine:init -->
<script>
document.addEventListener('alpine:init', () => {
    Alpine.data('editor', (optsId) => ({
        itemId: null,
        locked: false,
        saving: false,

        init() {
            const el = document.getElementById(optsId);
            if (el) Object.assign(this, JSON.parse(el.textContent));
        },

        async save() { /* ... */ },
    }));
});
</script>
<div x-data="editor('editor-opts-{{ item.id }}')">
```

### JSON Data Islands (Jinja → Alpine)

Pass server data via `<script type="application/json">`, never via attribute interpolation:

```html
<script type="application/json" id="editor-opts-{{ item.id }}">
  {{ {"itemId": item.id, "locked": item.locked} | tojson }}
</script>
```

The component reads it in `init()` via `JSON.parse(el.textContent)`.

### `data-*` Attributes for Loop Variables

```html
<!-- WRONG — Jinja quote in Alpine attribute -->
{% for tab in tabs %}
  <button @click="activeTab = '{{ tab.id }}'">
{% endfor %}

<!-- CORRECT — Jinja writes data-*, Alpine reads $el.dataset -->
{% for tab in tabs %}
  <button @click="activeTab = $el.dataset.tab"
          data-tab="{{ tab.id }}">
{% endfor %}
```

### JSDoc Type Annotations (No TypeScript, No Build)

Add JSDoc to external `.js` files for IDE and AI assistance:

```javascript
// js/items.js

/**
 * @typedef {Object} SearchResult
 * @property {number} id
 * @property {string} name
 * @property {string|null} description
 */

/**
 * Alpine.js data component for the item list.
 * @returns {{
 *   results: SearchResult[],
 *   query: string,
 *   loading: boolean,
 *   search: () => Promise<void>,
 * }}
 */
function itemList() {
    return {
        /** @type {SearchResult[]} */
        results: [],
        query: '',
        loading: false,
        async search() { /* ... */ },
    };
}
```

Optional `jsconfig.json` at project root for VS Code checkJs:
```json
{
    "compilerOptions": { "checkJs": true, "strict": true, "target": "ES2020", "module": "ES2020" },
    "include": ["frontend/js/**/*.js"]
}
```

### Global Stores (base.html)

```html
<script>
document.addEventListener('alpine:init', () => {

    Alpine.store('toast', {
        message: '',
        type: 'info',
        visible: false,
        _timer: null,
        show(message, type = 'info') {
            this.message = message;
            this.type = type;
            this.visible = true;
            clearTimeout(this._timer);
            this._timer = setTimeout(() => { this.visible = false; }, 4000);
        }
    });

    Alpine.store('nav', {
        currentItemId: null,
        currentTab: null,
    });

});
</script>

<!-- Toast component (persistent in base.html) -->
<div x-data x-show="$store.toast.visible" x-transition
     :class="{
       'bg-green-50 border-green-400 text-green-800': $store.toast.type === 'success',
       'bg-red-50 border-red-400 text-red-800': $store.toast.type === 'error',
       'bg-blue-50 border-blue-400 text-blue-800': $store.toast.type === 'info',
       'bg-yellow-50 border-yellow-400 text-yellow-800': $store.toast.type === 'warning',
     }"
     class="fixed bottom-4 right-4 z-50 rounded-lg border p-3 text-sm shadow-md max-w-sm"
     x-text="$store.toast.message">
</div>

<!-- Wire HTMX HX-Trigger → Alpine toast.
     IMPORTANT: Use htmx:afterSwap, NOT document.body showToast listener.
     In HTMX 2.x, HX-Trigger events fire on the REQUESTING element.
     If that element was removed during the swap (e.g. a form inside its own
     hx-target), the event dispatches on a detached DOM node and never bubbles.
     htmx:afterSwap fires on the TARGET element which stays in the DOM. -->
<script>
document.addEventListener('htmx:afterSwap', function(evt) {
    var xhr = evt.detail.xhr;
    if (!xhr) return;
    try {
        var hdr = xhr.getResponseHeader('HX-Trigger');
        if (!hdr) return;
        var triggers = JSON.parse(hdr);
        if (triggers.showToast) {
            Alpine.store('toast').show(triggers.showToast, 'success');
        }
    } catch (_) { /* non-JSON trigger headers */ }
});
</script>
```

### What NOT to Migrate

Simple boolean/string state in `x-data` is fine as-is — no `Alpine.data()` needed:

```html
x-data="{ open: false }"
x-data="{ editing: false }"
x-data="{ view: 'table', uploadOpen: false }"
```

**Rule**: if `x-data` is a plain object literal with no functions, no Jinja interpolation,
and fits on one line — leave it alone.

### Alpine.js DO / DON'T

**DO**:
- `Alpine.data()` for components with methods or async logic
- JSON data islands for server → client data
- `data-*` attributes for Jinja loop variables in handlers
- `Alpine.store()` for cross-component state
- JSDoc on all component factory functions
- `$el.dataset` to read data attributes from within Alpine expressions

**DON'T**:
- Put `{{ }}` inside `x-data`, `@click`, `:class`, or any Alpine directive attribute
- Use double quotes for JS strings inside Alpine attributes (use single quotes)
- Register components on `window` — use `Alpine.data()`
- Write component functions longer than ~5 lines in HTML attributes
- Use `Alpine.data()` for simple `{ open: false }` state objects

### Command Registry Pattern (Data-Driven UI)

When a list of items appears in multiple UI surfaces (command palette, sidebar, nav),
define a **single Python registry** in `lightemr/config/` and inject it via
`_get_base_context()`. Templates consume it via JSON data islands or Jinja loops.

**Pattern**:
```python
# lightemr/config/command_registry.py
COMMAND_REGISTRY: list[dict] = [
    {
        "id": "nav-schedule",
        "label": "Schedule",
        "category": "Navigation",
        "icon": "📅",
        "keywords": "calendar book appt appointment booking agenda slots",
        "url": "/schedule",
    },
    ...
]

def get_command_registry() -> list[dict]:
    return COMMAND_REGISTRY
```

```python
# ui_shared.py — _get_base_context()
ctx["cmd_registry"] = get_command_registry()
```

```html
<!-- Template: JSON data island for JS consumption -->
<script type="application/json" id="cmd-registry">{{ cmd_registry | tojson }}</script>
<script>
  commands: JSON.parse(document.getElementById('cmd-registry').textContent),
</script>

<!-- Template: Jinja loop for server-rendered sidebar -->
{% for group_name, items in settings_groups %}
  {% for cmd in items %}
    <button>{{ cmd.icon }} {{ cmd.label }}</button>
  {% endfor %}
{% endfor %}
```

**Keyword synonyms**: Every registry entry should have a rich `keywords` string with
synonyms, abbreviations, and related terms a user might type. Think clinician vocabulary
— "rx" for prescriptions, "appt" for appointments, "req" for requisitions, "xray" for
imaging, etc. Aim for 8–12 terms per entry covering the feature name, common
abbreviations, related concepts, and alternate phrasing.

**Rules**:
- One Python file = one source of truth. Never duplicate entries in JS or templates.
- Use camelCase for keys that JS consumes directly (`requiresPatient`, `settingsGroup`).
- Items can have grouping metadata (e.g. `settingsGroup`) that only specific consumers use.
- Adding a new command = one dict in the registry. No JS edits, no template edits.

---

## 7. Dual LLM Architecture

Two backends, chosen by **task difficulty**, not by data sensitivity.
All LLM calls route through a central `llm_service.py` — never call Ollama or
Vertex AI directly from services or CLI.

### When to Use Which

| Use Case | Backend | Why |
|----------|---------|-----|
| Autocomplete / text expansion | Ollama | Fast, cheap, ~100ms latency |
| Simple summarisation | Ollama | Good enough, runs locally |
| Quick classification (yes/no, A/B/C) | Ollama | Doesn't need heavy reasoning |
| Draft short text from a template | Ollama | Fast iteration, local |
| Complex structured extraction from documents | **Vertex AI** | Needs strong reasoning + Instructor |
| Multi-step reasoning (differential dx, billing logic) | **Vertex AI** | Ollama too weak |
| Long-document analysis or synthesis | **Vertex AI** | Better context handling |
| Any task where Ollama output quality is insufficient | **Vertex AI** | Escalation path |

**Rule of thumb**: try Ollama first. If quality isn't good enough, escalate to Vertex AI.
Both backends stay in Canada (`northamerica-northeast1` for Vertex AI), so data
residency is satisfied either way.

### Ollama (Local)

Cheap, fast, runs offline, no cloud credentials needed. Good for routine inference
where "good enough" quality is fine:

```python
# llm/ollama_service.py
import httpx
from lightemr.config.settings import settings

def ollama_complete(prompt: str, model: str | None = None) -> str:
    """Call local Ollama. Returns raw text response."""
    model = model or settings.ollama_model
    r = httpx.post(
        f"{settings.ollama_base_url}/api/generate",
        json={"model": model, "prompt": prompt, "stream": False},
        timeout=60,
    )
    r.raise_for_status()
    return r.json()["response"]
```

### Vertex AI + Instructor (Cloud — Canada)

For hard problems. Uses the `instructor` library to get validated Pydantic models
back from Gemini. Never parse LLM output with string splitting or regex — define a
Pydantic response model and let Instructor enforce it.

```python
# llm/vertex_service.py
import instructor
import vertexai
from vertexai.generative_models import GenerativeModel
from pydantic import BaseModel
from config.settings import settings

vertexai.init(
    project=settings.gcp_project_id,
    location="northamerica-northeast1",   # NEVER change this region
)

_gemini = GenerativeModel("gemini-2.5-pro")
_client = instructor.from_vertexai(_gemini)


def structured_complete(
    prompt: str,
    response_model: type[BaseModel],
    max_retries: int = 2,
) -> BaseModel:
    """
    Call Gemini 2.5 via Vertex AI, return a validated Pydantic model.

    Args:
        prompt: The prompt string.
        response_model: Pydantic model class defining expected output shape.
        max_retries: How many times Instructor retries on validation failure.

    Returns:
        An instance of response_model, fully validated.
    """
    return _client.chat.completions.create(
        messages=[{"role": "user", "content": prompt}],
        response_model=response_model,
        max_retries=max_retries,
    )
```

### Structured Response Models

Define in `llm/schemas/`, one file per task domain:

```python
# llm/schemas/document_triage.py
from pydantic import BaseModel, Field
from enum import Enum

class DocumentType(str, Enum):
    REFERRAL = "referral"
    REPORT = "report"
    LETTER = "letter"
    FORM = "form"
    OTHER = "other"

class DocumentTriageResult(BaseModel):
    document_type: DocumentType
    confidence: float = Field(ge=0.0, le=1.0)
    summary: str = Field(max_length=300)
    urgency: str = Field(default="routine", description="routine | urgent | emergent")
```

### LLM Service Router

```python
# llm/llm_service.py
from enum import Enum

class LLMBackend(str, Enum):
    OLLAMA = "ollama"
    VERTEX = "vertex"

class LLMService:

    def complete(
        self,
        prompt: str,
        backend: LLMBackend = LLMBackend.OLLAMA,
        response_model: type | None = None,
    ):
        """Route to Ollama or Vertex AI."""
        if backend == LLMBackend.VERTEX:
            if response_model is None:
                raise ValueError("Vertex AI calls require a Pydantic response_model")
            return self._vertex_complete(prompt, response_model)
        return self._ollama_complete(prompt)

    def _vertex_complete(self, prompt, response_model):
        if not settings.gcp_project_id:
            raise LLMNotAvailableError("Vertex AI not configured.")
        from llm.vertex_service import structured_complete
        return structured_complete(prompt, response_model)

    def _ollama_complete(self, prompt):
        from llm.ollama_service import ollama_complete
        return ollama_complete(prompt)
```

### Graceful Degradation

Both backends are optional. The app runs without either:

```python
def is_vertex_available() -> bool:
    return bool(settings.gcp_project_id)

def is_ollama_available() -> bool:
    try:
        import httpx
        r = httpx.get(f"{settings.ollama_base_url}/api/tags", timeout=2)
        return r.status_code == 200
    except Exception:
        return False
```

Templates render "AI unavailable" state, never crash:

```html
{% if llm_available %}
  <button hx-post="/items/{{ item.id }}/summarise">Summarise with AI</button>
{% else %}
  <span class="text-gray-400 text-xs">AI offline</span>
{% endif %}
```

### Dependencies

```toml
# pyproject.toml
instructor = ">=1.3"
google-cloud-aiplatform = ">=1.50"   # includes vertexai
```

---

## 8. Auth: Firebase + Dev Bypass

### The `--dev` Flag Pattern

```bash
myapp --dev serve                    # dev mode: all requests = user_id=1, admin
myapp serve                          # production: Firebase JWT required
myapp --dev items search "query"     # CLI dev mode
```

`--dev` is a CLI flag, not an env var. Explicit every time you run a command.
No stale env vars, no accidental production deploys with auth off.

### Auth Provider Interface

```python
# auth/provider.py
from abc import ABC, abstractmethod
from dataclasses import dataclass

@dataclass
class AuthUser:
    user_id: int
    firebase_uid: str | None
    display_name: str
    email: str | None
    role: str
    permissions: dict

class AuthProvider(ABC):
    @abstractmethod
    async def authenticate(self, credential: str | None) -> AuthUser: ...

def get_auth_provider(dev_mode: bool, db) -> AuthProvider:
    if dev_mode:
        return DevAuthProvider(db)
    return FirebaseAuthProvider(db)
```

### Dev Provider

```python
class DevAuthProvider(AuthProvider):
    async def authenticate(self, credential=None) -> AuthUser:
        return AuthUser(
            user_id=1, firebase_uid=None,
            display_name="Dev Admin", email="dev@localhost",
            role="admin", permissions={"*": True}
        )
```

### Firebase Provider

```python
import firebase_admin
from firebase_admin import auth as firebase_auth, credentials

class FirebaseAuthProvider(AuthProvider):
    def __init__(self, db):
        self.db = db
        if not firebase_admin._apps:
            firebase_admin.initialize_app(credentials.ApplicationDefault(), {
                "projectId": settings.firebase_project_id,
            })

    async def authenticate(self, token: str) -> AuthUser:
        decoded = firebase_auth.verify_id_token(token)
        firebase_uid = decoded['uid']
        provider = await self.db.get_provider_by_firebase_uid(firebase_uid)
        if not provider:
            raise PermissionError("Firebase user not linked to an app account.")
        permissions = await self.db.get_permissions(provider.id)
        return AuthUser(
            user_id=provider.id, firebase_uid=firebase_uid,
            display_name=provider.display_name, email=decoded.get('email'),
            role=provider.role, permissions=permissions,
        )
```

### FastAPI Auth Middleware

```python
from starlette.middleware.base import BaseHTTPMiddleware

class AuthMiddleware(BaseHTTPMiddleware):
    PUBLIC_ROUTES = {'/health', '/api/auth/login', '/api/auth/callback'}

    def __init__(self, app, auth_provider: AuthProvider):
        super().__init__(app)
        self.auth_provider = auth_provider

    async def dispatch(self, request, call_next):
        if request.url.path in self.PUBLIC_ROUTES or request.url.path.startswith('/static'):
            return await call_next(request)

        if isinstance(self.auth_provider, DevAuthProvider):
            user = await self.auth_provider.authenticate()
        else:
            auth_header = request.headers.get('Authorization', '')
            if not auth_header.startswith('Bearer '):
                raise HTTPException(401, "Missing Authorization header")
            user = await self.auth_provider.authenticate(auth_header[7:])

        request.state.user = user
        request.state.user_id = user.user_id
        return await call_next(request)
```

### Session Cookie After Firebase Login

```python
@router.post("/api/auth/session")
async def create_session(request: Request, response: Response):
    token = request.headers.get('Authorization', '')[7:]
    user = await firebase_provider.authenticate(token)
    session_id = secrets.token_urlsafe(32)
    await db.create_session(session_id, user.user_id)
    response.set_cookie(
        key="session_id", value=session_id,
        httponly=True, secure=True, samesite="lax", max_age=86400 * 7,
    )
    return {"status": "ok", "user": user.display_name}
```

### Firebase JS SDK (CDN — No npm)

```html
<script src="https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/10.12.2/firebase-auth-compat.js"></script>
<script>
firebase.initializeApp({
    apiKey: "{{ firebase_config.api_key }}",
    authDomain: "{{ firebase_config.auth_domain }}",
    projectId: "{{ firebase_config.project_id }}"
});

firebase.auth().onAuthStateChanged(async (user) => {
    if (user) {
        const token = await user.getIdToken();
        await fetch('/api/auth/session', {
            method: 'POST',
            headers: { 'Authorization': `Bearer ${token}` }
        });
        window.location.href = '/';
    }
});
</script>
```

The Firebase config object (apiKey, authDomain, projectId) is **not secret** — it
identifies the project but grants no privileges. Safe to embed in HTML.
The service account JSON key IS secret — never exposed to clients.

### The Key Architectural Rule

Services NEVER check auth. They receive a `user_id` parameter. Auth is resolved
before the service call — by the CLI (from AuthContext) or by the API middleware
(from Firebase JWT). The service doesn't know or care which mode you're in.

---

## 9. Configuration and Credentials

### Pydantic-Settings

```python
# config/settings.py
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    dev_mode: bool = False
    app_url: str = "http://localhost:8000"
    app_domain: str = "localhost"

    db_path: str = "data/main.db"
    audit_db_path: str = "data/audit.db"

    ollama_base_url: str = "http://localhost:11434"
    ollama_model: str = "llama3.1:8b"

    firebase_project_id: str = ""

    storage_backend: str = "local"          # "local" | "gcs"
    local_documents_dir: str = "data/documents"
    gcs_bucket_documents: str = ""

    gcp_project_id: str = ""
    gcs_region: str = "northamerica-northeast1"

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"

settings = Settings()
```

### .env File (gitignored)

```ini
DEV_MODE=true
APP_URL=http://localhost:8000
DB_PATH=data/main.db
AUDIT_DB_PATH=data/audit.db

OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=llama3.1:8b

FIREBASE_PROJECT_ID=my-project
GCP_PROJECT_ID=my-project
GCS_BUCKET_DOCUMENTS=my-bucket
STORAGE_BACKEND=local
```

### GCP Credentials

GCP client libraries (Firebase Admin SDK, `google-cloud-storage`, `vertexai`) use
**Application Default Credentials (ADC)**.

**Local dev** — point ADC at your service account JSON key:
```bash
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account.json"
# OR
gcloud auth application-default login
```

**Cloud Run** — credentials are automatic. Cloud Run attaches a service account and
GCP libraries discover it via ADC. No `GOOGLE_APPLICATION_CREDENTIALS` needed. Grant
the service account only the IAM roles it needs.

**Firebase emulator** for local auth testing (no npm):
```bash
curl -sL firebase.tools | bash
firebase emulators:start --only auth
export FIREBASE_AUTH_EMULATOR_HOST="localhost:9099"
```

### .gitignore

```
*-service-account.json
firebase-adminsdk-*.json
.env
data/main.db
data/audit.db
data/documents/
```

---

## 10. File Storage Philosophy

### Simple Data → JSON Files. Relational Data → SQLite.

**JSON files for**:
- Reference/lookup data (ICD codes, fee schedules, drug databases, province lists)
- Per-user config blobs (preferences, template exports)
- Feature flags, seed data for tests
- LLM prompt templates (as `.txt` or `.md` files)

```
data/reference/
├── codes.json
├── fee_schedule.json
└── drug_db.json
```

Loading pattern:
```python
import json
from pathlib import Path
from functools import lru_cache

@lru_cache(maxsize=None)
def load_reference(name: str) -> dict:
    path = Path("data/reference") / f"{name}.json"
    return json.loads(path.read_text())
```

**SQLite for**:
- All transactional/clinical/business data
- Audit trail (append-only, separate DB)
- Scheduling, billing, messaging
- Anything with relationships, foreign keys, or unbounded growth

**Never put in SQLite**:
- File bytes / blobs (use filesystem locally, GCS in production)
- Rarely-changing lookup tables you'd rather edit as a file
- LLM prompts or template text

### Document / File Storage

Never store file bytes in the database. Store metadata + a path string only.

```python
# Abstraction: swap backend without touching business logic
class StorageService:
    def write(self, key: str, data: bytes) -> str: ...    # returns file_path for DB
    def read(self, file_path: str) -> bytes: ...
    def delete(self, file_path: str) -> None: ...
    def get_signed_url(self, file_path: str, expires: int = 300) -> str: ...
```

- `LocalStorageService` → `pathlib` + `open()`, path like `data/documents/abc.pdf`
- `GCSStorageService` → `google-cloud-storage`, path like `gs://bucket/abc.pdf`

Factory selects based on `settings.storage_backend`.

**Serving files to browser**:
- Local dev: FastAPI `StreamingResponse(open(path, "rb"))`
- Production: GCS signed URL (15-min expiry) + `RedirectResponse(signed_url)`.
  Client downloads directly from GCS — keeps Cloud Run memory free.

---

## 11. GCP and PIPEDA/PHIPA Compliance

**Single rule: all GCP resources in `northamerica-northeast1` (Montréal).**

This satisfies PHIPA (Ontario) and PIPEDA (federal) requirements that data remain
in Canada. Never use `us-central1`, `us-east1`, or any non-Canadian region.

```python
GCP_REGION = "northamerica-northeast1"
```

Checklist for any new GCP resource:
- [ ] Cloud Run service: `northamerica-northeast1`
- [ ] **Vertex AI endpoint**: `northamerica-northeast1` (in `vertexai.init(location=...)`)
- [ ] Cloud SQL (if added): `northamerica-northeast1`
- [ ] GCS bucket: `northamerica-northeast1`
- [ ] Firebase project: verify data residency
- [ ] Cloud Logging: regional log buckets in `northamerica-northeast1`
- [ ] Any PubSub / Cloud Tasks: `northamerica-northeast1`

### Cloud Run + Litestream (SQLite in Production)

Cloud Run has an ephemeral filesystem. [Litestream](https://litestream.io/) continuously
replicates SQLite to a GCS bucket. On container startup, it restores from the latest
replica.

```yaml
# litestream.yml
dbs:
  - path: /app/data/main.db
    replicas:
      - type: gcs
        bucket: my-backups
        path: main.db
  - path: /app/data/audit.db
    replicas:
      - type: gcs
        bucket: my-backups
        path: audit.db
```

```dockerfile
FROM python:3.12-slim
ADD https://github.com/benbjohnson/litestream/releases/download/v0.3.13/litestream-v0.3.13-linux-amd64.tar.gz /tmp/
RUN tar -C /usr/local/bin -xzf /tmp/litestream-v0.3.13-linux-amd64.tar.gz
COPY . /app
WORKDIR /app
RUN pip install -r requirements.txt
COPY litestream.yml /etc/litestream.yml
CMD ["litestream", "replicate", "-exec", "uvicorn app.api.main:app --host 0.0.0.0 --port $PORT"]
```

**Critical**: set Cloud Run `maxScale: 1`. SQLite = single writer. For multi-instance
scaling, migrate to PostgreSQL (SQLAlchemy models work with zero code changes —
just swap the connection string and run Alembic migrations).

---

## 12. CSRF and Security Headers

### HTMX + CSRF

Session cookies use `SameSite=lax` (CSRF protection for navigational requests).
For POST/PATCH/DELETE, inject a CSRF token into all HTMX requests:

```html
<meta name="csrf-token" content="{{ csrf_token() }}">
<script>
document.addEventListener('htmx:configRequest', function(evt) {
    evt.detail.headers['X-CSRF-Token'] =
        document.querySelector('meta[name="csrf-token"]').content;
});
</script>
```

```python
from starlette_csrf import CSRFMiddleware
app.add_middleware(CSRFMiddleware, secret=settings.csrf_secret,
                   exempt_paths=["/api/auth/session"])
```

In `--dev` mode, CSRF can be disabled.

### Content Security Policy

Alpine.js needs `unsafe-eval` (expression evaluation). Tailwind CDN needs
`unsafe-inline` (style tag). Unavoidable with the CDN approach:

```python
CSP = (
    "default-src 'self'; "
    "script-src 'self' 'unsafe-eval' 'unsafe-inline' "
        "https://cdn.jsdelivr.net https://unpkg.com "
        "https://www.gstatic.com https://cdnjs.cloudflare.com; "
    "style-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net; "
    "font-src 'self' https://fonts.gstatic.com; "
    "img-src 'self' data: blob:; "
    "connect-src 'self' https://identitytoolkit.googleapis.com; "
    "frame-src 'none'; "
    "object-src 'none';"
)
```

---

## 13. UI Safety Nets (Modals, Panels, Collapse)

Infrastructure JS baked into `base_workspace.html` and `base.html` that prevents
stuck modals, orphaned dialogs, and stale panel content. These run automatically —
no per-component code needed.

### Available Global Functions

| Function | Purpose |
|----------|---------|
| `wsOpenModal(id)` | Open a `<dialog>` by ID. Resets body to spinner, restores maximize state, calls `showModal()`. Tracks open timestamp for watchdog. |
| `wsCloseModal(id)` | Close a specific dialog by ID (no-op if already closed). |
| `wsCloseAllModals()` | Nuclear option — close every open `<dialog class="ws-modal">`. |
| `wsToggleMaximize(dlg)` | Toggle modal between tier size and maximized. Persists to localStorage. |
| `wsToggleCollapse(triggerId, panelId)` | Toggle a panel's `hidden` class. Works on HTMX-swapped content (plain DOM, no Alpine). |

### Automatic Safety Behaviours

1. **Patient change guard** — `patientSelected` event → `wsCloseAllModals()`.
   Prevents showing stale data from a previous patient.

2. **Tab switch cleanup** — `htmx:beforeSwap` on `#ws-content` or `#tab-content` →
   `wsCloseAllModals()`. Modals from the old tab become orphaned; close them.

3. **Dialog orphan watchdog** — every 5 s, checks open dialogs. If a dialog body
   is completely empty AND it was opened more than 3 s ago → auto-close. Catches
   modals orphaned when HTMX replaces their triggering context.

4. **Backdrop click to close** — clicking the `::backdrop` (i.e. the `<dialog>` element
   itself, not its children) closes the modal.

5. **Escape key** — workspace: closes all open dialogs. Patient chart: closes
   the active ribbon slide-over tab.

6. **Alpine re-init on HTMX swap** — `htmx:afterSwap` and `htmx:afterSettle` both
   call `Alpine.initTree(target)` to activate `x-data` directives on swapped content.

### Building New Modals

Use `<dialog class="ws-modal">` and `wsOpenModal(id)`. The safety nets handle the rest:

```html
<!-- In base_workspace.html (alongside other modal shells) -->
<dialog id="modal-myfeature" class="ws-modal ws-modal-t2">
  <div class="ws-modal-header">
    <span>My Feature</span>
    <button onclick="document.getElementById('modal-myfeature').close()">×</button>
  </div>
  <div id="modal-myfeature-body"><!-- HTMX fills this --></div>
</dialog>

<!-- Trigger button -->
<button onclick="wsOpenModal('modal-myfeature')"
        hx-get="/my-feature/content"
        hx-target="#modal-myfeature-body"
        hx-swap="innerHTML">
  Open Feature
</button>
```

**What you get for free**: backdrop close, Escape close, patient-change auto-close,
tab-switch auto-close, orphan detection if HTMX load fails.

### Building Collapse Panels

For panels in HTMX-swapped content, use `wsToggleCollapse` (plain DOM) instead of
Alpine `x-show` (which requires `x-data` scope):

```html
<button id="trigger-details" onclick="wsToggleCollapse('trigger-details', 'panel-details')"
        aria-expanded="false">
  Toggle Details
</button>
<div id="panel-details" class="hidden">
  Panel content here
</div>
```

For panels inside an existing `x-data` scope (not HTMX-swapped), Alpine `x-show` is fine.

### The HTMX + Alpine Gotcha

**Never use Alpine directives (`@click`, `@mousedown`) on elements inside HTMX-swapped
content** unless they land inside a pre-existing `x-data` scope that was present before
the swap. Alpine doesn't auto-initialize directives on dynamically injected content
outside a component boundary.

Use plain `onclick` / `onmousedown` instead, accessing Alpine state via:
```javascript
onclick="Alpine.$data(this.closest('[x-data]')).myMethod()"
```

Or for passing data from `x-for` loops:
```html
<button onmousedown="event.preventDefault();
  var c = Alpine.$data(this.closest('[x-data]'));
  c.insertExpansion(JSON.parse(this.dataset.qt))"
  :data-qt="JSON.stringify(qt)">
```

### Custom Events: Always Use kebab-case

**Alpine `@event-name.window` listens for the EXACT string `event-name`.** HTML attribute
names are lowercased by the browser, so `@slotPicked` becomes `@slotpicked` in the DOM —
which is neither camelCase nor kebab-case. Always use kebab-case for custom events:

```javascript
// WRONG — Alpine @slot-picked.window will NEVER catch this
window.dispatchEvent(new CustomEvent('slotPicked', { detail: { ... } }));

// RIGHT — matches Alpine @slot-picked.window exactly
window.dispatchEvent(new CustomEvent('slot-picked', { detail: { ... } }));
```

```html
<!-- Alpine listener — kebab-case -->
<div @slot-picked.window="handleSlotPicked($event.detail)">
```

### HX-Trigger Toast: Use htmx:afterSwap, NOT body Event Listener

When a form targets its own container (e.g. `hx-target="#ws-content"` where the form lives
inside `#ws-content`), the form is **removed from the DOM** during the swap. HTMX 2.x
dispatches HX-Trigger events on the requesting element — if that element is detached, the
events never bubble. The `document.body.addEventListener('showToast', ...)` pattern silently
fails.

**Use `htmx:afterSwap` instead** — it fires on the TARGET element (which stays in the DOM)
and you can read the `HX-Trigger` header directly from the XHR:

```javascript
document.addEventListener('htmx:afterSwap', function(evt) {
    var xhr = evt.detail.xhr;
    if (!xhr) return;
    try {
        var hdr = xhr.getResponseHeader('HX-Trigger');
        if (!hdr) return;
        var triggers = JSON.parse(hdr);
        if (triggers.showToast) {
            Alpine.store('toast').show(triggers.showToast, 'success');
        }
    } catch (_) {}
});
```

### Programmatic Form Submission

When auto-submitting an HTMX form from JavaScript (e.g. after a slot picker selection),
use `form.requestSubmit()` — NOT `htmx.trigger(form, 'submit')`. The native method
reliably fires HTMX's submit handler:

```javascript
@slot-picked.window="
  bookDate = $event.detail.date;
  bookTime = $event.detail.time;
  $nextTick(() => {
    let f = $el.querySelector('form[hx-post]');
    if (f) f.requestSubmit();
  });
"
```

### Dual Header / Dual Nav

LightEMR has **two separate header bars** with their own avatar dropdown menus:

1. **`templates/components/nav.html`** — used by `base.html` (Schedule, Reports, Settings, etc.)
2. **Inline header in `templates/base_workspace.html`** (line ~366) — used only by the Workspace

Any fix to the nav (e.g. dropdown visibility, new links, overflow styling) must be applied
to **both** headers. They share no template code.

**Overflow-hidden gotcha**: Never put `overflow-hidden` on a header/nav bar that contains
absolute-positioned dropdown menus. The dropdown renders inside the header's stacking context
and gets clipped to invisibility. Use `overflow-visible` (or omit the overflow class entirely).

### Dual Tab Registries

Patient chart features appear in **two independent lists**:

1. **`templates/components/patient_tabs.html`** — standalone patient page tabs (+ "More" dropdown)
2. **`templates/partials/workspace/tab_chart.html`** — workspace Virtual Chart sidebar (`chart_sections` list)

When adding a new patient feature (e.g. Pharmacology, AI Scribe), register it in **both**
tab lists or it will be invisible in one context.

### Dual Database Sync

Alembic defaults to `data/tenants/dev/lightemr.db`. The app at runtime uses
`data/lightemr.db` (via `LIGHTEMR_DATABASE_URL`). After creating a migration:

```bash
# 1. Upgrade the dev DB (alembic default)
python -m alembic upgrade head

# 2. Upgrade the app DB
LIGHTEMR_DATABASE_URL="sqlite:///data/lightemr.db" python -m alembic upgrade head
```

If you skip step 2, the UI will 500 with "no such table" errors even though tests pass
(tests use in-memory SQLite created from models, not migrations).

### Command Palette Completeness

The command palette (`templates/components/command_palette.html`) has a hardcoded JS command
registry. When adding a new admin page or patient feature, also add a command entry so it's
discoverable via `Cmd+K`. Categories: `Admin`, `Patient` (with `requiresPatient: true`),
`Navigation`.

---

## Quick Checklist

Before writing any frontend or infrastructure code:

- [ ] Route returning partial for `HX-Request`, full page for direct nav?
- [ ] Jinja variables going to Alpine via JSON data islands (not attribute interpolation)?
- [ ] Tailwind classes from CDN default palette only (no arbitrary values, no `@apply`)?
- [ ] New JS library loaded from CDN, pinned to version, in base.html or page-specific slot?
- [ ] `Alpine.store('toast')` for success/error feedback instead of `alert()`?
- [ ] HTMX loading indicators on async buttons?
- [ ] Modal using `<dialog class="ws-modal">` + `wsOpenModal(id)`? (safety nets auto-apply)
- [ ] Collapse panel using `wsToggleCollapse()` if in HTMX-swapped content?
- [ ] No Alpine directives (`@click`) on HTMX-swapped content outside `x-data` scope?
- [ ] Custom events dispatched in kebab-case to match Alpine `@event-name` listeners?
- [ ] Toast wired via `htmx:afterSwap` (not body event listener) if form is inside its own target?
- [ ] Programmatic form submit using `form.requestSubmit()` (not `htmx.trigger(f, 'submit')`)?
- [ ] LLM call going through `llm_service.py`, not directly to Ollama or Vertex AI?
- [ ] Using Ollama for fast/routine tasks, Vertex AI only for hard problems?
- [ ] Any GCP resource in `northamerica-northeast1`?
- [ ] Credentials via ADC / env var, never hardcoded, never committed?
- [ ] File bytes in filesystem/GCS, never in SQLite?

### Ribbon-as-Modal Pattern

The ribbon action bar buttons are quick-access overlays. They open the **same workspace
partial** inside a `<dialog>` modal. No duplicate templates, no duplicate Alpine components,
no duplicate route handlers.

**Rule**: Functionality lives in the workspace/patient tab partial. The modal route creates
any necessary records (e.g. draft encounter), then returns the same partial with
`is_modal=True` in context.

**How it works**:

1. Ribbon button calls `wsOpenModal('modal-xxx')` + HTMX GET to load modal body
2. Modal route creates the record if needed (e.g. draft encounter), gathers context
3. Route returns the **same** partial template used in the workspace tab, with `is_modal=True`
4. The partial detects `is_modal` to add Cancel button and close-on-sign behavior
5. After sign/save, the partial handles HTMX target detection via `_editorTarget()` pattern

**Current status**: Note editor consolidated. Rx, Requisition, Referral still need cleanup
(tracked in backlog).

| Ribbon Action | Status | Notes |
|---------------|--------|-------|
| **Note** | Consolidated | `note_editor.html` with `is_modal` flag |
| **Rx** | Needs cleanup | `rx_modal.html` + `new_rx_form.html` — two implementations |
| **Requisition** | Needs cleanup | `requisition_modal.html` + `new_req_form.html` — diverged |
| **Referral** | Nearly correct | `referral_modal.html` is a 4-line include wrapper |
| **Task** | Fine as-is | Modal-only, no ribbon equivalent |
| **Bill** | Fine as-is | Shared `billing_workstation.html` |
| **Prevention** | Fine as-is | Read-only modal summary |

### Inline Update Routes: Return Full Template, Not HTML Fragments

**Never return raw f-string HTML fragments from POST update routes.** Always re-render
the full Jinja2 template partial and swap the outer wrapper element.

**Why this matters**: Inline edit endpoints (e.g. "update one field without reloading the
page") are tempting to implement as f-string HTML responses targeting a small inner element.
This seems simpler but creates problems:

1. **The f-string response diverges from the template** — two sources of truth for the same
   UI. When the template changes, the f-string doesn't get updated (and vice versa).
2. **htmx.ajax() with `values:{}` is fragile** — it works, but any issue with element IDs,
   DOM nesting, or HTMX processing on swapped content causes silent failures.
3. **Alpine.js state breaks** — if the response lands inside an `x-data` scope, the new
   HTML doesn't participate in Alpine's reactivity unless explicitly re-initialized.
4. **Tests can't assert template structure** — f-string responses lack the wrapper div IDs,
   HTMX attributes, and template markers that tests expect.

**Correct pattern**:

```python
# WRONG — f-string HTML fragment, fragile, diverges from template
@router.post("/patient/{id}/hin-version")
async def update_hin_version(request, patient_id, db):
    patient.hin_version_code = vc
    db.commit()
    return HTMLResponse(f"""
      <span>{patient.hin} — {vc}</span>
      <button onclick="htmx.ajax(...)">OK</button>
    """)

# CORRECT — re-render the full template partial, swap outerHTML
@router.post("/patient/{id}/hin-version")
async def update_hin_version(request, patient_id, db):
    patient.hin_version_code = vc
    db.commit()
    db.refresh(patient)
    ctx = _get_base_context(request)
    ctx.update({"p": _patient_to_demo_dict(patient, ...), "patient_id": patient_id})
    return _templates.TemplateResponse(ctx["request"], "partials/patient/demographics_tab.html", ctx)
```

```html
<!-- Template wrapper needs a stable ID for outerHTML swap -->
<div id="demographics-panel" x-data="{ editing: false }" class="space-y-5">
  ...
  <!-- OK button targets the wrapper, not an inner cell -->
  <button onclick="htmx.ajax('POST', '/patient/{{ p.id }}/hin-version',
    {target:'#demographics-panel', swap:'outerHTML',
     values:{hin_version_code:document.getElementById('hin-vc-input').value}})">
    OK
  </button>
</div>
```

**Key rules**:
- Give the template's outermost element a stable `id` (e.g. `id="demographics-panel"`)
- POST route returns the same template the GET route uses — single source of truth
- `htmx.ajax()` targets that outer ID with `swap:'outerHTML'` (replaces the whole panel)
- Alpine `x-data` on the wrapper div gets re-initialized cleanly after the outerHTML swap
- This pattern works identically whether the partial is loaded standalone or inside the
  workspace via HTMX (no DOM context issues)

### Curl Testing — Mandatory After Building Routes

After creating or modifying any route handler + template, **curl-test it against the
live dev server** before considering the work done. This catches template rendering
errors, missing context variables, broken form actions, and wrong redirects that
unit tests miss (since tests use in-memory SQLite with fresh models, not the real
DB with migrations and seed data).

**Standard protocol:**

```bash
# 1. GET routes — verify 200 and key content renders
curl -s -o /dev/null -w "%{http_code}" http://localhost:8084/my-route
curl -s http://localhost:8084/my-route | grep "expected heading or element"

# 2. POST action routes — verify 302 redirect (not 405, not 500)
#    Do NOT use -L (follows redirect as POST → 405 on GET-only target)
curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:8084/my-route/action \
  -d "field1=value1&field2=value2"

# 3. Edge cases — non-existent IDs, missing fields, no auth cookie
curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:8084/my-route/99999/action
curl -s -X POST http://localhost:8084/my-route/action -d "" | grep "error\|required"

# 4. Multi-step flows — chain with cookies
curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:8084/step1 \
  -d "data=value" -c /tmp/cookies.txt
curl -s -o /dev/null -w "%{http_code}" http://localhost:8084/step2 \
  -b /tmp/cookies.txt
```

**What to verify:**
- GET pages return 200 (not 404, 500)
- POST actions return 302 (redirect) or 200 (re-render with success)
- Non-existent IDs don't crash (graceful 200/302, not 500)
- Missing/invalid form data shows friendly error messages (not Python tracebacks)
- Template variables all resolve (no `UndefinedError` in response)
- Links and form actions point to correct URLs (especially after URL pattern changes)
- Cookie-gated flows redirect to login/verify when cookie is missing

**When to skip:** Only for pure API/JSON endpoints that are already covered by pytest
route tests with the TestClient.

### New Feature Checklist

When adding a new patient chart feature or admin page:

- [ ] Registered in **both** tab lists (`patient_tabs.html` + `tab_chart.html` `chart_sections`)?
- [ ] Command palette entry added (`command_palette.html` JS registry)?
- [ ] Nav link added to **both** headers (`nav.html` + `base_workspace.html` avatar dropdown)?
- [ ] Migration run against **both** databases (dev + app)?
- [ ] No `overflow-hidden` on containers that hold dropdown menus?
- [ ] **Curl-tested** every new GET and POST route against the live dev server?

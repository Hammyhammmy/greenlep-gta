# UI Safety Nets — Portable Reference

Infrastructure JS baked into `base_workspace.html` and `base.html` that prevents
stuck modals, orphaned dialogs, and stale panel content. These run automatically —
**no per-component code needed**. When building any new modal, panel, or collapsible
section, follow these patterns and the safety nets handle edge cases for you.

---

## Why This Exists

HTMX dynamically swaps DOM content. Alpine.js only processes directives at page load
(or when `Alpine.initTree()` is called). This creates three categories of bugs:

1. **Stuck modals** — a `<dialog open>` whose close button was in content that got swapped away
2. **Stale data** — a modal showing Patient A's data after the user switched to Patient B
3. **Dead buttons** — Alpine `@click` directives on HTMX-injected content that never fire

The safety nets catch all three automatically.

---

## Global Functions (Always Available)

### `wsOpenModal(id)`

Opens a `<dialog>` by ID. Resets the body element (`#<id>-body`) to a spinner,
restores saved maximize state from localStorage, calls `showModal()`, and registers
the open timestamp so the orphan watchdog knows when it was opened.

```javascript
// Usage — always pair with an HTMX call to fill the body
wsOpenModal('modal-rx');
htmx.ajax('GET', '/workspace/modal/rx', {target: '#modal-rx-body', swap: 'innerHTML'});
```

### `wsCloseModal(id)`

Closes a specific dialog. No-op if already closed.

```javascript
wsCloseModal('modal-rx');
```

### `wsCloseAllModals()`

Nuclear option — closes every open `<dialog class="ws-modal">`.

```javascript
wsCloseAllModals();
```

### `wsToggleMaximize(dialogEl)`

Toggles a modal between its CSS tier size and maximized. Persists to localStorage.

### `wsToggleCollapse(triggerId, panelId)`

Toggles a panel's `hidden` class. Works on HTMX-swapped content because it uses
plain DOM manipulation, not Alpine directives.

```html
<button id="trigger-info" onclick="wsToggleCollapse('trigger-info', 'panel-info')"
        aria-expanded="false">
  Show Info
</button>
<div id="panel-info" class="hidden">
  Collapsible content
</div>
```

---

## Automatic Safety Behaviours

These are event listeners in `base_workspace.html` and `base.html`. They fire
without any per-component opt-in.

### 1. Patient Change Guard

**Trigger**: `patientSelected` custom event on `document.body`
**Action**: `wsCloseAllModals()`

When the user selects a different patient (day sheet click, search result click),
all open modals close immediately. This prevents showing Patient A's prescription
form after switching to Patient B.

### 2. Tab Switch Cleanup

**Trigger**: `htmx:beforeSwap` where target is `#ws-content` or `#tab-content`
**Action**: `wsCloseAllModals()`

When switching workspace tabs (daysheet → encounter → chart) or patient chart tabs,
modals from the old tab become orphaned. Close them before the swap.

### 3. Dialog Orphan Watchdog

**Trigger**: `setInterval` every 5 seconds
**Action**: Auto-close orphaned dialogs

Checks every open `<dialog class="ws-modal">`. If the dialog's body element
(`#<id>-body`) is completely empty AND the dialog was opened more than 3 seconds ago,
it's orphaned — close it.

The 3-second grace period prevents closing modals that are still loading via HTMX.

### 4. Backdrop Click to Close

**Trigger**: `click` on the `<dialog>` element itself (not its children)
**Action**: `dialog.close()`

Clicking outside the modal content (on the `::backdrop`) closes it.

### 5. Escape Key

- **Workspace** (`base_workspace.html`): closes all open dialogs
- **Patient chart** (`base.html`): closes the active ribbon slide-over tab

### 6. Alpine Re-init on HTMX Swap

**Trigger**: `htmx:afterSwap` and `htmx:afterSettle`
**Action**: `Alpine.initTree(evt.detail.target)`

Ensures `x-data`, `x-show`, `@click` directives in HTMX-loaded partials are
initialized. Without this, Alpine components in swapped content are inert.

### 7. Native Dialog Cancel Tracking

**Trigger**: Browser `cancel` event on `<dialog>` (fired when Escape is pressed)
**Action**: Cleans up internal open-timestamp tracking

---

## Patterns: How to Build New UI Components

### Pattern 1: New Modal (Workspace)

Add the dialog shell to `base_workspace.html` alongside the existing modals:

```html
<dialog id="modal-myfeature" class="ws-modal ws-modal-t2">
  <div class="flex items-center justify-between px-4 py-2.5 border-b bg-slate-800 text-white rounded-t-xl">
    <span class="text-sm font-semibold">My Feature</span>
    <button onclick="document.getElementById('modal-myfeature').close()"
            class="text-slate-400 hover:text-white transition text-lg leading-none">&times;</button>
  </div>
  <div id="modal-myfeature-body" class="p-4">
    <!-- HTMX fills this -->
  </div>
</dialog>
```

Trigger it:

```html
<button onclick="wsOpenModal('modal-myfeature')"
        hx-get="/workspace/modal/myfeature"
        hx-target="#modal-myfeature-body"
        hx-swap="innerHTML">
  Open My Feature
</button>
```

**What you get for free**: spinner on open, backdrop close, Escape close,
patient-change auto-close, tab-switch auto-close, orphan watchdog.

### Pattern 2: Collapse Panel in HTMX-Swapped Content

When the panel lands inside HTMX-swapped content (outside a pre-existing `x-data` scope),
use `wsToggleCollapse` instead of Alpine `x-show`:

```html
<button id="trigger-details-{{ item.id }}"
        onclick="wsToggleCollapse('trigger-details-{{ item.id }}', 'panel-details-{{ item.id }}')"
        aria-expanded="false"
        class="text-sm text-indigo-600 hover:text-indigo-800">
  Toggle Details
</button>
<div id="panel-details-{{ item.id }}" class="hidden mt-2 p-3 bg-slate-50 rounded-lg">
  {{ item.details }}
</div>
```

### Pattern 3: Collapse Panel Inside Existing x-data Scope

When the panel is inside a component that was present before the HTMX swap
(e.g., inside `x-data="noteEditor(...)"`), Alpine `x-show` works fine:

```html
<div x-data="{ showDetails: false }">
  <button @click="showDetails = !showDetails">Toggle</button>
  <div x-show="showDetails" x-transition>
    Details content
  </div>
</div>
```

### Pattern 4: Buttons in HTMX-Swapped Content

**Never use Alpine event directives** (`@click`, `@mousedown`, etc.) on elements
rendered by HTMX into a container unless that container is inside a pre-existing
`x-data` scope.

```html
<!-- WRONG — Alpine directive on HTMX-swapped content outside x-data scope -->
<button @click="doSomething()">Click me</button>

<!-- CORRECT — plain onclick, access Alpine state via $data -->
<button onclick="Alpine.$data(this.closest('[x-data]')).doSomething()">Click me</button>
```

For `x-for` loops where you need to pass the loop variable:

```html
<!-- WRONG — @mousedown on template-generated button in swapped content -->
<template x-for="item in items" :key="item.id">
  <button @mousedown.prevent="selectItem(item)">...</button>
</template>

<!-- CORRECT — serialize to data attribute, parse in onclick -->
<template x-for="item in items" :key="item.id">
  <button onmousedown="event.preventDefault();
    var c = Alpine.$data(this.closest('[x-data]'));
    c.selectItem(JSON.parse(this.dataset.item))"
    :data-item="JSON.stringify(item)">
    ...
  </button>
</template>
```

### Pattern 5: Modal with Forms

For modals that contain forms, the form's submit handler should close the modal
on success. Use `hx-on::after-request` for HTMX forms:

```html
<form hx-post="/myfeature/save"
      hx-target="#modal-myfeature-body"
      hx-swap="innerHTML"
      hx-on::after-request="if(event.detail.successful) document.getElementById('modal-myfeature').close()">
  <!-- form fields -->
  <button type="submit">Save</button>
  <button type="button" onclick="document.getElementById('modal-myfeature').close()">Cancel</button>
</form>
```

---

## Modal Size Tiers

CSS classes on the `<dialog>` element control size:

| Class | Typical Use | Approximate Size |
|-------|-------------|------------------|
| `ws-modal-t1` | Simple confirmation, phone note | Small |
| `ws-modal-t2` | Forms, editors | Medium |
| `ws-modal-t3` | Rich editors, billing, notes | Large |
| `ws-modal-doc` | Document viewer | Extra large |
| `ws-modal-maximized` | Fullscreen (toggle via maximize button) | Full viewport |

---

## Debugging Stuck UI

If a modal or panel appears stuck:

1. **Check the browser console** for JS errors — a crash in an Alpine component
   can prevent close handlers from running
2. **Run in console**: `wsCloseAllModals()` — nuclear reset
3. **Run in console**: `document.querySelectorAll('dialog[open]')` — see what's open
4. **Check if the element has a `-body` suffix sibling** — the orphan watchdog only
   checks dialogs whose body ID follows the `<id>-body` convention
5. **Check Alpine state**: `Alpine.$data(document.querySelector('[x-data]'))` — inspect
   component state for stuck booleans

---

## File Locations

| File | What It Contains |
|------|------------------|
| `templates/base_workspace.html` | `wsOpenModal`, `wsCloseModal`, `wsCloseAllModals`, `wsToggleMaximize`, patient change guard, tab switch cleanup, orphan watchdog, backdrop click, Alpine re-init, `wsToggleCollapse` |
| `templates/base.html` | Tab content swap cleanup, Alpine re-init, `wsToggleCollapse` (fallback definition) |

---

## Checklist for New UI Components

- [ ] Modal uses `<dialog class="ws-modal ws-modal-tN">` + `wsOpenModal(id)`?
- [ ] Modal body has `id="modal-<name>-body"` so the orphan watchdog can check it?
- [ ] Close button uses `onclick="document.getElementById('modal-<name>').close()"` (not Alpine `@click`)?
- [ ] Collapse panels in HTMX-swapped content use `wsToggleCollapse()` (not Alpine `x-show`)?
- [ ] Buttons in HTMX-swapped content use `onclick` (not Alpine `@click`)?
- [ ] Form success closes the modal via `hx-on::after-request` or JS callback?
- [ ] No Alpine directives on elements outside a pre-existing `x-data` scope?

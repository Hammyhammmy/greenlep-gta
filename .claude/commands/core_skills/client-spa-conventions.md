# Client SPA Conventions — Portable Reference

When the project is a **client-only** app (no FastAPI backend, no Jinja2 templates),
the server-rendered stack rules don't apply. Use Next.js or Vite instead.

---

## When to Use What

| Scenario | Tool | Why |
|----------|------|-----|
| Full app with backend + server rendering | **FastAPI + HTMX** | The default stack — no build step, CDN only |
| Client-only SPA, SSR/SSG needed, Vercel deploy | **Next.js** | File-based routing, React ecosystem, built-in SSR |
| Client-only SPA, lightweight, any framework | **Vite** | Fast dev server, framework-agnostic (React/Vue/Svelte) |
| Static marketing site or docs | **Vite** | Simplest option, fast builds |
| Dashboard / admin panel (no SEO needed) | **Vite** | Lighter than Next.js when SSR isn't required |

**Rule of thumb**: if you need a backend, use the FastAPI + HTMX stack. If it's
purely client-side, pick Next.js (for SSR/SSG) or Vite (for everything else).

---

## Next.js Conventions

### Project Setup
```bash
npx create-next-app@latest my-app --typescript --tailwind --eslint --app --src-dir
cd my-app
```

### Structure
```
src/
├── app/                    # App Router (file-based routing)
│   ├── layout.tsx          # Root layout — global providers, fonts, metadata
│   ├── page.tsx            # Home page
│   ├── feature/
│   │   ├── page.tsx        # /feature route
│   │   └── [id]/
│   │       └── page.tsx    # /feature/:id dynamic route
│   └── api/                # API routes (if needed)
│       └── route.ts
├── components/             # Shared UI components
│   ├── ui/                 # Primitives (Button, Input, Card)
│   └── features/           # Feature-specific composed components
├── lib/                    # Utilities, API clients, helpers
├── hooks/                  # Custom React hooks
└── types/                  # TypeScript type definitions
```

### Key Rules
1. **Use the App Router** (`src/app/`), not Pages Router
2. **Server Components by default** — only add `'use client'` when you need interactivity
3. **Data fetching in Server Components** — use `async` components, not `useEffect` + `useState`
4. **Tailwind for styling** — installed by create-next-app, use PostCSS (not CDN)
5. **TypeScript always** — no `.js` or `.jsx` files
6. **Environment variables**: `NEXT_PUBLIC_` prefix for client-side, plain for server-side

### start.sh for Next.js
```bash
#!/usr/bin/env bash
set -euo pipefail

PORT="${1:-3000}"

# Find free port
while lsof -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; do
    PORT=$((PORT + 1))
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Next.js Dev Server"
echo "  URL: http://localhost:${PORT}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

npx next dev --port "$PORT"
```

---

## Vite Conventions

### Project Setup
```bash
# React + TypeScript
npm create vite@latest my-app -- --template react-ts
cd my-app && npm install

# Vue + TypeScript
npm create vite@latest my-app -- --template vue-ts

# Svelte + TypeScript
npm create vite@latest my-app -- --template svelte-ts
```

### Structure (React example)
```
src/
├── main.tsx                # Entry point — mounts <App />
├── App.tsx                 # Root component, router setup
├── components/             # Shared UI components
│   ├── ui/                 # Primitives
│   └── features/           # Feature-specific
├── pages/                  # Route-level components (one per route)
├── hooks/                  # Custom React hooks
├── lib/                    # Utilities, API clients
├── types/                  # TypeScript types
└── assets/                 # Static files (images, fonts)
```

### Key Rules
1. **TypeScript always** — use the `-ts` template variant
2. **Tailwind via PostCSS** — `npm install -D tailwindcss @tailwindcss/vite`, configure in `vite.config.ts`
3. **Client-side routing**: React Router (`react-router-dom`), Vue Router, or SvelteKit
4. **Environment variables**: `VITE_` prefix for client-exposed vars
5. **No SSR unless explicitly needed** — keep it simple, use Vite as a pure SPA bundler

### start.sh for Vite
```bash
#!/usr/bin/env bash
set -euo pipefail

PORT="${1:-5173}"

# Find free port
while lsof -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; do
    PORT=$((PORT + 1))
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Vite Dev Server"
echo "  URL: http://localhost:${PORT}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

npx vite --port "$PORT"
```

---

## What Still Applies from the Main Stack

These rules carry over regardless of whether it's server-rendered or SPA:

| Rule | Still applies? | Notes |
|------|---------------|-------|
| GCP northamerica-northeast1 | **Yes** | If deploying to GCP. Vercel deployments are exempt. |
| Credentials never committed | **Yes** | Always |
| Tailwind for styling | **Yes** | But via PostCSS/build, not CDN |
| Firebase Auth | **Yes** | Use the Firebase JS SDK directly (no backend token exchange needed for client-only) |
| start.sh with auto port finding | **Yes** | Adapt for `next dev` or `vite` instead of `uvicorn` |
| Git workflow + PR reviews | **Yes** | Same process |

## What Does NOT Apply

| Rule | Why |
|------|-----|
| Zero npm / zero build step | SPA projects require a bundler — that's the whole point |
| CDN-only libraries | Dependencies managed via `package.json` |
| HTMX / Alpine.js patterns | Replaced by React/Vue/Svelte component model |
| Jinja2 templates | No server-side templating |
| `wsOpenModal` / safety nets | Use framework-native patterns (portals, state management) |

---

## Deployment

### Next.js
- **Vercel** (default): `vercel deploy` — zero config
- **GCP Cloud Run**: Dockerize with `next build && next start`, deploy to `northamerica-northeast1`
- **Static export**: `next build` with `output: 'export'` in `next.config.js` → deploy to GCS bucket

### Vite
- **Static hosting** (GCS, Vercel, Netlify): `npm run build` → deploy `dist/`
- **GCP Cloud Run**: Serve `dist/` with nginx or a lightweight static server
- **GCS bucket**: `gsutil -m cp -r dist/* gs://your-bucket/` in `northamerica-northeast1`

---

## Choosing Between Next.js and Vite — Decision Tree

```
Do you need server-side rendering (SEO, social previews)?
├── Yes → Next.js
└── No
    ├── Is it a large app with many routes and data fetching?
    │   ├── Yes → Next.js (App Router gives you layouts, loading states, error boundaries)
    │   └── No → Vite
    └── Do you want non-React (Vue, Svelte)?
        ├── Yes → Vite
        └── No → Either works, prefer Vite for simplicity
```

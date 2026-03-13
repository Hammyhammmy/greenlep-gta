# Medical Practice Website — Complete Build Guide

> **What this is:** A portable skill file that teaches a Claude Code agent how to build a professional medical specialist website from scratch, modeled on greenlep.ca. Load this when starting a new medical practice site project.

---

## 1. Architecture Overview

**Static HTML site.** No build step, no npm, no backend. Each page is a self-contained HTML file served via GitHub Pages or a simple HTTP server.

```
project-root/
├── index.html          # Main procedure/service landing page (longest, most detailed)
├── about.html          # Physician biography, credentials, teaching, community
├── urology.html        # Full practice scope (all services offered) — name for specialty
├── referrals.html      # How to refer patients (for referring physicians)
├── start.sh            # Local dev server (python3 -m http.server)
├── CNAME               # GitHub Pages custom domain
├── pic.jpg             # Professional headshot of the physician
├── bph-diagram.png     # Medical diagram (relevant to main procedure)
├── assets/processed/   # Clinical evidence summaries (markdown)
└── .gitignore
```

**Only dependency:** Tailwind CSS via CDN `<script>` tag. Zero JavaScript frameworks. Zero build tools.

---

## 2. Page-by-Page Structure

### index.html — Main Landing Page (Longest Page, ~650 Lines)

This is the centerpiece. It tells the full story of the primary procedure/service.

**Section order (follow this exactly):**
1. **Sticky navigation** — anchor links to sections within the page
2. **Hero header** — dark brand background, physician name, hospital, address, phone, referral note
3. **The Problem** — explain the condition in patient-friendly language with medical diagram
4. **What is [Procedure]?** — explain the procedure clearly
5. **Who Is This For?** — candidacy criteria as checklist
6. **Important Warning Callout** — honest medical caveat (e.g., bladder function limitations)
7. **Advantages** — 2x2 grid of benefit cards with icons
8. **Side-effect/Risk Notes** — gray info boxes for sexual function, comparison to alternatives
9. **What to Expect** — numbered timeline (consultation → surgery → first week → full recovery)
10. **Additional Considerations** — info boxes for blood thinners, large cases, overactive bladder
11. **Evidence Base** — collapsible `<details>` cards with study summaries and full abstracts
12. **Is This Right for You?** — softer CTA paragraph + priority callout
13. **How to Refer** — 2-column grid (physicians | patients)
14. **About the Doctor** — photo + bio summary with link to full about page
15. **Footer** — dark background, contact info

### about.html — Physician Bio (~115 Lines)

**Section order:**
1. Sticky nav (with "About" highlighted)
2. Dark brand sub-header bar
3. Photo + name + title + brief intro paragraph (side-by-side on desktop, stacked on mobile)
4. **Surgical Practice** — checklist of procedures
5. Gradient divider
6. **Teaching & Academic Work** — awards, positions
7. Gradient divider
8. **Innovation** — AI/tech involvement
9. Gradient divider
10. **Community** — languages spoken, neighborhoods served
11. Footer

### urology.html — Full Practice Scope (~148 Lines)

**Section order:**
1. Sticky nav (with "Practice" highlighted)
2. Dark brand sub-header bar + page header
3. Intro paragraph about full scope
4. **Primary Service** — highlighted in brand-colored box with link to main page
5. Gradient divider
6. **Service 2** (e.g., Kidney Surgery) — icon + heading, 2-column sub-cards
7. Gradient divider
8. **Service 3** (e.g., Prostate Cancer) — icon + heading, description
9. Gradient divider
10. **Service 4** (e.g., Bladder Tumours) — icon + heading, description
11. Gradient divider
12. **Referrals CTA** — centered gray box with fax/email/link
13. Footer

### referrals.html — Referral Instructions (~158 Lines)

**Section order:**
1. Sticky nav (with "Refer" highlighted)
2. Dark brand sub-header bar + page header
3. **Referral Methods** — 2-column grid (Fax preferred in brand box | Email in gray box)
4. Gradient divider
5. **What to Include** — checklist in striped rows (reason, PSA, imaging, medications, retention status)
6. Gradient divider
7. **Cases We Prioritize** — left-bordered callout cards with varying urgency colors
8. Gradient divider
9. **For Patients** — soft gray info box explaining they need a referral from their doctor
10. Footer

---

## 3. Tailwind Configuration & Brand Palette

Every page includes this identical `<head>` block:

```html
<script src="https://cdn.tailwindcss.com"></script>
<script>
  tailwind.config = {
    theme: {
      extend: {
        colors: {
          brand: {
            50: '#f0fdf4',
            100: '#dcfce7',
            200: '#bbf7d0',
            300: '#86efac',
            400: '#4ade80',
            600: '#16a34a',
            700: '#15803d',
            800: '#166534',
            900: '#14532d',
          }
        }
      }
    }
  }
</script>
```

**Color usage rules:**
| Token | Hex | Usage |
|-------|-----|-------|
| `brand-50` | `#f0fdf4` | Light background for brand-themed boxes |
| `brand-100` | `#dcfce7` | Rarely used directly |
| `brand-200` | `#bbf7d0` | Borders on brand boxes, gradient dividers, timeline connectors |
| `brand-300` | `#86efac` | Hover borders on cards |
| `brand-400` | `#4ade80` | Footer accent text, SVG decorative elements |
| `brand-600` | `#16a34a` | Icons (checkmarks, section icons), timeline circles |
| `brand-700` | `#15803d` | Active nav links, link text, important callout text |
| `brand-800` | `#166534` | Section headings, hero background, sub-header bar |
| `brand-900` | `#14532d` | Footer background |

**Neutral grays:**
- `gray-50` — neutral box backgrounds
- `gray-200` — borders on neutral elements
- `gray-400` — chevron icons in accordions
- `gray-500` — nav link default color, secondary/meta text
- `gray-600` — neutral icons, sub-card body text
- `gray-700` — body paragraph text
- `gray-800` — bold labels, strong text, card headings

**Alert colors (used sparingly):**
- `amber-50` + `amber-400` border — warning callouts (bladder function, risks)
- `amber-500` border — priority triage items (urgent referrals)

**Adapting the palette for other specialties:**
- Green = urology/surgical (current)
- Blue (`sky`/`blue`) = cardiology, internal medicine
- Purple (`violet`/`purple`) = oncology
- Teal (`teal`/`cyan`) = pediatrics
- Red/Rose (`rose`) = cardiothoracic, emergency

Keep the same shade structure (50 through 900). Only change the hue.

---

## 4. Typography

```css
html { scroll-behavior: smooth; }
body { font-family: Georgia, 'Times New Roman', serif; }
h1, h2, h3, h4, nav, .nav-link, .label-text, .stat-num {
  font-family: system-ui, -apple-system, sans-serif;
}
```

**Rules:**
- **Body text is serif** (Georgia). This gives a trustworthy, authoritative medical feel.
- **Headings, navigation, labels, and UI elements are sans-serif** (system-ui). Clean and modern.
- When an inline `<h3>` or label appears inside a card and doesn't inherit the sans font, add `style="font-family: system-ui, -apple-system, sans-serif;"` directly.
- Use `leading-relaxed` on all paragraph text for readability.
- Never use decorative or display fonts. Medical sites must feel serious and trustworthy.

**Size scale (mobile → desktop):**
| Element | Mobile | Desktop |
|---------|--------|---------|
| Hero H1 | `text-2xl` | `md:text-4xl` |
| Page H1 | `text-2xl` | `md:text-3xl` |
| Section H2 | `text-xl` | `md:text-2xl` |
| Card H3 | `text-base` | `md:text-lg` |
| Body paragraphs | `text-sm` | `md:text-base` |
| Nav links | `text-xs` | `md:text-sm` |
| Meta/citations | `text-xs` | `text-xs` |
| Footer | `text-sm` | `text-sm` |

---

## 5. Component Catalog

### 5.1 Sticky Navigation Bar

```html
<nav class="bg-white/95 backdrop-blur border-b border-gray-200 sticky top-0 z-50">
  <div class="max-w-4xl mx-auto px-3 md:px-4 py-2 md:py-3 flex flex-wrap items-center justify-between gap-1 md:gap-2">
    <a href="index.html" class="text-brand-700 font-bold text-base md:text-lg tracking-tight">Site Name</a>
    <div class="flex flex-wrap gap-x-3 md:gap-x-5 gap-y-0.5 text-xs md:text-sm text-gray-500">
      <a href="index.html" class="nav-link hover:text-brand-700 transition-colors">Main</a>
      <a href="about.html" class="nav-link text-brand-700 font-medium">About</a> <!-- active page -->
      <a href="urology.html" class="nav-link hover:text-brand-700 transition-colors">Practice</a>
      <a href="referrals.html" class="nav-link hover:text-brand-700 transition-colors">Refer</a>
    </div>
  </div>
</nav>
```

**Active page:** Replace `hover:text-brand-700 transition-colors` with `text-brand-700 font-medium`.

**On the index page**, nav links use `#anchor` references instead of page URLs, and a scroll-spy script highlights the active one.

### 5.2 Sub-Header Bar

Appears on inner pages (about, practice, referrals) below the nav:

```html
<div class="bg-brand-800 text-brand-200 text-xs py-1.5 text-center tracking-wide"
     style="font-family: system-ui, -apple-system, sans-serif;">
  Dr. Yan&rsquo;s Full Practice
</div>
```

### 5.3 Hero Header (Index Page Only)

Dark brand background with decorative SVG lines and a radial glow:

```html
<header id="top" class="bg-brand-800 text-white relative overflow-hidden">
  <!-- Decorative diagonal lines -->
  <svg class="absolute inset-0 w-full h-full opacity-10" preserveAspectRatio="none" viewBox="0 0 800 400">
    <line x1="0" y1="380" x2="800" y2="120" stroke="#4ade80" stroke-width="1.5"/>
    <line x1="0" y1="400" x2="800" y2="180" stroke="#4ade80" stroke-width="0.75"/>
    <line x1="0" y1="340" x2="800" y2="80" stroke="#4ade80" stroke-width="0.5"/>
    <line x1="200" y1="400" x2="800" y2="200" stroke="#86efac" stroke-width="0.5"/>
    <line x1="0" y1="300" x2="600" y2="0" stroke="#86efac" stroke-width="0.75"/>
  </svg>
  <!-- Radial glow in top-right -->
  <svg class="absolute right-0 top-0 w-96 h-96 opacity-15" viewBox="0 0 400 400">
    <radialGradient id="glow">
      <stop offset="0%" stop-color="#4ade80"/>
      <stop offset="100%" stop-color="#4ade80" stop-opacity="0"/>
    </radialGradient>
    <circle cx="300" cy="100" r="200" fill="url(#glow)"/>
  </svg>
  <div class="max-w-4xl mx-auto px-4 py-8 md:py-24 relative">
    <h1 class="text-2xl md:text-4xl font-bold tracking-tight mb-2 md:mb-3">Site Title</h1>
    <p class="text-brand-200 text-base md:text-xl mb-4 md:mb-6">Subtitle — Location</p>
    <div class="text-brand-100 space-y-0.5 md:space-y-1 text-xs md:text-base leading-relaxed">
      <p><strong class="text-white">Doctor Name</strong>&ensp;|&ensp;Hospital Name</p>
      <p>Address&ensp;|&ensp;<a href="tel:..." class="underline underline-offset-2 hover:text-white">Phone</a></p>
      <p>Referrals accepted via family physician (fax or email)</p>
    </div>
  </div>
</header>
```

### 5.4 Simple Page Header (Inner Pages)

```html
<header class="bg-brand-800 text-white">
  <div class="max-w-4xl mx-auto px-4 py-8 md:py-16">
    <h1 class="text-2xl md:text-3xl font-bold tracking-tight mb-2">Page Title</h1>
    <p class="text-brand-200 text-sm md:text-base">Subtitle description</p>
  </div>
</header>
```

### 5.5 Main Content Container

```html
<main class="max-w-3xl mx-auto px-4 py-8 md:py-16 space-y-8 md:space-y-16">
  <!-- sections go here -->
</main>
```

Note: Nav uses `max-w-4xl`, content uses `max-w-3xl` (slightly narrower for readability).

### 5.6 Section Heading with Icon

```html
<div class="flex items-center gap-3 mb-3 md:mb-4">
  <svg class="w-6 h-6 md:w-8 md:h-8 text-brand-600 shrink-0" viewBox="0 0 32 32"
       fill="none" stroke="currentColor" stroke-width="1.5"
       stroke-linecap="round" stroke-linejoin="round">
    <!-- icon paths -->
  </svg>
  <h2 class="text-xl md:text-2xl font-bold text-brand-800">Section Title</h2>
</div>
```

**Icon style:** All icons are hand-drawn SVG, `viewBox="0 0 32 32"` for section headers, `viewBox="0 0 24 24"` for card-level icons. Use `stroke` style (outline icons, no fill). Keep `stroke-width="1.5"`.

### 5.7 Gradient Section Divider

```html
<div class="flex items-center" aria-hidden="true">
  <div class="h-px flex-1 bg-gradient-to-r from-transparent via-brand-200 to-transparent"></div>
</div>
```

Use between every major section. Always include `aria-hidden="true"`.

### 5.8 Checkmark List

```html
<ul class="list-none space-y-2 md:space-y-3 mt-2">
  <li class="flex items-start gap-3">
    <svg class="w-5 h-5 text-brand-600 shrink-0 mt-0.5" viewBox="0 0 20 20" fill="currentColor">
      <path fill-rule="evenodd" d="M16.7 5.3a1 1 0 010 1.4l-8 8a1 1 0 01-1.4 0l-4-4a1 1 0 011.4-1.4L8 12.6l7.3-7.3a1 1 0 011.4 0z" clip-rule="evenodd"/>
    </svg>
    <span>List item text here</span>
  </li>
</ul>
```

### 5.9 Brand-Highlighted Box

```html
<div class="bg-brand-50 border border-brand-200 rounded-lg p-4 md:p-6 hover:border-brand-300 transition-colors">
  <h3 class="font-bold text-brand-800 mb-2">Title</h3>
  <p class="text-gray-700 text-sm md:text-base leading-relaxed">Content</p>
</div>
```

### 5.10 Neutral Info Box

```html
<div class="bg-gray-50 border border-gray-200 rounded-lg p-4 md:p-5">
  <div class="flex items-start gap-3">
    <svg class="w-5 h-5 text-gray-500 shrink-0 mt-0.5" viewBox="0 0 24 24"
         fill="none" stroke="currentColor" stroke-width="1.5"
         stroke-linecap="round" stroke-linejoin="round">
      <circle cx="12" cy="12" r="9"/>
      <path d="M12 8v4m0 4h.01"/>
    </svg>
    <div class="text-sm text-gray-700 leading-relaxed">
      <p><strong class="text-gray-800">Bold lead-in:</strong> Explanation text here.</p>
    </div>
  </div>
</div>
```

### 5.11 Warning/Alert Callout (Amber)

```html
<div class="bg-amber-50 border-l-4 border-amber-400 rounded-r-lg p-4 md:p-6">
  <div class="flex items-center gap-3 mb-2 md:mb-3">
    <svg class="w-6 h-6 text-amber-600 shrink-0" viewBox="0 0 24 24"
         fill="none" stroke="currentColor" stroke-width="1.5"
         stroke-linecap="round" stroke-linejoin="round">
      <path d="M12 9v4m0 4h.01M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z"/>
    </svg>
    <h3 class="text-base md:text-lg font-bold text-gray-800"
        style="font-family: system-ui, -apple-system, sans-serif;">Warning Title</h3>
  </div>
  <div class="space-y-2 md:space-y-3 text-gray-700 text-sm md:text-base leading-relaxed">
    <p>Warning content.</p>
    <p class="font-medium text-gray-800">Key takeaway in bold.</p>
  </div>
</div>
```

### 5.12 Priority/Urgency Callout (Left Border)

```html
<!-- High priority (brand green) -->
<div class="border-l-4 border-brand-600 bg-brand-50 rounded-r-lg p-4 md:p-5">
  <h3 class="font-bold text-brand-800 mb-1">Priority Title</h3>
  <p class="text-sm text-gray-700 leading-relaxed">Description.</p>
</div>

<!-- Medium priority (amber) -->
<div class="border-l-4 border-amber-500 bg-amber-50 rounded-r-lg p-4 md:p-5">
  <h3 class="font-bold text-gray-800 mb-1">Medium Title</h3>
  <p class="text-sm text-gray-700 leading-relaxed">Description.</p>
</div>

<!-- Lower priority (gray) -->
<div class="border-l-4 border-gray-300 bg-gray-50 rounded-r-lg p-4 md:p-5">
  <h3 class="font-bold text-gray-800 mb-1">Standard Title</h3>
  <p class="text-sm text-gray-700 leading-relaxed">Description.</p>
</div>
```

### 5.13 Two-Column Grid Cards

```html
<div class="grid md:grid-cols-2 gap-4 md:gap-6">
  <div class="border border-gray-200 rounded-lg p-4 md:p-6 hover:border-brand-300 transition-colors">
    <div class="flex items-center gap-3 mb-2 md:mb-3">
      <svg class="w-6 h-6 text-brand-600 shrink-0" ...><!-- icon --></svg>
      <h3 class="text-base md:text-lg font-bold text-gray-800">Card Title</h3>
    </div>
    <p class="text-gray-700 text-sm leading-relaxed">Card content.</p>
  </div>
  <!-- repeat for second card -->
</div>
```

For a full-width card in a 2-column grid, add `md:col-span-2`.

### 5.14 Numbered Timeline (What to Expect)

```html
<div class="space-y-0">
  <!-- Step 1 -->
  <div class="flex gap-4">
    <div class="flex flex-col items-center">
      <div class="w-8 h-8 rounded-full bg-brand-600 text-white flex items-center justify-center text-xs font-bold shrink-0">1</div>
      <div class="w-px flex-1 bg-brand-200"></div>
    </div>
    <div class="pb-6 md:pb-8">
      <h3 class="font-bold text-gray-800 mb-1" style="font-family: system-ui, -apple-system, sans-serif;">Step Title</h3>
      <p class="text-sm text-gray-700 leading-relaxed">Step description.</p>
    </div>
  </div>

  <!-- Last step (no connecting line) -->
  <div class="flex gap-4">
    <div class="flex flex-col items-center">
      <div class="w-8 h-8 rounded-full bg-brand-600 text-white flex items-center justify-center text-xs font-bold shrink-0">4</div>
    </div>
    <div class="pb-2">
      <h3 class="font-bold text-gray-800 mb-1" style="font-family: system-ui, -apple-system, sans-serif;">Final Step</h3>
      <p class="text-sm text-gray-700 leading-relaxed">Description.</p>
    </div>
  </div>
</div>
```

### 5.15 Collapsible Evidence/Accordion

```html
<details class="group border border-gray-200 rounded-lg">
  <summary class="p-3 md:p-5 cursor-pointer flex items-center justify-between hover:bg-gray-50 rounded-lg transition-colors">
    <div>
      <h3 class="text-sm md:text-base font-bold text-gray-800">Study Title</h3>
      <p class="text-xs text-gray-500 mt-0.5">Author et al., <em>Journal</em>, Year — Patient count, duration</p>
    </div>
    <svg class="w-5 h-5 text-gray-400 group-open:rotate-180 transition-transform shrink-0 ml-2" viewBox="0 0 20 20" fill="currentColor">
      <path fill-rule="evenodd" d="M5.3 7.3a1 1 0 011.4 0L10 10.6l3.3-3.3a1 1 0 011.4 1.4l-4 4a1 1 0 01-1.4 0l-4-4a1 1 0 010-1.4z" clip-rule="evenodd"/>
    </svg>
  </summary>
  <div class="px-3 md:px-5 pb-3 md:pb-5 space-y-3 text-gray-700 text-sm leading-relaxed border-t border-gray-100 pt-3 md:pt-4">
    <p>Plain-language summary of the study for patients and referring physicians.</p>

    <!-- Nested collapsible for full abstract -->
    <details class="mt-3 bg-gray-50 rounded p-3">
      <summary class="text-xs font-medium text-brand-700 cursor-pointer">View full abstract</summary>
      <div class="mt-2 text-xs text-gray-600 leading-relaxed space-y-2">
        <p><strong>Background:</strong> ...</p>
        <p><strong>Methods:</strong> ...</p>
        <p><strong>Results:</strong> ...</p>
        <p><strong>Conclusions:</strong> ...</p>
      </div>
    </details>
    <p class="text-xs text-gray-400 mt-2">Full citation here.</p>
  </div>
</details>
```

### 5.16 Striped Checklist (Referral Requirements)

```html
<div class="bg-gray-50 border border-gray-200 rounded-lg divide-y divide-gray-200">
  <div class="px-4 py-3 flex items-start gap-3">
    <svg class="w-5 h-5 text-brand-600 shrink-0 mt-0.5" viewBox="0 0 20 20" fill="currentColor">
      <path fill-rule="evenodd" d="M16.7 5.3a1 1 0 010 1.4l-8 8a1 1 0 01-1.4 0l-4-4a1 1 0 011.4-1.4L8 12.6l7.3-7.3a1 1 0 011.4 0z" clip-rule="evenodd"/>
    </svg>
    <span class="text-sm text-gray-700">Item text</span>
  </div>
  <!-- repeat rows -->
</div>
```

### 5.17 Doctor Bio Section (with Photo)

```html
<div class="flex flex-col md:flex-row gap-6 md:gap-10 items-start">
  <img src="pic.jpg" alt="Doctor Name"
       class="w-40 h-52 md:w-48 md:h-64 rounded-xl object-cover object-[center_20%] shrink-0 mx-auto md:mx-0"/>
  <div>
    <h1 class="text-2xl md:text-3xl font-bold text-brand-800 mb-2">Dr. Full Name</h1>
    <p class="text-gray-500 text-sm md:text-base mb-4">Title, Hospital&ensp;|&ensp;Academic Title, University</p>
    <p class="text-gray-700 text-sm md:text-base leading-relaxed">Bio paragraph.</p>
  </div>
</div>
```

**Photo styling:** Fixed aspect ratio with `object-cover` and `object-[center_20%]` to frame the face properly. Rounded corners with `rounded-xl`. The `object-[center_20%]` is the one allowed arbitrary value for image cropping.

### 5.18 Doorway Link (Cross-Page CTA)

```html
<a href="about.html" class="block border border-brand-200 bg-brand-50 rounded-lg p-4 md:p-5 hover:border-brand-400 hover:shadow-sm transition-all group">
  <div class="flex items-center justify-between gap-4">
    <div>
      <p class="text-sm md:text-base text-gray-700 leading-relaxed">Teaser text with <strong class="text-gray-800">bold keywords</strong>.</p>
      <p class="text-brand-700 font-medium text-sm mt-1">View full page</p>
    </div>
    <svg class="w-5 h-5 text-brand-600 shrink-0 group-hover:translate-x-0.5 transition-transform" viewBox="0 0 20 20" fill="currentColor">
      <path fill-rule="evenodd" d="M7.3 4.3a1 1 0 011.4 0l5 5a1 1 0 010 1.4l-5 5a1 1 0 01-1.4-1.4L11.6 10 7.3 5.7a1 1 0 010-1.4z" clip-rule="evenodd"/>
    </svg>
  </div>
</a>
```

### 5.19 Footer

```html
<footer class="bg-brand-900 text-brand-200">
  <div class="max-w-3xl mx-auto px-4 py-6 md:py-8 text-center text-sm">
    <p class="mb-2">Hospital Name&ensp;|&ensp;Address&ensp;|&ensp;<a href="tel:..." class="underline underline-offset-2 hover:text-white">Phone</a></p>
    <p class="text-brand-400">Fax: ...&ensp;|&ensp;<a href="mailto:..." class="underline underline-offset-2 hover:text-white">email@domain.com</a></p>
  </div>
</footer>
```

---

## 6. Content Writing Style

### Tone & Voice
- **Professional but accessible.** Write for an educated reader who is not a medical professional.
- **First-person plural sparingly** ("we prioritize"), second-person for patients ("your family physician").
- **Explain medical terms inline** on first use: "benign prostatic hyperplasia (BPH)" then "BPH" after.
- **Use analogies for anatomy:** "the tube that carries urine out of the body" for urethra.
- **Be honest about risks.** Never oversell. Include percentages when available: "less than 1% risk of stress incontinence", "approximately 10% chance of weaker erections", "at least 50% chance of retrograde ejaculation".
- **No marketing superlatives.** Never say "best", "revolutionary", "cutting-edge", "world-class". Let the evidence speak.
- **Active voice.** "Dr. Yan performs" not "procedures are performed by Dr. Yan".

### Content Structure Patterns
- **Problem → Solution → Evidence** is the macro pattern.
- Every clinical claim should reference or link to evidence.
- Use `<strong>` for key terms on first introduction, not for emphasis.
- Paragraphs are short: 2-4 sentences max.
- Use `&mdash;` (em dash), `&ensp;` (en space), `&rsquo;` (right single quote) and `&ndash;` (en dash for ranges) — never straight quotes or hyphens for these.

### HTML Entity Usage
- `&rsquo;` for apostrophes: `Dr. Yan&rsquo;s`
- `&mdash;` for em dashes: `GreenLEP &mdash; a minimally invasive procedure`
- `&ndash;` for ranges: `60&ndash;120 minutes`
- `&ensp;` for visual separation: `Hospital&ensp;|&ensp;Address`
- `&rarr;` for link arrows: `Full details &rarr;`
- `&ge;` / `&lt;` for comparisons in clinical text

### Image Best Practices
- Doctor headshots: professional, high-quality, cropped to head-and-shoulders.
- Medical diagrams: clear labels, simple colors, no stock photography of procedures.
- All images must have descriptive `alt` text that explains what the image shows for accessibility.
- Use `class="w-full max-w-xl mx-auto my-4 md:my-6 rounded-lg"` for inline images.

---

## 7. Responsive Design Rules

**Mobile-first.** Default styles target phones. Use `md:` prefix for tablet/desktop (768px+).

**Spacing scale:**
- Horizontal padding: `px-3 md:px-4` (nav), `px-4` (content — consistent)
- Section spacing: `space-y-8 md:space-y-16` (between major sections on index), `space-y-8 md:space-y-14` (inner pages)
- Paragraph spacing: `space-y-3 md:space-y-4`
- Card padding: `p-4 md:p-6`
- Grid gaps: `gap-4 md:gap-6`

**Layout shifts:**
- Doctor photo + bio: stacked on mobile (`flex-col`), side-by-side on desktop (`md:flex-row`)
- Grid cards: single column on mobile, `md:grid-cols-2` on desktop
- Nav links: wrapping flex, allowing 2 rows on small screens

**Never use:**
- Fixed pixel widths (except image dimensions)
- `lg:` or `xl:` breakpoints (keep it simple, only `md:`)
- Horizontal scrolling
- Arbitrary Tailwind values except `object-[center_20%]` for photo cropping

---

## 8. Interactions & JavaScript

**Minimal JavaScript.** This is a content site, not an app.

**Scroll-spy (index.html only):**
```javascript
(function() {
  var links = document.querySelectorAll('nav a.nav-link[href^="#"]');
  var sections = [];
  links.forEach(function(a) {
    var el = document.querySelector(a.getAttribute('href'));
    if (el) sections.push({ el: el, link: a });
  });
  if (!sections.length) return;
  function update() {
    var scrollY = window.scrollY + 120;
    var active = null;
    sections.forEach(function(s) {
      if (s.el.offsetTop <= scrollY) active = s;
    });
    links.forEach(function(a) {
      a.classList.remove('text-brand-700', 'font-medium');
    });
    if (active) {
      active.link.classList.add('text-brand-700', 'font-medium');
    }
  }
  window.addEventListener('scroll', update, { passive: true });
  update();
})();
```

Place at the bottom of `<body>`, after the footer. Only needed on the index page where nav uses `#anchor` links.

**CSS-only interactions:**
- `<details>` + `<summary>` for accordions (no JS needed)
- `group-open:rotate-180` on chevron icons to animate accordion open/close
- `hover:border-brand-300 transition-colors` on cards
- `group-hover:translate-x-0.5 transition-transform` on CTA arrows
- `hover:text-white` on footer links
- `smooth scroll` via CSS `html { scroll-behavior: smooth; }`

---

## 9. SEO & Meta

Each page needs:
```html
<title>Page Title — Doctor Name, Hospital, City</title>
<meta name="description" content="One-sentence summary with keywords. Doctor name, procedure, hospital, city.">
```

**Title formula:** `[Topic] — [Doctor Name], [Hospital], [City]`
**Description formula:** `[Procedure/Service] — [1-sentence explanation]. [Doctor Name], [Hospital], [City].`

---

## 10. Accessibility Checklist

- Semantic HTML: `<nav>`, `<header>`, `<main>`, `<footer>`, `<section>`
- Proper heading hierarchy: one `<h1>` per page, `<h2>` for sections, `<h3>` for sub-items
- Decorative elements: `aria-hidden="true"` on dividers and decorative SVGs
- Links: descriptive text, `underline underline-offset-2` for visibility
- Phone numbers: `<a href="tel:...">` for mobile tap-to-call
- Email: `<a href="mailto:...">`
- Images: descriptive `alt` text
- Color contrast: brand-700/800 on white passes WCAG AA

---

## 11. Deployment

### GitHub Pages
1. Push to `main` branch
2. Add `CNAME` file with custom domain
3. Configure DNS (A records or CNAME to GitHub Pages)

### Local Development
```bash
#!/usr/bin/env bash
PORT="${1:-8080}"
# Find free port
while lsof -i :"$PORT" >/dev/null 2>&1; do PORT=$((PORT + 1)); done
echo "Serving at http://127.0.0.1:$PORT"
python3 -m http.server "$PORT" --bind 127.0.0.1
```

---

## 12. Adapting for a Different Medical Specialty

To create a site for a different specialist (e.g., orthopedics, cardiology, dermatology):

1. **Change the brand color palette** — pick a hue that resonates with the specialty (see Section 3).
2. **Replace the 4-page structure content** but keep the same page roles:
   - `index.html` → primary procedure/service the doctor is known for
   - `about.html` → doctor bio (same structure works universally)
   - `[specialty].html` → full scope of practice
   - `referrals.html` → referral pathways (identical structure)
3. **Replace SVG section icons** — draw simple outline icons relevant to the specialty.
4. **Replace the hero SVG decoration** — keep the diagonal-line + radial-glow pattern, change colors to match new brand palette.
5. **Replace evidence section** — swap in relevant studies. Keep the same `<details>` accordion format.
6. **Keep all component patterns identical** — the visual system is specialty-agnostic.
7. **Update the warning/callout content** — every specialty has honest risk discussions. Use the same amber callout pattern.
8. **Contact info format stays the same** — fax, email, phone, address in footer. Referral methods on referrals page.

---

## 13. Anti-Patterns — What NOT to Do

1. **No stock photography.** Medical stock photos feel generic and erode trust.
2. **No testimonials or patient quotes.** Privacy and regulatory concerns.
3. **No "Book Now" buttons.** Specialist appointments require physician referral in Canada.
4. **No pricing.** Publicly funded healthcare — no price lists.
5. **No chatbots or live chat widgets.** Inappropriate for medical sites.
6. **No cookie banners.** Static site with no tracking = no cookies.
7. **No animations beyond subtle transitions.** This is not a marketing agency site.
8. **No hamburger menus.** Nav wraps naturally on mobile with flex-wrap.
9. **No JavaScript frameworks.** No React, Vue, Alpine, jQuery. Vanilla only when needed.
10. **No CSS frameworks beyond Tailwind CDN.** No Bootstrap, no custom CSS files.
11. **No arbitrary Tailwind values** like `w-[347px]` — use the default scale.
12. **No `<marquee>`, `<blink>`, auto-playing anything.** Obviously.

# Firebase Auth — Portable Reference

How LightEMR wires Firebase authentication end-to-end. Covers the dual dev/prod
design, frontend token exchange, session cookies, FastAPI dependency, RBAC, and
all the tricky parts that break silently if done wrong.

---

## The Core Design

Two modes, same code path after the cookie is set.

```
DEV MODE                          PRODUCTION (Firebase)
──────────────────────────────    ──────────────────────────────────────
No token needed                   Firebase ID token (JWT) required
Always user_id=1, role=admin      UID → providers.firebase_uid → user_id
Cookie: dev:{id}:1                Cookie: firebase:{id}:{user_id}
──────────────────────────────    ──────────────────────────────────────
               ↓                               ↓
        session_id cookie read on every request
        FastAPI dependency extracts user_id → loads Provider from DB
        RBAC checks permissions
        Service receives user_id — never knows which auth mode
```

**The invariant**: services never see auth. They receive `user_id: int`. Auth is
resolved before the service is called — either by the session cookie middleware or
by the `--dev` bypass. The service doesn't know which.

---

## 1. Frontend — Firebase JS SDK (no npm, CDN only)

Load Firebase compat SDK in `base.html`. No build step, no npm.

```html
<!-- Firebase compat SDK — compat build allows firebase.xxx() syntax -->
<script src="https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/10.7.0/firebase-auth-compat.js"></script>
```

### Login page pattern (`templates/pages/login.html`)

Firebase config is injected from the backend via Jinja2 — never hardcoded in
the template. Config is not secret (it's the client-side web config, not
the service account).

```html
<script>
// Config comes from backend via template context — not from an env var on the client
firebase.initializeApp({{ firebase_config | tojson }});

async function signInWithGoogle() {
  const provider = new firebase.auth.GoogleAuthProvider();
  try {
    const result = await firebase.auth().signInWithPopup(provider);
    const token = await result.user.getIdToken();
    // Exchange Firebase ID token for a session cookie
    const resp = await fetch('/api/auth/session', {
      method: 'POST',
      headers: { 'Authorization': 'Bearer ' + token }
    });
    if (resp.ok) {
      window.location.href = '/';
    } else {
      showError('Login failed — account not linked to a provider.');
    }
  } catch (e) {
    showError(e.message);
  }
}
</script>
```

### Dev mode login (no Firebase needed)

```html
<!-- In dev mode, show a simple button — no Firebase SDK needed -->
{% if dev_mode %}
<form method="post" action="/auth/dev-login">
  <button type="submit">Enter (Dev Mode)</button>
</form>
{% endif %}
```

### What NOT to do

- Do NOT use `onAuthStateChanged` for the token exchange. It fires on every page
  load and every token refresh, not just on sign-in. Use the popup result directly.
- Do NOT use the Firebase Modular SDK (v9 tree-shakeable) with CDN. It requires
  a bundler. Use the compat build (`firebase-app-compat.js`).
- Do NOT put `firebase_config` inline in the HTML. Inject it via Jinja2
  `{{ firebase_config | tojson }}` so the backend controls the values.

---

## 2. Backend — Session Endpoint

### `POST /api/auth/session`

Exchanges a Firebase ID token for a session cookie. This is the only endpoint
that touches Firebase. Everything else reads the cookie.

```python
@router.post("/api/auth/session")
async def create_session(request: Request, response: Response,
                         db: Session = Depends(get_db)) -> dict:
    auth_header = request.headers.get("Authorization", "")

    # Dev mode: no token, create admin session
    if not auth_header or request.headers.get("X-Dev-Mode") == "true":
        session_id = secrets.token_urlsafe(32)
        _set_session_cookie(response, f"dev:{session_id}:1")
        return {"status": "ok", "mode": "dev", "user_id": 1}

    # Production: validate Firebase token
    scheme, _, token = auth_header.partition(" ")
    if scheme.lower() != "bearer" or not token:
        raise HTTPException(status_code=401, detail="Missing Bearer token")

    try:
        firebase_provider = FirebaseAuthProvider(db)
        auth_user = await firebase_provider.authenticate(token)
    except PermissionError as e:
        raise HTTPException(status_code=401, detail=str(e))

    session_id = secrets.token_urlsafe(32)
    _set_session_cookie(response, f"firebase:{session_id}:{auth_user.user_id}")

    # Audit the login
    audit_svc.log(user_id=auth_user.user_id, action="login",
                  table_name="providers", record_id=auth_user.user_id)

    return {"status": "ok", "user_id": auth_user.user_id,
            "display_name": auth_user.display_name}


def _set_session_cookie(response: Response, value: str) -> None:
    response.set_cookie(
        key="session_id",
        value=value,
        httponly=True,        # prevent JS access
        secure=True,          # HTTPS only — set False for local dev if not using HTTPS
        samesite="lax",       # protects against CSRF
        max_age=86400 * 7,    # 7 days
    )
```

### Cookie format

```
dev:{random_token}:{user_id}         ← dev bypass
firebase:{random_token}:{user_id}    ← production
```

The `user_id` (internal `providers.id`) is the last segment. Parse with
`cookie.split(":")[-1]` — works for both modes without branching.

### `DELETE /api/auth/session` — Logout

```python
@router.delete("/api/auth/session")
async def logout(response: Response) -> dict:
    response.delete_cookie("session_id")
    return {"status": "ok"}
```

---

## 3. Firebase Admin SDK — Token Verification

```python
# lightemr/auth/firebase_provider.py

import firebase_admin
from firebase_admin import auth as firebase_auth

class FirebaseAuthProvider:
    """Validates Firebase ID tokens server-side. Uses Admin SDK."""

    def __init__(self, db=None):
        self.db = db
        # Lazy init — do this ONCE per process, not per request
        if not firebase_admin._apps:
            # On Cloud Run: auto-discovers default service account
            # Local dev: needs GOOGLE_APPLICATION_CREDENTIALS env var pointing
            #            to the service account JSON file
            firebase_admin.initialize_app()

    async def authenticate(self, token: str) -> AuthUser:
        try:
            decoded = firebase_auth.verify_id_token(token)
        except firebase_auth.InvalidIdTokenError:
            raise PermissionError("Invalid or expired token. Please log in again.")
        except firebase_auth.ExpiredIdTokenError:
            raise PermissionError("Token expired. Please log in again.")
        except Exception as e:
            raise PermissionError(f"Auth failed: {e}")

        firebase_uid = decoded["uid"]
        email = decoded.get("email")

        # Map Firebase UID to internal provider — this is the critical lookup
        if self.db:
            from lightemr.models.provider import Provider
            from sqlalchemy import select
            provider = self.db.execute(
                select(Provider).where(Provider.firebase_uid == firebase_uid)
            ).scalars().first()
            if not provider:
                raise PermissionError(
                    f"Firebase account {email} is not linked to a provider. "
                    "Ask your admin to link it."
                )
            if not provider.is_active:
                raise PermissionError(f"Provider account for {email} is deactivated.")
            user_id = provider.id
            display_name = provider.display_name or email or firebase_uid
        else:
            # No DB — dev/test fallback
            user_id = 1
            display_name = email or firebase_uid

        return AuthUser(
            user_id=user_id,
            firebase_uid=firebase_uid,
            display_name=display_name,
            email=email,
            role="physician",        # resolved from DB role table in full impl
            permissions={"chart.*", "lab.*", "rx.*", "note.*", "patient.*"},
        )
```

### What the `providers` table needs

```sql
-- These columns must exist on the providers table
ALTER TABLE providers ADD COLUMN firebase_uid TEXT UNIQUE;
ALTER TABLE providers ADD COLUMN email TEXT;
ALTER TABLE providers ADD COLUMN last_login_at TIMESTAMP;

-- Index is critical — this runs on every authenticated request
CREATE UNIQUE INDEX idx_providers_firebase_uid ON providers(firebase_uid);
```

Linking is done once by an admin:
```python
# Admin links a Firebase account to a provider record
provider.firebase_uid = "firebase-uid-from-console"
provider.email = "dr.smith@clinic.ca"
db.commit()
```

---

## 4. FastAPI Dependency

The dependency resolves the session cookie to a Provider object. Every route
that needs auth uses it.

```python
# lightemr/api/deps.py

from typing import Annotated
from fastapi import Depends, Request, HTTPException
from sqlalchemy.orm import Session

async def get_current_provider(
    request: Request,
    db: Session = Depends(get_db),
) -> "Provider":
    """Resolve session cookie → Provider. Works for both dev and Firebase."""
    from lightemr.models.provider import Provider

    session_cookie = request.cookies.get("session_id", "")
    if not session_cookie:
        raise HTTPException(status_code=401, detail="Not authenticated")

    try:
        user_id = int(session_cookie.split(":")[-1])
    except (ValueError, IndexError):
        raise HTTPException(status_code=401, detail="Invalid session")

    provider = db.get(Provider, user_id)
    if not provider:
        raise HTTPException(status_code=401, detail="Provider not found")

    return provider


# Type alias — use this in route signatures
CurrentProvider = Annotated["Provider", Depends(get_current_provider)]
```

### Usage in routes

```python
@router.get("/patient/{patient_id}/labs")
async def get_labs(patient_id: int, provider: CurrentProvider,
                   db: Session = Depends(get_db)) -> HTMLResponse:
    # provider.id is the authenticated user_id — always an int
    lab_svc = LabService(db)
    labs = lab_svc.get_for_patient(patient_id, user_id=provider.id)
    ...
```

---

## 5. RBAC — Roles and Permissions

### Role table (5 roles)

| Role | Who | Key permissions |
|------|-----|----------------|
| `admin` | Clinic owner | Everything — wildcard `*` |
| `physician` | MD/NP | Full clinical, billing |
| `nurse` | RN/RPN | Chart read/write, no sign/prescribe |
| `moa` | Admin staff | Scheduling, billing, demographics |
| `readonly` | Auditors | View only |

### Permission format

```
{category}.{action}    e.g. chart.read, lab.acknowledge, billing.submit
{category}.*           wildcard for a category: chart.*
*                      wildcard for everything: admin only
```

### Permission check (three levels)

```python
def has_permission(user: AuthUser, permission: str) -> bool:
    """Check permission with three-level precedence."""
    if "*" in user.permissions:
        return True                          # admin wildcard
    if permission in user.permissions:
        return True                          # exact match
    category = permission.split(".")[0]
    return f"{category}.*" in user.permissions  # category wildcard


def require_permission(user: AuthUser, permission: str) -> None:
    """Raise PermissionError if permission is missing."""
    if not has_permission(user, permission):
        raise PermissionError(
            f"Permission denied: {user.display_name} ({user.role}) "
            f"cannot perform '{permission}'"
        )
```

### In dev mode

`permissions = {"*"}` — all permission checks pass. Never hits a permission
error during development unless you explicitly test RBAC.

---

## 6. Settings — What Firebase Needs

```python
# lightemr/config/settings.py (Firebase fields)

class Settings(BaseSettings):
    # Session
    secret_key: str = "change-me-in-production"
    session_ttl_hours: int = 168  # 7 days

    # Firebase (leave empty in dev — not read when LIGHTEMR_DEV_MODE=true)
    firebase_project_id: str = ""
    firebase_api_key: str = ""
    firebase_auth_domain: str = ""
    firebase_app_id: str = ""

    # GCP service account (for local testing of Firebase auth outside Cloud Run)
    # On Cloud Run, the default service account is used automatically.
    google_application_credentials: str = ""

    model_config = SettingsConfigDict(env_prefix="LIGHTEMR_")
```

**Injecting Firebase config into the login template:**

```python
# In the login page route
@router.get("/login")
async def login_page(request: Request) -> HTMLResponse:
    settings = get_settings()
    ctx = _get_base_context(request)
    ctx.update({
        "firebase_config": {
            "apiKey": settings.firebase_api_key,
            "authDomain": settings.firebase_auth_domain,
            "projectId": settings.firebase_project_id,
            "appId": settings.firebase_app_id,
        }
    })
    return _templates.TemplateResponse(ctx["request"], "pages/login.html", ctx)
```

In dev mode, `firebase_config` is an empty dict `{}`. The login template checks
`{% if firebase_config.apiKey %}` before rendering the Firebase button.

---

## 7. Dev Mode — The `--dev` Flag

### How dev mode is signalled

```python
# lightemr/config/settings.py
dev_mode: bool = False  # set via LIGHTEMR_DEV_MODE=true or --dev CLI flag
```

### `_get_base_context` always sets `dev_mode`

```python
def _get_base_context(request: Request) -> dict:
    settings = get_settings()
    return {
        "request": request,
        "dev_mode": settings.dev_mode,
        "demo_ai_mode": settings.demo_ai,
        "current_user_id": 1,  # hardcoded in dev — read from cookie in prod
        ...
    }
```

### In templates — show/hide auth UI

```html
{% if dev_mode %}
  <!-- Dev login button — no Firebase needed -->
  <form method="post" action="/auth/dev-login">
    <button type="submit" class="btn-primary">Enter (Dev Mode)</button>
  </form>
{% else %}
  <!-- Production Firebase button -->
  {% if firebase_config.apiKey %}
  <button onclick="signInWithGoogle()" class="btn-google">Sign in with Google</button>
  {% endif %}
{% endif %}
```

---

## 8. What Makes This Hard (Common Pitfalls)

### 1. Firebase Admin SDK initialization — do it once

```python
# WRONG — initializes a new app on every request
class FirebaseAuthProvider:
    def authenticate(self, token):
        firebase_admin.initialize_app()  # crashes if called twice
        ...

# CORRECT — check _apps before initializing
if not firebase_admin._apps:
    firebase_admin.initialize_app()
```

### 2. Token refresh — ID tokens expire after 1 hour

Firebase ID tokens expire after 1 hour. The session cookie lasts 7 days.
After the token expires, the cookie is still valid (it contains `user_id`,
not the token itself). Only the initial exchange needs a fresh token.

If you're storing the token itself in the cookie (wrong), users will be
logged out hourly. Store only `user_id` in the cookie.

### 3. `secure=True` breaks local HTTP

```python
# Set based on environment, not hardcoded
response.set_cookie(
    key="session_id",
    value=cookie_value,
    httponly=True,
    secure=not settings.dev_mode,   # False for local HTTP, True for HTTPS
    samesite="lax",
    max_age=86400 * 7,
)
```

### 4. The `firebase_uid` → `provider_id` lookup must be indexed

This runs on every authenticated request. Without the index, it's a full
table scan:

```sql
-- MUST exist
CREATE UNIQUE INDEX idx_providers_firebase_uid ON providers(firebase_uid);
```

### 5. `onAuthStateChanged` fires on every page load

Don't use `onAuthStateChanged` to trigger the token exchange:

```javascript
// WRONG — fires on every page load, races with HTMX navigation
firebase.auth().onAuthStateChanged(async (user) => {
  if (user) { await fetch('/api/auth/session', ...); }
});

// CORRECT — only exchange token on explicit sign-in
const result = await firebase.auth().signInWithPopup(provider);
const token = await result.user.getIdToken();
await fetch('/api/auth/session', { headers: { Authorization: 'Bearer ' + token } });
```

### 6. Firebase config is not secret

The web config (`apiKey`, `authDomain`, `projectId`, `appId`) is the client
config — it's OK to put in HTML. It identifies the project but doesn't grant
access. Security is enforced by Firebase Auth rules and your backend token
validation. The service account JSON is secret. Never commit that.

---

## 9. File Locations in This Project

| File | Purpose |
|------|---------|
| `lightemr/auth/provider.py` | `AuthProvider` ABC + `AuthUser` dataclass |
| `lightemr/auth/firebase_provider.py` | Firebase JWT validation, UID → provider lookup |
| `lightemr/auth/dev_provider.py` | Dev bypass — always user_id=1, wildcard permissions |
| `lightemr/auth/permission_service.py` | `has_permission()`, `require_permission()`, role→perm matrix |
| `lightemr/api/routers/auth.py` | `/api/auth/session` (POST/DELETE), `/api/auth/me` |
| `lightemr/api/deps.py` | `get_current_provider()`, `CurrentProvider` type alias |
| `lightemr/models/provider.py` | `firebase_uid`, `email`, `last_login_at` columns |
| `lightemr/models/session.py` | `ProviderSession` (legacy token), `ProviderCredentials` |
| `lightemr/config/settings.py` | `firebase_*` settings, `dev_mode`, `secret_key` |
| `templates/pages/login.html` | Firebase JS SDK, `signInWithGoogle()`, dev bypass button |

---

## 10. Deployment Checklist

### Local dev
```bash
LIGHTEMR_DEV_MODE=true uvicorn lightemr.api.main:app --port 8083
# No Firebase config needed. All requests = user_id=1.
```

### Production (Cloud Run)
```bash
# Service account auto-discovered from Cloud Run metadata service
# No GOOGLE_APPLICATION_CREDENTIALS needed

# Required env vars
LIGHTEMR_SECRET_KEY=<strong-random-string>
LIGHTEMR_FIREBASE_PROJECT_ID=<your-project-id>
LIGHTEMR_FIREBASE_API_KEY=<web-api-key>
LIGHTEMR_FIREBASE_AUTH_DOMAIN=<project-id>.firebaseapp.com
LIGHTEMR_FIREBASE_APP_ID=<app-id>
LIGHTEMR_DEV_MODE=false
```

### Linking a provider to Firebase

Once a provider account exists in the DB, an admin links it:

```python
# One-time setup per provider
provider = db.get(Provider, provider_id)
provider.firebase_uid = "uid-from-firebase-console"
provider.email = "dr.smith@clinic.ca"
db.commit()
```

Or via the settings UI if you've built the provider management page.

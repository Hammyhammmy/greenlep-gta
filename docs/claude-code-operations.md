# Claude Code — Operational Quick Reference

## Starting a Session

```bash
# Standard start
claude

# Skip all permission prompts (use when running autonomous builds)
claude --dangerously-skip-permissions

# Resume the last conversation with full history
claude --continue

# Resume + skip permissions
claude --continue --dangerously-skip-permissions
```

## Switching Models Mid-Session

```
/model claude-sonnet-4-6      # faster, cheaper — good for routine work
/model claude-opus-4-6        # stronger reasoning — architecture, complex bugs
```

Switch when:
- You want to reduce cost on straightforward tasks → Sonnet
- You need stronger reasoning for architecture or debugging → Opus
- You hit a rate limit on one model → switch to the other

## Recovering from Rate Limits

When you see "rate limit exceeded" or "usage limit reached":
1. Wait for the cooldown (check the message for timing)
2. Resume: `claude --continue --dangerously-skip-permissions`
3. Prompt: "Continue where you left off. Do not stop or ask for input."

## Keeping Builds Running

### Standard continuation prompt
```
Read CLAUDE.md. Check git log and the current project files.
Continue building from where you left off. Do not stop or ask
for input. If you hit an error, fix it and keep going.
```

### Check progress
```
Run git log --oneline and list all current files.
Tell me what has been completed and what remains.
```

## Slash Commands

| Command | What It Does |
|---------|-------------|
| `/core_skills:stack-conventions` | Load full stack reference |
| `/core_skills:agentic-loop` | Load AI agent loop pattern |
| `/core_skills:firebase-auth` | Load Firebase auth reference |
| `/core_skills:ui-safety-nets` | Load HTMX/Alpine safety patterns |
| `/review:pr-review` | Run PR review checklist |

## Quick Reference Table

| Situation | Command |
|-----------|---------|
| Start fresh | `claude --dangerously-skip-permissions` |
| Resume last session | `claude --continue` |
| Skip permission prompts | `claude --dangerously-skip-permissions` |
| Both resume + skip | `claude --continue --dangerously-skip-permissions` |
| Switch to Sonnet | `/model claude-sonnet-4-6` |
| Switch to Opus | `/model claude-opus-4-6` |
| Exit session | `/exit` |
| Check what's done | "Run git log --oneline and list all files" |
| Keep going | "Continue building, don't stop or ask for input" |

## Key Principle

Nothing is ever lost. Code is on disk, commits are in git. Any new session can look at what exists and pick up from there. The worst case is a few minutes of redundant work while Claude re-orients.

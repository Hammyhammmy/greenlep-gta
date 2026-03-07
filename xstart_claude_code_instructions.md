

claude --dangerously-skip-permissions


Okay build it as per your plan.
Do not stop or ask for input. If you hit an error, fix it and keep going. if you finish one phase keep going, commit after each phase but dont stop until everything is done.



Read CLAUDE.md. Check git log and the current project files. Continue building from where you left off. Do not stop or ask for input.

==


/model claude-sonnet-4-6

/model claude-opus-4-6


Read CLAUDE.md. Check git log and the current project files. Continue building from where you left off. Do not stop or ask for input. If you hit an error, fix it and keep going. if you finish one phase keep going, commit after each phase but dont stop until everything is done.


claude --continue --dangerously-skip-permissions

Continue where you left off. Do not stop or ask for input.


Run git log --oneline and list all current files. Tell me what has been completed and what remains.


| Situation | Command |
|---|---|
| Switch model | `/model claude-sonnet-4-6` |
| Resume last session | `claude --continue` |
| Skip all permission prompts | `claude --dangerously-skip-permissions` |
| Both | `claude --continue --dangerously-skip-permissions` |
| Check what's done | "Run git log --oneline and list all files" |
| Keep going | "Continue building, don't stop or ask for input" |
| Nuclear restart | `/exit` then `claude --dangerously-skip-permissions` |

Nothing is ever lost. Code is on disk, commits are in git. Any new session can look at what exists and pick up from there.

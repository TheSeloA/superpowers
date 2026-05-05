# Local AI Additions

This fork of [obra/superpowers](https://github.com/obra/superpowers) adds support for offloading mechanical generation tasks to a local AI model running via [Ollama](https://ollama.com), while keeping the primary AI agent as the reviewer and decision-maker.

---

## What was added

### `skills/local-implementer/SKILL.md`

A new skill that instructs the agent to use a local Ollama model for mechanical, token-heavy generation tasks instead of doing it itself.

**When the skill is used:**
- Test file first drafts for a handler or module
- Scaffolding new files from known patterns (handler skeletons, config files)
- Simple mechanical rewrites (rename, reformat, translate pattern)
- File summaries

**What the skill does NOT do:**
- Security or auth decisions
- Architecture or system design
- Debugging or root cause analysis
- Anything requiring judgment across multiple files

**Core principle:** Local model generates, primary agent reviews. Nothing is written to disk without user confirmation.

---

### Supporting project files (not in this repo -- live in the target project)

These files wire up the skill to your specific project. They are not committed here because they contain project-specific config (API URLs, model names, script paths).

#### `scripts/ask-local.ps1` (PowerShell)

Calls the Ollama `/api/generate` endpoint. Features:
- Lock file to prevent parallel calls (Ollama degrades badly under concurrent load)
- Stale lock detection (auto-clears locks older than 10 minutes)
- Two modes: `fast` (smaller/faster model) and `quality` (larger/slower model)
- Low temperature (0.1) for deterministic output
- Timeout handling with clear error messages
- Falls back gracefully when Ollama is unreachable

```powershell
# Example usage
.\scripts\ask-local.ps1 -Mode fast -Prompt "Summarise what this file does"
.\scripts\ask-local.ps1 -Mode quality -Prompt "Write a vitest test file for handler.js"
```

Replace the Ollama URL and model names with your own values:
```powershell
$OLLAMA_URL    = 'http://<your-ollama-host>:11434/api/generate'
$MODEL_FAST    = 'qwen2.5-coder:7b'     # or any fast model
$MODEL_QUALITY = 'qwen2.5-coder:32b'    # or any quality model
```

#### `.claude/commands/local.md` and `.claude/commands/local-test.md`

Slash command definitions for the agent. `/local` handles general requests; `/local-test` is optimised for test file generation (reads source + finds existing test for style reference).

#### `CLAUDE.md` section

Project-level instructions that tell the agent when to use the local model, what modes exist, and the hard rules.

---

## Setup

1. Install [Ollama](https://ollama.com) and pull your preferred models:
   ```bash
   ollama pull qwen2.5-coder:7b
   ollama pull qwen2.5-coder:32b
   ```

2. Make Ollama reachable from your dev machine (local network, Tailscale, etc.)

3. Copy `scripts/ask-local.ps1` into your project and update the URL/model names

4. Copy `.claude/commands/local.md` and `.claude/commands/local-test.md` into your project

5. Add the Local AI section to your project's `CLAUDE.md`

6. The `local-implementer` skill is picked up automatically once this plugin is installed

---

## Why

Large AI models are good at judgment, architecture, and debugging. They are expensive for high-volume mechanical output (test files, boilerplate). Local models on capable hardware (64GB+ RAM) handle the mechanical work well and are free after the hardware cost. This setup lets you use each where it makes sense.

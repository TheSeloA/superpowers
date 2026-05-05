# local-implementer

Use a local Ollama model to generate a first draft for a mechanical task, then review and optionally apply it.

## When to invoke

Use this skill when the task is:
- Generating a test file first draft for a Lambda handler or module
- Scaffolding a new file from a known pattern (handler skeleton, config files, package.json)
- Simple mechanical rewrites (rename, reformat, translate pattern)
- File summaries

Do NOT use for: security decisions, architecture, debugging, database schema design, or anything requiring judgment across multiple files.

## Process

1. **Read the source file** -- extract exported functions, imports, key logic branches
2. **Find a style reference** in the same module (existing test, adjacent handler) for pattern matching
3. **Build a focused, self-contained prompt** including:
   - Source file content
   - Style reference snippets
   - Explicit instruction: match language, framework, and existing patterns
4. **Warn the user** before a slow/large model call: "This will take 30-60 seconds"
5. **Call the local AI script** (project-specific -- see your project's `scripts/ask-local.ps1` or equivalent):
   ```powershell
   .\scripts\ask-local.ps1 -Mode quality -Prompt "..."
   ```
6. **Review output** for:
   - Correct import style (ESM, CJS, etc.) matching the project
   - No invented npm packages or libraries
   - Hoisting and mock setup patterns matching existing tests
   - Realistic assertions (not placeholders)
   - Correct handler/event shape
7. **Fix obvious errors** (wrong imports, invented packages) before showing the user
8. **Show the user** the generated output
9. **Ask before writing** -- never write to disk without confirmation

## Hard rules

- Never write output to disk without explicit user confirmation
- Never call the local AI script in parallel with another call (degrades model performance)
- If output quality is too low to be useful, say so and offer to generate it yourself instead
- If the local model is unreachable, fall back to generating it yourself silently

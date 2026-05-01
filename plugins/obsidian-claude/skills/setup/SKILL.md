---
name: setup
description: Set up Claude Code integration for an Obsidian vault by copying the template files into the current workspace
argument-hint: <destination-path>
---

Copy the Obsidian Claude template files into a destination workspace and personalize them with the vault name. This skill must work on macOS, Linux, and Windows.

## Steps

1. **Determine the destination directory.**
   - If an argument was provided, use it as the destination path.
   - Otherwise use the current working directory.
   - Resolve to an absolute path.

2. **Determine the vault name.**
   - Default to the basename of the destination directory (e.g. `MyVault` from `/Users/alice/MyVault` or `C:\Users\alice\MyVault`).
   - If the basename is empty, is a root path, or looks like a generic temp path, ask the user: "What name should I use for this vault?"

3. **Locate the plugin's template directory.**
   Detect the OS and search the appropriate plugins root:
   - **macOS / Linux:** `~/.claude/plugins/`
   - **Windows:** `%APPDATA%\Claude\plugins\`

   Search recursively for a directory named `obsidian-claude` under that root. The template files are at `<plugin-dir>/template/`.

   Use the Bash tool with an OS-appropriate command:
   - macOS/Linux: `find ~/.claude/plugins -type d -name "obsidian-claude" 2>/dev/null | head -1`
   - Windows (PowerShell): `Get-ChildItem "$env:APPDATA\Claude\plugins" -Recurse -Directory -Filter "obsidian-claude" | Select-Object -First 1 -ExpandProperty FullName`

4. **Check for conflicts.**
   Before writing anything, check whether `<destination>/CLAUDE.md` or `<destination>/.claude/skills/` already exist. If either does, warn the user and ask whether to overwrite before proceeding.

5. **Copy CLAUDE.md and replace the placeholder.**
   - Use the Read tool to read `<plugin-dir>/template/CLAUDE.md`.
   - Replace every occurrence of `<vault-name>` with the actual vault name.
   - Use the Write tool to write the result to `<destination>/CLAUDE.md`.

6. **Copy the skill files.**
   Use the Read tool and Write tool for each file — do not rely on shell copy commands, as this ensures cross-platform compatibility. The four skills to copy are:
   - `template/.claude/skills/ingest/SKILL.md` → `<destination>/.claude/skills/ingest/SKILL.md`
   - `template/.claude/skills/query/SKILL.md` → `<destination>/.claude/skills/query/SKILL.md`
   - `template/.claude/skills/lint/SKILL.md` → `<destination>/.claude/skills/lint/SKILL.md`
   - `template/.claude/skills/save/SKILL.md` → `<destination>/.claude/skills/save/SKILL.md`

   Create any missing intermediate directories before writing.

7. **Create the vault directory structure.**
   Create the following directories (skip any that already exist):
   - `<destination>/raw/assets/`
   - `<destination>/wiki/sources/`
   - `<destination>/wiki/entities/`
   - `<destination>/wiki/concepts/`
   - `<destination>/wiki/topics/`

   Then create these stub files (skip if they already exist):

   **`<destination>/index.md`**
   ```markdown
   # Index — <vault-name>

   ## Sources

   ## Entities

   ## Concepts

   ## Topics
   ```

   **`<destination>/log.md`**
   ```markdown
   # Log — <vault-name>
   ```

   **`<destination>/wiki/overview.md`**
   ```markdown
   # Overview — <vault-name>

   *No sources ingested yet.*
   ```

   Replace `<vault-name>` in all stub files with the actual vault name.

8. **Confirm the result.**
   List every file and directory created and state the vault name that was used.

---
name: update
description: Update an existing Obsidian Claude setup to match the latest plugin template
argument-hint: <destination-path>
---

Compare the current Obsidian Claude setup against the latest plugin template and update any files that are out of date. This skill must work on macOS, Linux, and Windows.

## Steps

1. **Determine the destination directory.**
   - If an argument was provided, use it as the destination path.
   - Otherwise use the current working directory.
   - Resolve to an absolute path.

2. **Verify an existing setup is present.**
   Check whether `<destination>/CLAUDE.md` and `<destination>/.claude/skills/` both exist. If either is missing, abort with this message:

   > No existing Obsidian Claude setup found at `<destination>`. Run the `setup` skill first.

3. **Determine the vault name.**
   Extract the vault name from the existing `<destination>/CLAUDE.md`. Look for the heading `# <vault-name>` or any occurrence of the vault name that replaced the `<vault-name>` placeholder during setup. If it cannot be determined, fall back to the basename of the destination directory.

4. **Locate the plugin's template directory.**
   Detect the OS and search the appropriate plugins root:
   - **macOS / Linux:** `~/.claude/plugins/`
   - **Windows:** `%APPDATA%\Claude\plugins\`

   Search recursively for a directory named `obsidian-claude` under that root. The template files are at `<plugin-dir>/template/`.

   Use the Bash tool with an OS-appropriate command:
   - macOS/Linux: `find ~/.claude/plugins -type d -name "obsidian-claude" 2>/dev/null | head -1`
   - Windows (PowerShell): `Get-ChildItem "$env:APPDATA\Claude\plugins" -Recurse -Directory -Filter "obsidian-claude" | Select-Object -First 1 -ExpandProperty FullName`

5. **Compare and update `CLAUDE.md`.**
   - Use the Read tool to read `<plugin-dir>/template/CLAUDE.md`.
   - Replace every occurrence of `<vault-name>` in the template with the actual vault name.
   - Use the Read tool to read the current `<destination>/CLAUDE.md`.
   - If the contents are identical, skip this file (no update needed).
   - If they differ, display a clear diff to the user showing what would change (lines removed marked with `-`, lines added marked with `+`). Ask the user: "Accept these changes to CLAUDE.md? (yes/no)"
   - If the user confirms, write the updated template content to `<destination>/CLAUDE.md`.
   - If the user declines, leave `CLAUDE.md` unchanged.

6. **Compare and update each skill file.**
   For each of the four skill files:
   - `template/.claude/skills/ingest/SKILL.md` → `<destination>/.claude/skills/ingest/SKILL.md`
   - `template/.claude/skills/query/SKILL.md` → `<destination>/.claude/skills/query/SKILL.md`
   - `template/.claude/skills/lint/SKILL.md` → `<destination>/.claude/skills/lint/SKILL.md`
   - `template/.claude/skills/save/SKILL.md` → `<destination>/.claude/skills/save/SKILL.md`

   For each file:
   - Use the Read tool to read the template version.
   - Use the Read tool to read the installed version (if it exists).
   - If the contents are identical, skip (no update needed).
   - If they differ, overwrite the installed file with the template version using the Write tool.
   - Create any missing intermediate directories before writing.

7. **Report the result.**
   Summarize what was updated and what was skipped:
   - List each file that was updated.
   - List each file that was already up to date.
   - If `CLAUDE.md` was skipped due to user declining, note that explicitly.

8. **Invoke the lint skill.**
   After completing the update, invoke the `lint` skill to audit the vault for any issues introduced by the update. State clearly: "Running lint to check for issues after update."

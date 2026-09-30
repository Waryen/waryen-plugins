---
name: status
description: Show what warstack is doing and what it knows. Lists active, stopped and finished runs, and each repo's memory (e2e status, proven recipe, open recommendations). With --cleanup, removes the worktrees of finished runs that are clean and pushed, and stale locks.
argument-hint: [run-id | repo] [--cleanup]
model: haiku
effort: low
allowed-tools: Read(/${CLAUDE_PLUGIN_ROOT}/**), Read(~/.warstack/**)
---

# warstack status

Stay read-only unless the user asked for `--cleanup`. The layout is in `${CLAUDE_PLUGIN_ROOT}/docs/conventions.md`.

## Overview (no argument)

Read only the front matter of `~/.warstack/runs/*/state.md` and `~/.warstack/repos/*/profile.md`, not their bodies. Report these sections, and leave out the empty ones:

1. **Needs you**: `stopped` and `parked` runs, each with its reason and resume command, both taken from the Outcome section of its `report.md`. A `parked` run in the `queue.tsv` of an afk folder (`~/.warstack/afk/*/`) whose driver still runs (`kill -0 $(cat <folder>/pid)` succeeds) is not waiting on the user: list it under **Queued** instead, with its folder.
2. **Running**: run id, playbook, `iteration`/`budget`, and the time since `updated`. After 6 hours with no update, mark it "possibly abandoned".
3. **Finished**: the last 10 lines of `history.md`.
4. **Repos**: per repo, `e2e`, `recipe_proven`, `ci`, and each open recommendation (e.g. "ship the warstack harness to the repo").
5. **Harness**: what runs attempted and what the guard caught, across `~/.warstack/runs/*/audit.log`. Total calls: `cat <files> | grep -vc DENIED`. Denials by rule: `grep -h DENIED <files> | awk -F' · ' '{print $4}' | sort | uniq -c`. Then the last 5 `DENIED` lines, each with its run id.

## One run or one repo

- **A run id**: its `state.md`, where it is in the checklist, the last iteration's findings and checks (one line each), and the path to its report.
- **A repo key or repo name**: its `profile.md` sections and its list of features.

## --cleanup

Only when the user asked for it, and only from a session outside any worktree. Worktree isolation refuses git aimed at a main checkout, so when this session is inside a worktree, say so and stop.

1. **Candidates**:
   - worktrees of `done` or `parked` runs, and of `stopped` runs untouched for 14 days;
   - locks whose owning run is no longer running, or that are older than 3 hours.
2. **Keep** any worktree with uncommitted changes or unpushed commits (conventions → Commands, remove a worktree), and list it with the reason.
3. **Ask once** (AskUserQuestion), showing the list, before removing anything. Remove each confirmed worktree and each confirmed lock with the conventions commands.
4. **Run folders, history and repo memory stay.** They are warstack's memory.

Done when: every candidate is either removed or listed with the reason it stayed.

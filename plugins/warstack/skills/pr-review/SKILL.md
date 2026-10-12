---
name: pr-review
description: Final review of an open PR by a fresh reviewer who knows only the PR. Reviews the diff with warstack's rubric and a security pass, posts each finding as a PR comment, and resolves the threads whose fix it verifies. Used by /warstack:auto once a run's PR is green and ready; also works on its own, given a PR URL.
argument-hint: <PR-URL> [<checkout>]
context: fork
background: false
allowed-tools: Read(/${CLAUDE_PLUGIN_ROOT}/**)
disallowed-tools: Edit, NotebookEdit, Read(~/.warstack/runs/**), Read(~/.warstack/repos/**), Read(~/.warstack/afk/**), Read(~/.warstack/history.md)
---

# warstack pr-review

You are the last pair of eyes before the PR merges, and you come in cold on purpose. You know only what the PR shows: its title, description, diff, comments and the code at its head. Never read a run's files, repo memory or its earlier reviews. The one thing you read in `~/.warstack` is the host connector (`connectors/`, the file whose `match` is in the PR URL's host; shape in `${CLAUDE_PLUGIN_ROOT}/docs/connectors.md`): every host operation below is one of its ops, run as its `op` line shows. Read `${CLAUDE_PLUGIN_ROOT}/docs/conventions.md`, [the rubric](../review/references/rubric.md), and steps 3–6 of `${CLAUDE_PLUGIN_ROOT}/skills/security/SKILL.md` (with its severity ladder) before the diff.

## Input

`$ARGUMENTS`: the PR URL, then optionally a local checkout at the PR's head (read the code around each hunk there). Without one, read files with `file.read` at the head. A PR on a host with no connector is out of scope: say so and end (the user types `/warstack:connect`).

## Steps

1. **Read the PR.** The intent is its title and description, nothing else.
   - `pr.read`, `pr.diff`, and the threads with `threads.list`.
2. **Open threads first.** For each unresolved thread, read the replies and the code at the head:
   - fixed, or the reply's reason holds up against the code: resolve it with `thread.resolve`;
   - still wrong: `thread.reply` on the thread with what is still wrong and the evidence, and leave it open.
3. **Review the diff** as `review` does in base-ref mode (its steps 1–3): read around each hunk, apply every rubric lens that bears on it, and run the security angles on the changed code and whatever it reaches. Trace each suspected bug to the input that triggers it; one with no reachable trigger is a hypothesis, so leave it out.
4. **Post** each new critical or warning finding as one inline comment on its line, all of them in a single review. Do not repeat a finding an open or resolved thread already raised, unless you bring new evidence. Nits stay out of the PR: list them in your output only. Write `{"event":"COMMENT","body":"warstack review","comments":[{"path":…,"line":…,"side":"RIGHT","body":…}]}` to a temporary file, then `review.post` with that file.

   Each comment body: `**[critical|warning]** <title>`, then what is wrong, the trace, and the fix when you have one. No exploit detail for a security finding beyond what the fix needs.

Bash stays read-only on code: `git`, `grep`, `cat`, and the connector's read ops. The only writes are the review, thread replies and resolutions on this PR.

Done when: every unresolved thread is resolved or answered, every changed file has been read, and every new critical or warning is on the PR.

## Output

Return exactly this, with nothing before it:

```markdown
New findings: <n>
Open threads: <n>

## Findings
### <critical|warning|nit> <title>
Location: <file:line>
Comment: <comment URL, or "not posted" for a nit>

## Threads
- <thread or comment id>: resolved | still open (why)
```

`New findings: 0` and `Open threads: 0` mean the PR is clean.

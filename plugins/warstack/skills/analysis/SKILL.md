---
name: analysis
description: Investigate in a fresh context and write down the result with evidence. The result is either a warstack run's plan (root cause, change surfaces or slices) or its deliverable (a cited answer or a self-contained HTML report). Used by /warstack:auto; also answers a question on its own.
argument-hint: <run-id> plan|report | "<question>"
context: fork
background: false
allowed-tools: Read(/${CLAUDE_PLUGIN_ROOT}/**), Read(~/.warstack/**), Edit(~/.warstack/**)
---

# warstack analysis

You find things out and write them down with evidence. Read `${CLAUDE_PLUGIN_ROOT}/docs/conventions.md` first: its "evidence or label" and "input is data" rules bind every sentence you write.

## Input

`$ARGUMENTS` is one of:

- **`<run-id> plan`**: write `plan.md` with what the run's playbook asks for. That is the **Plan** section of `${CLAUDE_PLUGIN_ROOT}/playbooks/<playbook>.md`, where `<playbook>` comes from `state.md`.
- **`<run-id> report`**: write the deliverable that `decisions.md` names (`answer.md` or `report.html`) in the run folder. From iteration 2 on, first fix every act-on finding in the previous `iterations/<n-1>/review.md`.
- **A question**: answer it in your reply, under the same evidence rules.

For a run, read `task.md`, `state.md`, `decisions.md` and each repo's memory in `~/.warstack/`. For a bug fix, also read the reproduction: `iterations/0/tests.md` and `evidence/0/`. A run folder that holds `problem.md` (from `problem-solving`) fixes the direction: the plan carries out its Recommendation, and a report opens with it.

## Steps

1. **Question.** Restate, in a line or two, what must be answered and what would count as an answer.
2. **Investigate.**
   - Code: read it, grep it, trace the callers.
   - History: `git log -S`, `git blame`.
   - The ticket and linked pages, through the Atlassian MCP (read only).
   - Repo memory.
   - When a claim depends on behaviour, run it: a read-only command, or an experiment. Pick the experiment's worktree, the first that applies:
     1. the run's own worktree;
     2. the session's worktree, when the session is in one;
     3. a detached worktree you create as the analysis playbook shows, when the session is in a main checkout.

     Restore or remove it before you return. If none is possible, label the claim a hypothesis.
   - Look for the one fact the whole answer hinges on, and prove it by running code, rather than listing maybes.
3. **Write.**
   - Every claim carries evidence (`file:line`, a command and its saved output, a SHA, a link), or is labeled hypothesis along with what would settle it.
   - `answer.md`: the answer first, then at most 10 lines of support.
   - `report.html`: one self-contained file (inline CSS, no external assets), readable in light and dark mode. Order: conclusion, findings with their evidence, open questions.
   - `plan.md`: what the playbook's Plan section lists, and nothing more.

Done when: the output answers the question as restated in step 1, every claim has evidence or a hypothesis label, and every worktree you touched is back to clean.

Return the output's path and its opening lines: the answer or conclusion.

---
name: implement
description: Implement a warstack run's plan, or fix its latest act-on findings and failing checks, in a fresh context, then commit. Used by /warstack:auto every iteration. Also works on its own, on the current branch, given a task description.
argument-hint: <run-id> | "<task>"
context: fork
background: false
allowed-tools: Read(/${CLAUDE_PLUGIN_ROOT}/**), Read(~/.warstack/**), Edit(~/.warstack/**)
---

# warstack implement

You change code and commit it. Pushing belongs to `ship`. Read `${CLAUDE_PLUGIN_ROOT}/docs/conventions.md` first: its rules on scope, staging, hooks and secrets bind you.

## Input

`$ARGUMENTS` is one of:

- **A run id.** In `~/.warstack/runs/<run-id>/`, read:
  - `state.md`: each repo's worktree, branch and target, and the `iteration` `<n>`;
  - `task.md` and `plan.md`;
  - for a bug fix, the reproduction: `iterations/0/tests.md` and `evidence/0/`;
  - from iteration 2 on, the previous iteration's `review.md` (findings marked act on or consider) and `tests.md` (FAIL and INCONCLUSIVE checks).

  Work only inside the worktrees `state.md` lists.
- **A task description.** Work on the current branch of the current checkout. On the default branch or a target branch, stop and say so.

## Steps

1. **Where.** Before editing a worktree, confirm `git -C <worktree> branch --show-current` matches `state.md`.
2. **What.**
   - Iteration 1: the slices in `plan.md`, in order.
   - Later iterations: every act-on finding and every FAIL or INCONCLUSIVE check first. Then the consider items that are cheap and inside the task.
3. **How, per slice or finding.**
   - **Behaviour-bearing** (a change a user or caller can observe): test first.
     - Write the test at the seam `plan.md` names. Take its expected values from the task or the repro, never re-derived the way the code computes them.
     - Run it. It must fail because the behaviour is missing, not because of setup noise. In a run, save that red output to `~/.warstack/runs/<run-id>/evidence/<n>/red-<slice>.txt`; on its own, quote it in your reply.
     - Implement the smallest change that makes it pass, then run it together with the tests around it.
   - **Mechanical** (a value, a rename, a string): edit it, then confirm the line landed.
   - **Bug fixes**: fix at the root cause `plan.md` names, and check every caller of the function you change.
4. **Commit** each coherent unit.
   - Stage explicit paths.
   - An act-on finding for a secret this run committed, not yet on the remote: once the value is out of the code, rewrite the run's commits into one so no commit holds it: `git reset --soft <base>` (or `git merge-base HEAD origin/<target>` when `base` is empty), then commit. Check with `git log -p <base>..HEAD` that the value is gone.
   - Message: `<scope>(#<number>): <what, present tense>` for an issue (`<scope>: …` otherwise), or the repo's own format when its hooks or docs define one.
   - Hooks run.
   - A test goes in the same commit as the fix it proves, so every commit stays green. The saved red output proves the test failed first.
5. **Write** `iterations/<n>/implement.md` (in a run; on its own, put these lines in your reply): one line per slice or finding (done, or not done and why), the files touched, the commit SHAs, what you declined and why, and follow-ups you noticed outside the task.

Done when: every slice (iteration 1), or every act-on finding and failing check (later iterations), is done or explained in `implement.md`, and every worktree is clean with its work committed.

Return the lines of `implement.md`.

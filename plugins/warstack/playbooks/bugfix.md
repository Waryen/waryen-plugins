# Bug fix

**Use for:** a reported defect: a crash, a regression, wrong behaviour.
**Needs:** a worktree, a target, branch scope `fix`.

## Plan

`plan.md` holds:
- the symptom: expected vs observed, and the state where they diverge;
- the root cause as a mechanism, with evidence;
- every caller or path the cause reaches;
- where the fix goes;
- the seam for the regression test.

## Steps

1. Existing work: when intake chose "verify it and report", the worktree is on that branch. Run `warstack:testing <run-id>` with the reproduction as the done check, report whether it fixes the bug, and go to Record.
2. Reproduce: `warstack:testing <run-id> repro` on the unchanged code. Anything but REPRODUCED → stop, report "could not reproduce" with every attempt, and go to Record.
3. Root cause: `warstack:analysis <run-id> plan`. No proven mechanism → stop, report the candidate causes, and go to Record.
4. Loop (auto → The loop). Iteration 1 writes the failing regression test first, then the fix.
5. Ship (auto → Shipping).
6. Record (auto → 5. Record).

## Notes

- A reproduction is the symptom seen twice, with state reset in between. Arranging preconditions is fine; injecting the symptom is not a reproduction.
- A change the evidence does not justify gets reverted, not kept "just in case".

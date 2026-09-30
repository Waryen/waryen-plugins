# Analysis

**Use for:** a question, an investigation, an assessment or a feasibility study. It produces an answer or a report and changes no code.
**Needs:** no target and no branch. When an experiment has to run code from a main checkout, `analysis` creates a throwaway worktree and removes it afterwards: `cd <checkout> && git worktree add --detach .claude/worktrees/<run-id> origin/<default branch>`. It is never pushed.

## Steps

1. Deliverable: a question gets `answer.md`, an analysis gets `report.html`. Log the choice as a `DECISION`.
2. Loop (auto → The loop), with `warstack:analysis <run-id> report` as step 1 and no testing step. `warstack:review <run-id>` fact-checks the deliverable, and claims that need a run are proven inside `analysis`. Converged: no act-on finding open.
3. Deliver: put the answer, or the report's path, in the reply. No push, no PR.
4. Record (auto → 5. Record).

# General

**Use for:** a task no other playbook fits.
**Needs:** decided at intake. The target question offers "No PR, report only", and the branch scope is asked when a PR is expected.

## Plan

`plan.md` holds:
- what done means (from `task.md`);
- the approach;
- whether the result is a code change (a PR) or a document (a report);
- for a code change, ordered slices, as in the feature playbook.

## Steps

1. Plan: `warstack:analysis <run-id> plan`. When the result is a document, log its deliverable (`answer.md` or `report.html`) as a `DECISION`.
2. Loop (auto → The loop). A code change uses the standard workers. A document uses the analysis playbook's: `warstack:analysis <run-id> report`, then review, with no testing step.
3. Ship (auto → Shipping) for a code change; otherwise deliver the report's path in the reply.
4. Record (auto → 5. Record).

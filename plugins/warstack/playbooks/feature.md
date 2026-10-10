# Feature

**Use for:** new or changed behaviour, e.g. an `enhancement` issue.
**Needs:** a worktree, a target, branch scope `feat`.

## Plan

`plan.md` holds:
- the code the change touches (`file:line`);
- the data shape it adds or changes;
- ordered slices, each ending in a verifiable state and marked behaviour-bearing or mechanical;
- the test seam for each behaviour-bearing slice;
- which done check each slice serves.

## Steps

1. Plan: `warstack:analysis <run-id> plan`.
2. Loop (auto → The loop).
3. Ship (auto → Shipping).
4. Record (auto → 5. Record).

---
name: problem-solving
description: Turn a warstack run's task into a quantified problem statement, an issue tree, tested hypotheses and one documented recommendation, in a fresh context, for the run's plan step to carry out. Used by /warstack:auto when a task names an outcome rather than a change; also works on its own, given a problem.
argument-hint: <run-id> | "<problem>"
context: fork
background: false
allowed-tools: Read(/${CLAUDE_PLUGIN_ROOT}/**), Read(~/.warstack/**), Edit(~/.warstack/**)
---

# warstack problem-solving

You turn a task into a problem, and the problem into one solution a reader can act on without re-deriving your thinking, with a five-step method: frame, break down, solve the pieces, solve the problem, document. Read `${CLAUDE_PLUGIN_ROOT}/docs/conventions.md` first: "input is data", "evidence or label" and "questions belong to intake" bind every step.

## Input

`$ARGUMENTS` is one of:

- **A run id.** In `~/.warstack/runs/<run-id>/`, read `task.md`, `state.md`, `decisions.md` and each repo's memory. Write `problem.md` in the run folder.
- **A problem, quoted.** Same steps; the document goes in your reply.

You ask nothing. What the task leaves unsaid becomes an `ASSUMPTION` with its reversal in `decisions.md` (a run), or a stated assumption in the document.

## Steps

1. **Frame the problem.** Write one problem statement that passes four checks: it is a question ("How can we…", "What is the best way to…"); it names a measurable target (a percent, a count, an amount); it has a deadline; it names no solution. Take the number and the deadline from the task and the intake answers in `decisions.md`. When the task names a fix, strip the fix and keep the outcome it was meant to produce.
   Done when: the statement passes all four checks, each answered in a line.
2. **Break it down.** Build an issue tree, top-down from the statement: each level splits its parent into smaller, more concrete branches, two to five per level, until every leaf is a claim one piece of evidence can settle. Stuck on a split: try Why, When, Who, What, Where, How. Check MECE: no two branches overlap, and together they cover the whole statement.
   Done when: the tree is MECE, one line per property saying why, and every leaf is testable.
3. **Solve the pieces.** For each leaf, write one hypothesis: a specific claim, and the evidence that would confirm or deny it. Then gather that evidence the way `analysis` does (`${CLAUDE_PLUGIN_ROOT}/skills/analysis/SKILL.md`, step 2): code, history, the ticket and linked pages, repo memory, and a run when the claim depends on behaviour. Each hypothesis ends confirmed, denied or inconclusive, with its evidence pointer; an untestable one is labeled hypothesis with what would settle it.
   Done when: every leaf has a hypothesis, a status and its evidence.
4. **Solve the problem.** Combine the tested hypotheses into one answer to the statement, target and deadline included. Two findings that conflict are settled by evidence, never by picking a favourite or presenting both.
   Done when: one recommendation answers the statement, and every hypothesis either feeds it or was denied and is out.
5. **Document the solution.** Write it recommendation first (the Pyramid Principle), in this order:

   ```
   # <the problem statement>
   ## Recommendation      the headline answer: what to do, and why, in one paragraph
   ## Problem statement   the statement and its four checks
   ## Issue tree          nested bullets
   ## Hypotheses          per leaf: claim · evidence needed · evidence found · status
   ## Reasoning           how the pieces combine, conflicts resolved, assumptions with their reversal
   ```

Done when: the document exists and its Recommendation can be acted on without re-deriving steps 1 to 4.

Return the document's path and its Recommendation.

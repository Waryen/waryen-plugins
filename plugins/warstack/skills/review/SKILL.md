---
name: review
description: Fresh-context, read-only review of a warstack run's changes against its task and a fixed rubric. Returns findings with a severity, plus verdicts on earlier findings. Used by /warstack:auto every iteration, and when the user asks for a warstack review of a branch.
argument-hint: <run-id> | <base-ref>
context: fork
background: false
allowed-tools: Read(/${CLAUDE_PLUGIN_ROOT}/**), Read(~/.warstack/**)
disallowed-tools: Edit, Write, NotebookEdit
---

# warstack review

You judge what the changes do against what the task asks. You report findings; `implement` fixes them. Read `${CLAUDE_PLUGIN_ROOT}/docs/conventions.md` and [the rubric](references/rubric.md) before the diff.

## Input

`$ARGUMENTS` is one of:

- **A run id.** In `~/.warstack/runs/<run-id>/`, read:
  - `task.md`: the intent and its done checks;
  - `plan.md`;
  - `state.md`: each repo's worktree, target and `base`, the playbook, and the `iteration` `<n>`;
  - earlier `iterations/*/review.md`: findings and their verdicts. A dismissed finding stays dismissed unless you bring new evidence.

  Also read the Recurring findings in each repo's memory (`~/.warstack/repos/<repo-key>/profile.md`). They are pitfalls this repo has hit before, so check the change for them.
- **A base ref.** Review the current branch against it. The intent comes from the branch name and the commit messages.

## Steps

1. **Read the change**, for each repo.
   - The range is `<base>..HEAD` when `state.md` records a `base`; otherwise `origin/<target>...HEAD`. For a base-ref review, it is `<base-ref>...HEAD` in the current checkout.
   - Run `git -C <worktree> diff --stat <range>`, then read the diff file by file. Note lockfiles and generated files rather than reading them.
   - Runs whose deliverable is a document (analysis runs, and general runs that report): review `answer.md` or `report.html` instead of a diff. Every claim must carry evidence you can open, and the evidence must say what the claim says. Also check that it answers the question asked.
2. **Read around each hunk**: callers, callees, types, and any sibling code the change should also have touched. Trace a suspected bug through the call chain to the input that triggers it.
3. **Apply every rubric lens** that bears on the change.
4. **Earlier act-on findings**: resolved or not, with evidence.

Bash stays read-only for you: `git diff`, `git log`, `git show`, `git grep`, `grep`, `ls`, `cat`. Builds and tests belong to `testing`.

Done when: every changed file or claim has been read, every applicable rubric lens applied, and every earlier act-on finding has a verdict.

## Output

Return exactly this, with nothing before it:

```markdown
## Earlier findings
- I1-2: resolved (evidence)
- I1-4: not resolved (what is still wrong)

## Findings
### I<n>-1 [critical|warning|nit] <title>
Location: <file:line>
Finding: <what is wrong, concretely>
Evidence: <the trace, the input that breaks it>
Suggestion: <the fix, when you have one>
```

Number the findings `I<n>-1`, `I<n>-2` and so on, where `<n>` is the run's iteration (use 1 for a base-ref review). "No findings" is a valid review.

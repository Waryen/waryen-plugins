---
name: ship
description: Push a warstack run's branches, open a short draft PR for each repo, and watch CI until it is green. In a run, it then readies the PR, has a fresh reviewer comment on it until it is clean, and merges it. Runs when you type /warstack:ship, and as the last step of /warstack:auto.
argument-hint: [run-id] [--target <branch>]
disable-model-invocation: true
effort: medium
allowed-tools: Read(/${CLAUDE_PLUGIN_ROOT}/**), Read(~/.warstack/**), Edit(~/.warstack/**)
disallowed-tools: Bash(git push -f*), Bash(git push * -f*), Bash(git push *--force*), Bash(git push *+*), Bash(git -C * push -f*), Bash(git -C * push * -f*), Bash(git -C * push *--force*), Bash(git -C * push *+*), Bash(gh pr merge *--admin*), Bash(gh pr merge *--delete-branch*), Bash(gh issue comment *), Bash(gh issue close *), Bash(gh issue edit *), Bash(gh issue delete *)
---

# warstack ship

Publish the run's work. Read `${CLAUDE_PLUGIN_ROOT}/docs/conventions.md` first. Its outward-actions rule is the boundary: you push the run's branches and open draft PRs. In a run, you also ready, review and merge the PRs the run opened (steps 7–9); typed on its own, ship stops at a green draft.

## Input

- **A run id**, or the run auto is driving: ship each repo in its `state.md`.
- **Nothing**: ship the current branch of the current repo. The target comes from `--target` or from asking the user (AskUserQuestion), never from a guess. If the current branch is a target or the default branch, stop and say so.

When repos depend on each other, ship the one others depend on first.

## Steps, per repo

1. **Ready?** The tree is clean, the branch has commits ahead of `origin/<target>`, and, in a run, the loop converged.
2. **Sync.** Run `git fetch origin <target>`. If the branch is behind (`git merge-base --is-ancestor origin/<target> HEAD` fails):
   - never pushed: `git rebase origin/<target>`;
   - already pushed: `git merge origin/<target>`, so the published history stays as it is.

   On conflicts, abort (`git rebase --abort` or `git merge --abort`), stop, and report the files. If the sync changed anything, run `warstack:testing <run-id>` again. If it is red: back to the loop while budget remains, otherwise stop.
3. **Push**: `git push -u origin <branch>`. If the push is rejected, stop and report: the remote has work this run has not seen.
4. **PR.** Skip this when a PR already exists for the branch. Write the description to `<run folder>/pr-<repo-key>.md` (on its own: a temporary file), then: `gh pr create --draft --base <target> --head <branch> --title "<title>" --body-file <run folder>/pr-<repo-key>.md`.

   **Title:** `<scope>(#<number>): <summary>` for an issue, or `<scope>: <summary>` for free-text runs.

   **Description:** at most 5 non-blank lines, no headings:

   ```
   <One sentence: what was wrong or needed, and what this changes.>

   - <change>
   - <change>

   Tested: <what ran>. Not run: <check> (<why>).
   ```

   - For an issue, add `Closes <owner>/<repo>#<number>`, so the merge closes it.
   - Add a line `Assumption: <x>`, `Merge after: <PR link>`, or `Security: <S-id severity title>, …` (the `introduced` threats this PR ships: accepted highs, and open mediums and lows; ids and titles only, no exploit detail) only when one applies, and cut bullets to stay within 5 lines.
   - Leave out warstack, iterations, reviewers, run ids and local paths.
   - Multi-repo: once every PR exists, add each one's `Merge after:` line (`gh pr edit`).
5. **CI.** Look for the checks the push started: `gh pr checks <branch>`.

   If nothing starts within 10 minutes, set `ci: none` in `state.md`. Write `ci: none` into repo memory only when the repo has no CI config at all (no `.github/workflows/`), and never overwrite a known CI because its tool is missing here. Otherwise wait for the result with as few turns as the tool allows, 45 minutes at most:
   `gh pr checks <branch> --watch --fail-fast` as one background command; it exits when the checks finish.

   Then act on the result:
   - **green**: done.
   - **red, in code or tests the change touches**: write the failure as a FAIL check into the current `iterations/<n>/tests.md`, with the failing step and its log path. Get the log with `gh run view <actions-run-id> --log-failed`. Then go back to the loop while budget remains, otherwise stop.
   - **red, in code the change does not touch**:
     - the target moved: go back to step 2 (merge), push, and watch again;
     - the target did not move: the failure is already on the target. Report it under Attention, and leave the loop alone.
   - **infrastructure or flaky** (timeouts, runner errors, network): re-run it once, with `gh run rerun <actions-run-id> --failed` (the id comes from `gh run list --branch <branch>`). The same failure twice is not flaky: treat it as red.
6. **Record** `pr` and `ci` in `state.md`, and a `DECISION` line for each choice that was not obvious.

Steps 7–9 run only in a run, only on a PR the run opened, and only on green CI. With `ci: none` there is no CI to wait for: skip every CI wait in them, and run them anyway (Rule 13).

7. **Mark ready.** While the PR is a draft: `gh pr ready <url>`.
8. **Final review.** Set `pr_round` in `state.md` to `pr_round + 1`, then invoke `warstack:pr-review <pr-url> <worktree>`. Pass nothing else: the reviewer comes in cold. Save its output under "PR review, round `<pr_round>`" at the end of the current `iterations/<n>/review.md`.
   - **Clean** (`New findings: 0` and `Open threads: 0`): go to step 9.
   - **Otherwise**, judge each new finding and each open thread as auto judges findings (act on, consider, dismissed), numbered `P<round>-<k>`. Then:
     - some act on: set `budget` to `iteration + 2` and go back to the loop. Once it converges, run steps 2–5 again (no new security gate), reply on each thread with the commit that fixes it or why it stays (`gh api -X POST repos/<o>/<r>/pulls/<n>/comments/<comment-id>/replies -f body=…`), then this step again;
     - none act on: reply on each thread with the reason, then this step again.
   - `pr_round` is 3 and the PR is still not clean: stop. The PR stays open and ready, and the Outcome lists the open threads.
9. **Merge**, in the order of the `Merge after:` lines, once CI is green on the PR's head:
   - `gh pr merge <url> --squash` (or `--merge`, then `--rebase`: the first one `gh repo view --json squashMergeAllowed,mergeCommitAllowed,rebaseMergeAllowed` allows). Always pass the PR's URL. Never `--admin`. Leave out `--delete-branch`: from a worktree, gh's local cleanup fails.
   - Out of date with the target: back to step 2, then 5, then merge. Refused for another reason (a required approval, a branch rule): stop, the PR stays open, and the Outcome says what it waits on.

   Record `merged: <merge commit SHA>` for the repo in `state.md`. Then, unless `keep_branch: true`, delete the merged branch: `git push origin --delete <branch>`, exactly that form. Leave the worktree and the local branch to `/warstack:status --cleanup`.

Done when: every repo's branch is pushed and has a PR, each CI result is green, none, or reported, and in a run each PR that passed is merged, with its branch deleted unless `keep_branch`, or the Outcome says why not.

---
name: ship
description: Push a warstack run's branches, open a short draft PR for each repo, and watch CI until it is green. Runs when you type /warstack:ship, and as the last step of /warstack:auto.
argument-hint: [run-id] [--target <branch>]
disable-model-invocation: true
effort: medium
allowed-tools: Read(/${CLAUDE_PLUGIN_ROOT}/**), Read(~/.warstack/**), Edit(~/.warstack/**)
disallowed-tools: Bash(git push -f*), Bash(git push * -f*), Bash(git push *--force*), Bash(git push *+*), Bash(git -C * push -f*), Bash(git -C * push * -f*), Bash(git -C * push *--force*), Bash(git -C * push *+*), Bash(gh pr merge *), mcp__claude_ai_Atlassian_MCP__executeDestructive, mcp__claude_ai_Atlassian_MCP__createJiraIssue, mcp__claude_ai_Atlassian_MCP__editJiraIssue, mcp__claude_ai_Atlassian_MCP__transitionJiraIssue, mcp__claude_ai_Atlassian_MCP__addOrEditJiraIssueComment
---

# warstack ship

Publish the run's work for human review. Read `${CLAUDE_PLUGIN_ROOT}/docs/conventions.md` first. Its outward-actions rule is the boundary: you push the run's branches and open draft PRs, and merging stays with people.

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
4. **PR.** Skip this when a PR already exists for the branch. Write the description to `<run folder>/pr-<repo-key>.md` (on its own: a temporary file), then pick the host from `git remote get-url origin`:
   - **`bitbucket.org`**: Atlassian MCP `executeWrite` with `createBitbucketRepoPullRequest`. Pass `workspaceId` and `repoId` (both from the URL), `title`, `sourceBranch`, `targetBranch`, `description`, and `draft: true`. If the operation rejects its inputs, run `discover` on it and retry once with the inputs it lists.
   - **`github.com`**: `gh pr create --draft --base <target> --head <branch> --title "<title>" --body-file <run folder>/pr-<repo-key>.md`.
   - **Any other host**: print the create-PR link for the user.

   **Title:** `<scope>(<KEY>): <summary>`, or `<scope>: <summary>` for free-text runs.

   **Description:** at most 5 non-blank lines, no headings:

   ```
   <One sentence: what was wrong or needed, and what this changes.>

   - <change>
   - <change>

   Tested: <what ran>. Not run: <check> (<why>).
   ```

   - Add a line `Assumption: <x>` or `Merge after: <PR link>` only when one applies, and cut bullets to stay within 5 lines.
   - Leave out warstack, iterations, reviewers, run ids and local paths.
   - Multi-repo: once every PR exists, add each one's `Merge after:` line (`updateBitbucketRepoPullRequest`, or `gh pr edit`).
5. **CI.** Use the CI named in repo memory (`ci:` in `profile.md`). If it is unknown, look for the pipeline the push started:
   - Bitbucket Pipelines: `listBitbucketRepoPipelines` for the branch, newest first.
   - GitHub: `gh pr checks <branch>`.

   If nothing starts within 10 minutes, set `ci: none` in `state.md`. Write `ci: none` into repo memory only when the repo has no CI config at all (no `bitbucket-pipelines.yml`, `.github/workflows/` or `Jenkinsfile`), and never overwrite a known CI because its tool is missing here. Otherwise wait for the result with as few turns as the tool allows, 45 minutes at most:
   - GitHub: `gh pr checks <branch> --watch --fail-fast` as one background command; it exits when the checks finish.
   - Bitbucket Pipelines: no CLI, so poll `getBitbucketRepoPipeline` with `responseFields: ["state"]` every 2 minutes, and wait between polls with a background `sleep 120`.

   Then act on the result:
   - **green**: done.
   - **red, in code or tests the change touches**: write the failure as a FAIL check into the current `iterations/<n>/tests.md`, with the failing step and its log path. For Bitbucket, get the steps with `listBitbucketRepoPipelineSteps`, then the log with `getBitbucketRepoPipelineStepLog`. Then go back to the loop while budget remains, otherwise stop.
   - **red, in code the change does not touch**:
     - the target moved: go back to step 2 (merge), push, and watch again;
     - the target did not move: the failure is already on the target. Report it under Attention, and leave the loop alone.
   - **infrastructure or flaky** (timeouts, runner errors, network): re-run it once, with `runBitbucketRepoPipeline`, or with `gh run rerun <actions-run-id> --failed` (the id comes from `gh run list --branch <branch>`). The same failure twice is not flaky: treat it as red.
6. **Record** `pr` and `ci` in `state.md`, and a `DECISION` line for each choice that was not obvious.

Done when: every repo's branch is pushed and has a draft PR (or a printed link), and each CI result is green, none, or reported.

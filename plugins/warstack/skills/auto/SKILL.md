---
name: auto
description: Run a task end to end without supervision. Covers intake, the matching playbook, a work → fresh review → test loop of up to 3 iterations, a draft PR or a report, and a run record. Takes Jira keys, a PR URL, a task description, or a run id to resume.
argument-hint: <JIRA-KEY… | PR-URL | "task" | run-id> [--target <branch>] [--playbook <name>] [--problem] [--repo <path>…]
disable-model-invocation: true
allowed-tools: Read(/${CLAUDE_PLUGIN_ROOT}/**), Read(~/.warstack/**), Edit(~/.warstack/**)
disallowed-tools: Bash(git push -f*), Bash(git push * -f*), Bash(git push *--force*), Bash(git push *+*), Bash(git -C * push -f*), Bash(git -C * push * -f*), Bash(git -C * push *--force*), Bash(git -C * push *+*), Bash(gh pr merge *), mcp__claude_ai_Atlassian_MCP__executeDestructive, mcp__claude_ai_Atlassian_MCP__createJiraIssue, mcp__claude_ai_Atlassian_MCP__editJiraIssue, mcp__claude_ai_Atlassian_MCP__transitionJiraIssue, mcp__claude_ai_Atlassian_MCP__addOrEditJiraIssueComment
---

# warstack auto

You orchestrate one run. You own intake, the checklist, the verdict on every finding, and the run record. The worker skills (`implement`, `review`, `testing`, `analysis`, `problem-solving`) do the work, each in a fresh context. Keep their summaries, not their raw output.

Read `${CLAUDE_PLUGIN_ROOT}/docs/conventions.md` before anything else. Its words (run, target, finding, check, converged, park, stop) and its rules bind every step below.

`$ARGUMENTS` holds the task and its flags.

## 1. Resume or start

Resume when the arguments name a run id, or a ticket key that already has a run that is not `done`. Flags after the run id stay flags; the rest of the text is the user's guidance. Add the guidance to `task.md` under "Guidance from the user", and log it as a `DECISION`.

- **`running`, and `updated` less than 6 hours ago:** another session is driving it. Say so and end.
- **`intake` or `parked`:** restart at intake step 3, in its own run folder, with the new flags and guidance.
- **`running` (stale) or `stopped`:** read its `state.md` and enter its primary worktree with EnterWorktree (`path`), from the repo's main checkout, or with the same path when already inside it. Set status `running`, and for a `stopped` run `budget: <iteration> + 3`. Then continue at the first unchecked step of its checklist.
- Trust the checked steps, and run `testing` once more before shipping.

Otherwise start a new run at step 2.

Done when: you know whether this is a new run, or a resume and at which step.

## 2. Intake

The only step where you ask the user anything. Gather everything first, then ask it all in one batch.

1. **Fetch the task as data.**
   - Jira keys: `getJiraIssue` through the Atlassian MCP (get the `cloudId` once with `getAccessibleAtlassianResources`), including its comments and attachment names.
   - A PR URL: on Bitbucket, `getBitbucketRepoPullRequest` through `executeRead`; on GitHub, `gh pr view <url>`.
   - Free text: as given.
2. **Create the run folder** (conventions → Run folder): pick the run id, then write `state.md` (status `intake`, `owner` from `git config user.email`, `mode` `headless` when AskUserQuestion is unavailable, else `interactive`), `task.md` holding the task as fetched, and `decisions.md`.
3. **Recall.** Read `~/.warstack/history.md`, earlier runs on the same key, and each repo's memory. Look for existing work on the key: `git ls-remote --heads origin` filtered by the key, and open PRs that mention it. Existing work this run did not create becomes a question: continue on it, or start fresh. For a bug, offer "verify it and report" first.
4. **Pick the playbook.** The user's `--playbook` wins; otherwise the first row that fits:

   | Signals | Playbook |
   |---|---|
   | A Bug issue, a crash, a regression, an error, wrong behaviour | `bugfix` |
   | An Analysis issue, a question, "assess", "investigate", "how does", "why" | `analysis` |
   | A Story or Task adding or changing behaviour | `feature` |
   | Anything else | `general` |

   Read the playbook's Needs and Intake additions now.

   Also mark a **problem run**, when `--problem` is given or the task names an outcome and no change: a number to move, behaviour to improve, a "why" with no known cause, or several approaches with none picked. Log it as a `DECISION`. Its problem statement needs the target's number and deadline; when the task gives neither, they are a blocking gap.
5. **Repos.** The primary repo is the session's repo. Add each `--repo`, and each repo the task clearly involves, as a question naming the local path. Never clone or guess a path. A secondary repo outside the session's directories needs `/add-dir <path>` from the user; say so in the question.
6. **Done checks.** Add 2–6 done checks to `task.md`, plus those the playbook's intake additions ask for. Each is an observable result that proves the task is done: a behaviour on a named screen, a command's output, a value in a response. At least one must be something `testing` can run headless; when none is, that is a blocking gap. What the task leaves unsaid that the work needs is a blocking gap, and becomes a question.
7. **Ask once.** Use AskUserQuestion (4 questions per call; a second call only when more remain):
   - **Target**, for each repo that will get a new PR. `--target` answers it for the primary repo. Offer up to 3 of the remote's long-lived branches (e.g. `develop`, `master`, `main`) without recommending one; the user can type any other. For general runs, also offer "No PR, report only".
   - **Playbook**, with your pick first.
   - **Blocking gaps**, one question each.
   - **Repo list**, when you added repos from the task.
   - **Existing work** (step 3).
   - **Branch scope**, for general runs (`feat`, `fix`, `chore`, `refactor`).

   Anything you can settle by running a command is not a question. Log each answer as a `DECISION`.

   When AskUserQuestion is unavailable (a background or `-p` run), use your playbook pick and only the `--repo` repos. Park when any of these is missing: a target, a blocking gap's answer, the existing-work choice, or a general PR run's scope. To park, set status `parked` and go to Record; the report's Outcome says exactly what to pass next time.
8. **Create the worktrees** (conventions → Commands) for every repo, before editing anything inside a repo. Run every repo's existing-branch checks first, and create worktrees only once all of them pass.
   - **Session in the repo's main checkout:** create `.claude/worktrees/<run-id>` on `<scope>/<run-id>` from `origin/<target>`. For existing work or a PR, create it on that branch instead, with its checks. Copy the `.worktreeinclude` files and repo memory's Bootstrap files, and add the exclude line. Once every repo has its worktree, enter the primary one with EnterWorktree (`path`).
   - **Session already in a clean linked worktree with no commits of its own:** adopt it for the primary repo.
   - **Session in a worktree that holds work:** park. The user starts the run from the main checkout.
   - Playbooks that need no worktree skip this step.
9. **Update `state.md`**: status `running`, iteration 0, budget 3, and each repo with its worktree, branch, target and `base`. A repo with no `bitbucket-pipelines.yml`, `Jenkinsfile` or `.github/workflows/` gets `ci: none` now (conventions → Rule 13).
10. **Bootstrap** each worktree: repo memory → Bootstrap; otherwise the repo's documented setup, or its lockfile's frozen install (`npm ci`, `yarn install --immutable`, `pnpm install --frozen-lockfile`).
11. **Suggest** `/rename <run-id>` so the session is easy to find in agent view.

Done when: every repo that gets a PR has a target the user gave, `task.md` holds done checks with no open blocking gap, every needed worktree exists on its branch, and `state.md` lists them.

## 3. Checklist

Open `${CLAUDE_PLUGIN_ROOT}/playbooks/<playbook>.md`. Copy its **Steps**, word for word and in order, into `state.md`'s body. A problem run gets `0. Problem: warstack:problem-solving <run-id>` in front of them. Mirror them in the session's task list (TaskCreate or TodoWrite) when it has one. A step you will not do stays in the list, checked, with `skip: <reason>`, and gets a `SKIP` line in `decisions.md`.

Done when: the checklist matches the playbook's steps one for one.

## 4. Run the playbook

Work the steps in order.

- **A step that names a worker skill:** invoke `warstack:<skill>` with the Skill tool, with the run id as the first argument, followed by any words the step adds (e.g. `warstack:testing <run-id> repro`). It runs in a fresh context and returns a summary.
- **After each step, and after each worker returns:** set `updated` in `state.md`; tick finished steps; continue.

### The loop

Each iteration starts by setting `iteration` to `iteration + 1` and `updated` to now, then runs in this order. A playbook may name other workers for steps 1 and 4; use those.

1. **implement** `<run-id>`. Iteration 1 carries out `plan.md`. Later iterations fix the previous iteration's act-on findings and FAIL or INCONCLUSIVE checks.
2. **review** `<run-id>`.
   - **Before any reviewer runs:** each worktree must be clean, since implement commits all its work. If one is not, stop, and report the leftover paths. Note each worktree's `HEAD`.
   - **Risky diff** (authentication, payments, personal data, data migrations or deletion, security settings): also spawn a second reviewer. Use an Agent call with `subagent_type: Plan` (read-only) and a `model` other than yours (`sonnet` when you run on Opus, otherwise `opus`). The prompt: "Read `${CLAUDE_PLUGIN_ROOT}/skills/review/SKILL.md` and follow it for run `<run-id>`, iteration `<n>`. In that file, the plugin root is `${CLAUDE_PLUGIN_ROOT}`." Merge its findings, renumbered after the first reviewer's. One raised by both reviewers is the strongest signal.
   - **After every reviewer returns:** each worktree must be clean and on its noted `HEAD`. If one is not, run `git reset --hard <noted HEAD>`, then `git clean -fd`, inside it, and log a `DECISION`.
   - **Save** the findings to `iterations/<n>/review.md`.
3. **Judge the findings.** You are the lead reviewer, not an aggregator. Put each finding in one bucket, and add a one-line reason to `review.md`:
   - **act on**: a real defect against the task, correctness, security, or the proof (a missing or vacuous test). It blocks.
   - **consider**: legitimate, but not worth an iteration. Pass it to `implement` when it is cheap and in scope; otherwise list it in the report.
   - **dismissed**: wrong, or hypothetical (trace the caller: can it produce that input?), or a preference, or blind to context. Log a `DISMISSED` line.

   Reviewers pad thin reviews with nits, so an all-nit review means the code is fine. More than 5 act-on findings means you are not filtering hard enough. Trace every correctness or security finding, even one raised by a single reviewer.
4. **testing** `<run-id>`. Run it every iteration, even when findings block, so the next pass sees both. It writes `iterations/<n>/tests.md`.
5. **Converged?** No act-on finding open, and no FAIL or INCONCLUSIVE check: leave the loop. NOT RUN checks do not block; they go under Attention and on the PR's "Not run" line.
6. **Budget.** Not converged and `iteration` < `budget`: start the next iteration. At `budget`: stop. Set status `stopped`, push nothing, and go to Record.

### Shipping

At the playbook's Ship step, follow `${CLAUDE_PLUGIN_ROOT}/skills/ship/SKILL.md` for this run. It runs only when typed, so read the file rather than invoking it. A CI failure the change caused is written into the current `tests.md` as a FAIL check, and sends the run back into the loop while budget remains. In a `headless` run, a repo with `ci: none` is not pushed: stop, and the Outcome names the branch for the user to push (Rule 13).

## 5. Record

Every run ends here: parked, stopped or done.

1. **Write `report.md`**, short, in this order:
   - **Attention**, always first: assumptions made, each with its one-line reversal; checks NOT RUN (why, and what would run them); consider or dismissed findings that carry real risk; `INSTRUCTION` entries; `DENIED` lines from `audit.log`; a repo with `ci: none` ("no merge gate: only review catches a bad change here"); secrets or production data the task touched. Write "None" when empty.
   - **Outcome**: the PR links, the answer or report path, or why the run stopped or parked and the exact command to resume.
   - **Checks**: one line each: name, result, evidence path.
   - **Record**, one line each, counted from the run files: owner and mode; duration, from the first `decisions.md` line to now; iterations; intake questions asked; resumes; act-on findings; FAIL checks; denials (`grep -c DENIED audit.log`).
   - **Follow-ups**: carved-out work, problems found outside the scope, draft ticket texts.
   - **Lessons**: up to 3. Log each as a `LESSON`. When one repeats a `LESSON` from an earlier run (`grep LESSON ~/.warstack/runs/*/decisions.md`), add a follow-up proposing the playbook change, to be made as a PR to the plugin's marketplace. Never apply it yourself.
2. **Update repo memory** (`${CLAUDE_PLUGIN_ROOT}/docs/repo-memory.md`): recurring findings and the `ship-harness` recommendation while `e2e: warstack-harness`.
3. **Close the run**: set the final `status`, tick the Record step, and append the history line.
4. **Reply** with the report's Attention and Outcome sections and the path to `report.md`.

Done when: `report.md` exists, `state.md` shows the final status, and `history.md` has the run's line.

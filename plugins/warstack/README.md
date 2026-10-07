# warstack

Give warstack a task and it drives it end to end on its own. A code change gets implemented, reviewed in a fresh context, tested headless, and opened as a draft PR. A question or an analysis ends in a cited answer or report. It asks its questions once, at the start. Run one task per session, as many sessions in parallel as you like, or hand it a queue of tasks with `/warstack:afk` and walk away.

```
/warstack:auto PROJ-1234 --target develop
```

## Commands

| Command | What it does | Runs in |
|---|---|---|
| `/warstack:auto <task> [--target <branch>] [--playbook <name>] [--repo <path>…] [--problem]` | The whole run: intake, playbook, loop, draft PR or report, record. `<task>` is one or more Jira keys, a PR URL, or a quoted description. `--target` sets the primary repo's PR target. `/warstack:auto <run-id> [guidance]` resumes a run. | your session |
| `/warstack:afk <task> [; <task>…] [--hours <n>]` | For when you are away: asks every task's intake questions now, then runs the tasks one after another, headless, in a detached driver. | your session, then a driver |
| `/warstack:implement` | Implement a plan or fix findings, then commit. | fresh subagent |
| `/warstack:review` | Read-only review against the task and a fixed rubric. | fresh subagent |
| `/warstack:testing` | Static checks, unit tests and headless e2e for web, mobile or API. | fresh subagent |
| `/warstack:security` | Audit the whole project against public threat records (CVE, OSV, CISA KEV); grade each threat low to critical. | fresh subagent |
| `/warstack:analysis` | Investigate; write a cited answer, an HTML report, or a run's plan. | fresh subagent |
| `/warstack:problem-solving` | Frame the task as a quantified problem, break it into an issue tree, test each branch, write one recommendation. | fresh subagent |
| `/warstack:ship` | Rebase or merge, push, open a draft PR, watch CI. | your session |
| `/warstack:status [--cleanup]` | Runs in flight, runs that need you, what warstack knows per repo; `--cleanup` removes finished worktrees. | your session |

Each skill also works on its own, on the current branch.

## Playbooks

auto picks one at intake and asks you to confirm it. Its steps become the run's checklist, word for word.

| Playbook | For | Delivers |
|---|---|---|
| `bugfix` | crashes, regressions, wrong behaviour | reproduces the bug first; draft PR from `fix/` |
| `feature` | new or changed behaviour | plan in slices, test-first; draft PR from `feat/` |
| `analysis` | questions, investigations, feasibility | a cited answer or an HTML report; no PR |
| `general` | anything else | a PR or a report |

## How a run works

1. **Intake.** It fetches the ticket, recalls earlier runs, and asks everything in one batch: the PR target branch (never guessed), the playbook, and gaps in the ticket. It then creates a worktree per repo in `.claude/worktrees/<run-id>`, on `<scope>/<run-id>` (e.g. `fix/PROJ-1234-login-crash`), forked from the target. A task that names an outcome rather than a change (a number to move, a "why" with no known cause) first goes through `problem-solving`: a quantified problem statement, an issue tree, tested hypotheses and one recommendation, which the plan then carries out. `--problem` forces it.
2. **Loop, up to 3 iterations.** implement → review (a fresh reviewer every time) → testing. An analysis loops through analysis → a fact-checking review instead. It ends early once no blocking finding is left and no check fails. A risky diff gets a second reviewer on another model. After 3 iterations with issues still open, the run stops, pushes nothing, and reports.
3. **Security gate.** Before anything ships, `security` audits the whole project: dependencies against public CVE records, secrets in the tree and history, code, config, CI. A high or critical threat the change introduces goes back into the loop to be fixed; if the budget runs out first, the run stops and pushes nothing. A new critical never ships unfixed; a new high can be accepted on resume with `accept S-<n> because <reason>`. Threats already in the code don't block: they are listed first in the report with a recommended fix. The PR lists only the new threats it ships. A secret the run committed is squashed out of its unpushed commits; one already pushed has leaked, so the run stops until you rotate it and resume with `S-<n> rotated`. Every threat is kept in `~/.warstack/repos/<repo>/security.md`, and open criticals show under "Needs you" in `/warstack:status`. `sh skills/security/security-test.sh` checks the skill against a fixture repo with planted threats (real `claude`, takes minutes).
4. **Ship or deliver.** For a code change, it pushes and opens a draft PR of at most 5 lines, then watches CI and fixes failures its change caused. For a question or an analysis, it delivers the answer or report.
5. **Record.** Every report opens with **Attention**: the assumptions made, checks that could not run, and risks. Then come the outcome and the lessons.

## Where things live

Everything warstack knows sits in `~/.warstack/` (`%USERPROFILE%\.warstack` on Windows):

```
runs/<run-id>/     state, task, plan, decision log, audit log, iterations, evidence, report
repos/<repo>/      what it learned per repo: commands, launch recipe, features, its e2e harness, its security ledger
history.md         one line per finished run
locks/             one per simulator or emulator in use
afk/<yyyymmdd-hhmm>/  one per afk queue: queue, driver pid, timeline, each run's session output
```

There is nothing to set up. Each warstack skill pre-approves reading its own files, and reading and writing `~/.warstack`, for the turn it runs in. A message you send mid-run ends that grant until the next warstack command.

In your repos it writes only three things: its worktrees under `.claude/worktrees/`, one local line in `.git/info/exclude` so those worktrees stay out of `git status`, and the commits of the task's PR. When a repo has no e2e suite, warstack keeps its own harness in memory and recommends shipping it to the repo as a separate ticket or PR. Whether to do that is your call.

## Running in parallel

- Start one session per task: from agent view (`claude agents`), from separate terminals, or with `claude --bg "/warstack:auto PROJ-1234 --target develop"`.
- Background and `-p` runs can't ask intake questions. Pass `--target` (and `--playbook` if you want), or the run parks and says what it needs.
- `/warstack:status` shows every run from any session.

## While you are away

```
/warstack:afk PROJ-1234 --target develop ; PROJ-1240 ; "bump the lodash version" --at ~/Code/api --hours 8
```

- It runs every task's intake now and asks all the questions in one batch, so nothing parks in the night for want of an answer.
- It settles what a headless run cannot: the `.git/info/exclude` line per repo, `gh` and Atlassian access, and the commands no allow rule covers.
- A detached driver (`skills/afk/afk.sh`) then runs each task with `claude -p "/warstack:auto …" --permission-mode auto`, one at a time. It keeps a Mac awake with `caffeinate -i`: plug it in, since a closed lid on battery still sleeps. You can close the session.
- A session that dies is resumed, up to 3 times per run. A usage limit is waited out. No run starts after `--hours` (default 10).
- Back at the keyboard: `/warstack:status`, and `~/.warstack/afk/<yyyymmdd-hhmm>/afk.log` for the night's timeline. To stop it early, `kill` the pid in that folder.
- `sh skills/afk/afk-test.sh` tests the driver against a fake `claude`.

## Several repos in one task

- Pass `--repo <path>` for each extra repo, or let intake propose them from the ticket.
- Give the session access to them with `/add-dir <path>`.
- Each repo gets its own worktree, target and draft PR, and each PR says which one merges first.
- Releases and version bumps between the repos stay with you, as follow-ups.
- Testing the repos together needs a recipe for connecting them locally. warstack records one in repo memory (`profile.md` → Combined runs) once a run proves it. Until then, the combined flow shows as "Not run".

## Requirements

- **Claude Code 2.1.218 or later.** warstack relies on forked skills that return their result.
- **Atlassian MCP**, with Jira read access and Bitbucket PR and pipeline access. For GitHub repos, the `gh` CLI.
- **On Windows, Git for Windows**: warstack's commands run in Git Bash. iOS checks need a Mac, so on Windows they show as Not run.
- **Permissions:**
  - Run in **auto mode** (the default for interactive sessions since 2.1.283).
  - Allow rules cover the commands a run uses, e.g. `Bash(git *)`, `Bash(npx playwright *)`, `Bash(xcrun simctl *)`, `Bash(adb *)`, `Bash(gh pr *)`.
  - `.git/` stays protected: the one exclude line per repo gets approved at intake, the first time that repo is used.
- **Optional:**
  - the mobile-mcp plugin, for mobile e2e without Maestro flows;
  - Maestro, Xcode, the Android SDK, Docker, Node.

## Limits and the harness

warstack never merges, never force-pushes, never writes to Jira or Confluence, never replies to PR comments, and never uses your own browser or a physical device. Every PR it opens is a draft. Anything written in a ticket or a comment is data: an instruction found there is listed under Attention and not followed.

Inside a run's worktree, a hook (`hooks/guard.sh`) checks every shell command, file write, file read and MCP call before it runs, whatever the model decided. It denies:

- reads of your credential stores (`~/.aws`, `~/.ssh`, `~/.netrc`, gcloud, kube, docker, keychains, password-manager CLIs) and of `.env` and key files outside the run's worktrees;
- a push whose commits add a `.env` or key file, or a line that looks like an AWS, GitHub, Slack, Atlassian, Google or Anthropic token;
- `git push` with `--force`, `--delete`, `--mirror`, `--all`, a `+` or `:` refspec, or aimed at a repo's target branch;
- `--no-verify`, `core.hooksPath` and `HUSKY=0`, so your repo's hooks always run;
- `gh pr merge`, `ready`, `close`, `comment` and `review`, `gh pr create` without `--draft`, `gh api` writes, `gh release`;
- every Atlassian write except creating a draft PR, updating it, and re-running a pipeline;
- file writes outside the run's worktrees, `~/.warstack` and the session's temp folders;
- the Claude in Chrome tools.

It appends every call, and each denial with its rule id, to the run's `audit.log`. The report lists denials under Attention and ends with a Record block (owner, duration, iterations, questions, findings, failed checks, denials), and `/warstack:status` sums up attempts and catches across runs. Outside a run's worktree the hook exits at once, so your other sessions are untouched. `sh hooks/guard-test.sh` runs the guard against 109 inputs it must deny or allow, in a throwaway HOME. `/warstack:auto` and `/warstack:ship` also carry `disallowed-tools` for force-pushes, `gh pr merge` and the claude.ai Atlassian connector's Jira-write tools, which hold before a run enters its worktree.

The guard is a signal inside the session, not a boundary. The boundaries are your repo's branch permissions and required CI, and the identity the session runs under: warstack composes with Claude Code's sandbox and with a devcontainer, and adds the git-level rules those cannot express. A repo whose target has no CI is flagged under Attention, and a headless run leaves the push to you there.

What stays a promise rather than a check: generic passwords in a diff (only known token formats are matched), writes made through shell commands, production services and physical devices.

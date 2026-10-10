---
name: afk
description: Queue warstack runs for while you are away from the keyboard (afk), overnight or for hours. Asks every task's intake questions now, in one batch, settles what a headless run cannot, then hands the queue to a detached driver that runs each task through /warstack:auto headless, one after the other, resuming sessions that die or hit a usage limit.
argument-hint: <task> [; <task>…] [--hours <n>]   (each task as for /warstack:auto, plus --at <checkout>)
disable-model-invocation: true
allowed-tools: Read(/${CLAUDE_PLUGIN_ROOT}/**), Read(~/.warstack/**), Edit(~/.warstack/**), Write(~/.warstack/**)
disallowed-tools: Bash(git push *), Bash(git -C * push *), Bash(gh pr create *), Bash(gh pr merge *), Bash(gh issue comment *), Bash(gh issue close *), Bash(gh issue edit *), Bash(gh issue delete *)
---

# warstack afk

The user is about to leave. Everything that needs them happens now, in this session: every task's intake questions, and every approval a headless run cannot get. Then a detached driver (`afk.sh`) runs each task through `/warstack:auto` headless, one after the other, and this session is free to close. You do no task's work here: no worktree, no code, no push.

Read `${CLAUDE_PLUGIN_ROOT}/docs/conventions.md` and `${CLAUDE_PLUGIN_ROOT}/skills/auto/SKILL.md` before anything else.

## 1. Tasks

`$ARGUMENTS` holds tasks separated by ` ; `, in queue order. Each is written as for `/warstack:auto`, plus `--at <checkout>` when its primary repo is not this session's repo. `--hours <n>` (default 10) covers the whole queue: no run starts after it.

This session must be in a main checkout, not in a worktree: intake runs git against every task's checkout. If it is in a worktree, say so and end.

Done when: you have the ordered task list, each with its primary checkout.

## 2. Intake, every task at once

For each task, follow auto's §1 and §2 steps 1–7, with the task's `--at` checkout (or this session's) as its primary repo, and these differences:

- **A run id or an issue with a run** (auto §1): only a `stopped` or `parked` run joins the queue, as a resume. A `running` run is driven elsewhere, and a `done` one is done: say so and leave it out.
- **Step 2:** `mode: headless`.
- **Step 7:** gather every task's questions first, then ask them together, 4 per AskUserQuestion call, each naming its run id. An answer asking to drop the task leaves it out of the queue.
- **Existing work** the user chose to continue: run step 8's existing-branch checks now, so a park shows up while the user is here.
- **Stop before step 8.** Write each task's answers into its `task.md` under "Guidance from the user", log each as a `DECISION`, and set status `parked`. The driver resumes it with the answers as flags, and auto restarts at intake step 3 with nothing left to ask.

Done when: every queued run is `parked` with no open question, and every task left out is named with its reason.

## 3. Preflight

What a headless run would fail on at 3am, settled now:

1. **Exclude line** (conventions → Commands), once per repo. `.git/` is protected, and a headless run cannot get that approval.
2. **Access.** `gh auth status`: warstack supports GitHub only, for repos and issues. A failure is the user's to fix now; nothing starts without it.
3. **Permissions.** The driver runs `claude -p --permission-mode auto`: a call the classifier refuses is denied, not asked. From repo memory (`profile.md`: Bootstrap, test and e2e commands), plus `gh pr *` and `gh api *` (ready, review comments and merge), list the commands no allow rule in `~/.claude/settings.json` or the repo's `.claude/settings*.json` covers, and offer the rules that would. Without them, a run's PR stays open and unmerged. Add only the ones the user accepts.
4. **Power.** On macOS, the driver holds `caffeinate -i`, which does not keep a Mac with its lid closed awake on battery: when `pmset -g batt` says "Battery Power", tell the user to plug in. Elsewhere, tell them the machine must not suspend.

Done when: every repo has its exclude line, every service answers, and the user has seen the uncovered commands.

## 4. Launch

1. **Folder:** `<TS>/afk/<yyyymmdd-hhmm>/`. Write `queue.tsv` with the Write tool, one line per run, fields separated by a tab: `<checkout>	<run-id>	<run-id> --target <t> [--playbook <p>] [--repo <path>…] Intake answered in /warstack:afk; see Guidance from the user.` A resumed `stopped` run's third field is its run id alone.
2. **Start the driver**, detached so it outlives this session:

   ```bash
   nohup sh "${CLAUDE_PLUGIN_ROOT}/skills/afk/afk.sh" "<afk folder>" <hours> > /dev/null 2>&1 &
   ```

3. **Check it started:** `cat "<afk folder>/afk.log"` shows `START`, and `<afk folder>/pid` holds its pid.

Done when: the driver's `START` line is in `afk.log`.

## 5. Reply

- The queue: run ids in order, each with its target.
- Tasks left out, and why.
- Back at the keyboard: `/warstack:status` for what needs you, and `<afk folder>/afk.log` for the timeline (one line per start, finish, death and wait; each run's session output is in `<run-id>.log`).
- To stop: `kill $(cat "<afk folder>/pid")`. It ends the current run's session too and leaves that run `stopped`; resume it with `/warstack:auto <run-id>`.

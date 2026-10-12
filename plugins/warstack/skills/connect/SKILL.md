---
name: connect
description: Set up, or show, how warstack talks to your git host and issue tracker (GitHub, GitLab, Bitbucket, Azure DevOps, Jira, Linear…), through a CLI or an MCP server you already use. Asks which provider the project runs on, works the commands out from your setup, and saves them once you confirm. Runs the first time warstack needs a provider, and when typed.
argument-hint: [host | tracker | show | <connector-id>]
disable-model-invocation: true
effort: medium
allowed-tools: Read(/${CLAUDE_PLUGIN_ROOT}/**), Read(~/.warstack/**), Write(~/.warstack/connectors/**), Edit(~/.warstack/connectors/**)
---

# warstack connect

warstack is provider-agnostic. Everything it does with a git host or a tracker goes through a connector: `<TS>/connectors/<id>.conf`. Read `${CLAUDE_PLUGIN_ROOT}/docs/connectors.md` (the file format and the operations) and `${CLAUDE_PLUGIN_ROOT}/connectors/github.conf` (the reference) first, and `${CLAUDE_PLUGIN_ROOT}/docs/conventions.md` for Rule 2 (secrets by name) and Rule 3.

Typed on its own, or followed from auto's intake, this skill asks its own questions first: intake cannot fetch the task without a connector. In a headless run it asks nothing: the run parks and says to type `/warstack:connect`.

## Input

- **Nothing, `host` or `tracker`**: set up what is missing. The host comes from `git remote get-url origin`; the tracker is asked.
- **`show`**: list `<TS>/connectors/*.conf` and the bundled one, each with its `match`/`ref`, `via`, `tool`, and which ops it maps. Change nothing.
- **A connector id**: redo that connector.

## Steps

1. **What exists.** A host connector is missing when no file in `<TS>/connectors/` has a `match` found in `origin`'s URL. A tracker connector is missing when the user's tracker (asked, or implied by the task reference) matches no file's `ref`. Nothing missing: say so and end.
2. **Ask which provider** (AskUserQuestion), with the detected one first:
   - the code host: GitHub, GitLab, Bitbucket, Azure DevOps, other;
   - the issue tracker: the host's own, Jira, Linear, other.

   Ask nothing when the answer is already clear (a `github.com` origin and a `#12` task are GitHub).
3. **Find how this machine talks to it.** Look, and never read a secret's value (Rule 2):
   - **CLIs:** `command -v` for the provider's usual tools (`gh`, `glab`, `bb`, `az`, `jira`, `linear`…), then its auth status command.
   - **MCP servers:** the tools of this session whose names carry the provider (`mcp__*`).
   - **Credentials:** only the names of environment variables that look like the provider's tokens (`env | cut -d= -f1`), to tell the user what exists. Never print or open a value, a credential file or a keychain.

   Prefer a signed-in CLI, then an MCP server already connected. With only an API token and no CLI, say so: a hand-written `curl` mapping is possible, but the user has to ask for it and accept that the token's reach is the boundary. Nothing usable: say what to install or connect, and end.
4. **Draft the mapping.** Start from the bundled `github.conf` when the provider is GitHub; otherwise write the file from `docs/connectors.md`, with the tool's own `--help` as the source of every command. Map each op the provider supports. Leave out the ones it lacks; do not invent a command to fill a gap.
   - Writes: the host's draft flag in `opt.pr.create.require`; the bypass flags in `opt.pr.merge.forbid`.
   - Reads built on a generic API call must not be able to write: no method flag, no body.
   - `ref`, `link`, `ci-config`: from the provider's conventions.
5. **Prove the reads.** Run `auth.check`, and `issue.read` and `pr.read` on a real issue and PR of this project when there are any. A read that fails is fixed or left out. Writes are not run: show them to the user instead.
6. **Confirm.** Show the draft (AskUserQuestion, with the file's content in the question): which ops are mapped, which are missing and what that costs (no draft PRs, no resolvable threads, no CI watch), and the write ops word for word. Save nothing before a yes.
7. **Save** `<TS>/connectors/<id>.conf` with the Write tool. Nothing else records the choice: later runs find the connector by `match` and `ref`.

Done when: every connector this project needs is a confirmed file whose reads ran, or the user was told what is missing and nothing was saved.

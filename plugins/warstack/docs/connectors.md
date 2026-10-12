# Connectors

A connector tells warstack how to talk to one git host or issue tracker: through which CLI or MCP server, with which commands. warstack never assumes a provider. It asks once, works out the commands from the user's setup, and keeps them in `<TS>/connectors/<id>.conf` once the user confirmed them. The guard enforces the rules of Rule 3 through these files, so every provider gets the same safety as GitHub.

`${CLAUDE_PLUGIN_ROOT}/connectors/github.conf` is the reference (GitHub through `gh`). Copy its shape; do not copy its commands for another provider.

## File

Plain lines, `key: value`. `#` starts a comment line.

| Key | Meaning |
|---|---|
| `match` | A host connector only: the text in a repo's `origin` URL that selects it (`github.com`). |
| `via` | `cli` or `mcp`. |
| `tool` | `cli`: the executable (`gh`). `mcp`: the tool-name prefix (`mcp__atlassian__`). Every call to it goes through the ops below. |
| `ref` | A tracker connector, or a host with issues: an ERE a task reference matches (`#12`, `PROJ-123`, an issue URL). |
| `link` | Text for the PR description that closes or links the task on merge (`Closes <owner>/<repo>#<number>`, `PROJ-123`). Omit it when the tracker has none: the task is then left open and the report says so. |
| `ci-config` | Paths whose absence means the repo has no CI (`.github/workflows`). Omit it when unknown. |
| `op.<name>` | An operation: the command, or for MCP the tool's exact name. |
| `opt.<name>.require` | Words the call must contain (`--draft`). |
| `opt.<name>.forbid` | Words the call must never contain (`--admin`); a single-letter flag also matches inside a cluster (`-sd`). |

## Operations

A call to a connector's CLI or MCP tools that matches none of its `op` lines is denied. Reads and writes alike must be mapped.

A template is a list of words. The leading words, up to the first flag or `<value>`, must equal the call's. Every other fixed word must appear in the call, in any order, and extra words are allowed. `<name>` is a value the caller fills in. Write templates shell-ready (quoted as they should be run). `<thread>` is special (see `thread.resolve`).

| Op | Does | Rule the guard applies |
|---|---|---|
| `auth.check` | exits 0 when signed in | read-only |
| `issue.read <issue>` | the issue with its comments, as JSON | read-only |
| `pr.read <pr>` | title, body, base ref, head commit, changed files | read-only |
| `pr.diff <pr>` | the PR's diff | read-only |
| `pr.list` | PRs by search or branch | read-only |
| `merge.methods` | which merge methods the repo allows | read-only |
| `ci.checks <branch>` | the branch's checks, once | read-only |
| `ci.watch <branch>` | blocks until the checks finish, fails fast | read-only |
| `ci.runs` | CI runs of a branch | read-only |
| `ci.log <run>` | the failed steps' log | read-only |
| `ci.rerun <run>` | re-runs the failed jobs | none (once, for a flaky failure) |
| `threads.list` | a PR's review threads: id, state, file, line, comments | read-only |
| `file.read` | a file at a ref, without a checkout | read-only |
| `pr.create` | opens a PR | needs every word in `opt.pr.create.require`: map the host's draft flag there |
| `pr.edit <pr>` | edits a PR's description | the run's own PR only |
| `pr.ready <pr>` | takes a PR out of draft | the run's own PR only |
| `pr.merge <pr>` | merges a PR | the run's own PR only, none of `opt.pr.merge.forbid` (bypasses of the target's rules, deleting the branch) |
| `review.post` | one review with inline comments | the run's own PR only |
| `thread.reply` | replies on a review thread | the run's own PR only |
| `thread.resolve` | resolves a thread, with its id as `<thread>` | needs `thread.owner`; the thread must be on the run's own PR |
| `thread.owner` | prints the URL of the PR a `<thread>` belongs to | run by the guard itself |

Read-only ops never carry a non-GET method flag (`-X`, `--method`) or `--input`.

"The run's own PR" is one of the PRs in `state.md`. The call must name it by its URL, or by its repo path (`owner/repo`) and number, or, for MCP, by `owner`, `repo` and the number as separate values. Ops that act on a PR take the PR's URL wherever the provider allows it.

An op the provider lacks is left out, and so is its use: no `pr.ready` and no `require` for a host without drafts (the PR is then opened ready, and the report says so), no `thread.resolve` for one without resolvable threads (threads stay open and the run stops at pr-review's limit as usual). Nothing outside the table is ever mapped to a write: commenting on issues, closing, releasing and the like stay with the user.

## MCP connectors

`tool` is the prefix of the server's tool names, and each `op` is one tool's exact name. A tool of that prefix that no op names is denied. An op's arguments are free; the guard reads the whole input for the run's PR, and for `opt.*.require` words (`"draft":true`).

## Where connectors live

- `<TS>/connectors/*.conf`, one file per provider, written only by `/warstack:connect` or by auto's intake when it follows that skill, always after the user confirmed. A run never edits them, and the guard denies it.
- A repo's host connector is the one whose `match` is in its `origin` URL. A task's tracker is the connector whose `ref` matches the task reference; a host's own issues use the host connector.
- The guard also loads the bundled `github.conf` when the user has no connector for `gh`, so a GitHub setup is enforced before it is ever confirmed.

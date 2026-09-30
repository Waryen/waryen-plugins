# Repo memory

What warstack knows about a repo lives in `~/.warstack/repos/<repo-key>/`, never in the repo. `testing` reads it first and keeps it true, `auto` reads it at intake, and `status` shows it.

```
repos/<repo-key>/
├── profile.md
├── features/<feature>.md
└── e2e/
```

## profile.md

Front matter, which `status` reads:

```yaml
---
repo: github.com-acme-webapp
checkouts: [/Users/me/Code/webapp]
kind: web            # web | mobile | api | library | cli | mixed
e2e: none            # own-suite | warstack-harness | none
recipe_proven: ""    # date Launch → Evidence → Cleanup last ran end to end
ci: unknown          # bitbucket-pipelines | jenkins | github-actions | none | unknown
recommendations: []  # open suggestions for the user, e.g. ship-harness
---
```

Body sections, each a few bullets, each fact proven by a run (cite its run id):

- **Bootstrap**: install commands for a fresh worktree, and the gitignored files to copy from the main checkout.
- **Checks**: lint, typecheck and unit commands, and which ones are slow.
- **Launch**: the exact command that starts the app for verification, how to tell it is ready, how to stop it.
- **Health check**: one read-only check that the running instance is this app, this build, and started by this run.
- **Drive**: the harness and its headless command (the repo's suite path, or `e2e/` here), plus the stable handles: roles, labels, test ids, routes.
- **Evidence**: what proves behaviour, and how to capture it.
- **Isolation**: whether two runs can drive the app at once (ports, data directories, devices).
- **Combined runs**: per other repo this one works with, how to connect the two locally for a combined e2e check (a `file:` or yalc dependency, Metro `watchFolders`, local Pods or Gradle paths, an env var pointing at a local API).
- **Quirks**: gotchas that cost a run time, including files a build rewrites.
- **Recurring findings**: review findings seen in two or more runs here. `review` checks each change against them.

## features/<feature>.md

One file per user-facing feature a run has driven, written from the user's side:

```markdown
# <Feature>
<One paragraph: what the user sees.>

## How to get to it
## Driving it
Preconditions, then one bullet per action: the action → the exact command or selector → the observable result.
## What proves it works
## Gotchas
```

## e2e/

warstack's own harness, for a repo that has no e2e suite. Build it the way the repo would commit it: the stack's standard layout and config, and no machine-specific paths. Later runs reuse and extend it. While `e2e: warstack-harness`, keep `ship-harness` in `recommendations`, and every report suggests shipping the harness to the repo as its own ticket or PR. The user decides.

## Keeping it true

- Record what a run proved. Mark anything else `unproven`.
- Amend in place: rewrite a wrong line, and keep each section to a few bullets.
- When a recipe step fails because the app changed, fix the memory in the same run and log a `DECISION`.
- Parallel runs share repo memory. Edit the lines you touched, not the whole file.

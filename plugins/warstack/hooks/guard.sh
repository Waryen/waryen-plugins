#!/bin/sh
# warstack guard: the deterministic part of the harness (docs/conventions.md → Rules → Harness).
# PreToolUse: a denied call exits 2 with the reason on stderr. PostToolUse: one audit line per call.
# It acts only inside a warstack run's worktree and exits 0 at once anywhere else.
# POSIX sh, so it runs in Git Bash on Windows. No jq: the JSON on stdin is read with grep and sed.
# hooks/guard-test.sh is its test; run it after every change.

set -f
input=$(cat | tr -d '\n\r')

# First string value of a key, as written in the JSON (escapes kept).
field() { printf '%s' "$input" | grep -o "\"$1\": *\"[^\"]*\"" | head -1 | sed 's/^"[^"]*": *"//; s/"$//'; }
# One path form: forward slashes, a drive letter as /c.
norm() { printf '%s' "$1" | sed 's#\\\\#/#g; s#^\([A-Za-z]\):#/\1#'; }
lc() { printf '%s' "$1" | tr 'A-Z' 'a-z'; }
# Every value of a key in state.md: `key: value  # comment`.
yaml() { grep -E "^ *(- )?$1: *" "$state" | sed "s/^ *\(- \)\{0,1\}$1: *//; s/ *#.*$//; s/^\"//; s/\" *$//; s/ *$//"; }
log() { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) · $sid · $1" >> "$audit"; }
# deny <rule> <reason>: the rule id names the convention it enforces, for the audit summary.
deny() {
  log "DENIED · $1 · $tool · $2"
  echo "warstack guard denied this call ($1): $2. Log a DECISION line and continue without it." >&2
  exit 2
}

# Gate: cwd is <checkout>/.claude/worktrees/<run-id>, and that run is in flight.
cwd=$(norm "$(field cwd)")
case "$cwd" in */.claude/worktrees/*) ;; *) exit 0 ;; esac
run=${cwd##*/.claude/worktrees/}; run=${run%%/*}
ts=$HOME/.warstack
state=$ts/runs/$run/state.md
[ -f "$state" ] || exit 0
grep -qE '^status: *(intake|running)( |$)' "$state" || exit 0
audit=$ts/runs/$run/audit.log
root=${cwd%%/.claude/worktrees/*}/.claude/worktrees/$run
home=$(lc "$(norm "$HOME")")

tool=$(field tool_name)
event=$(field hook_event_name)
sid=$(field session_id | cut -c1-8); sid=${sid:--}

# The Bash command up to its closing quote, with \n and \t as spaces.
cmd=
if [ "$tool" = Bash ]; then
  cmd=${input#*\"command\":}
  if [ "$cmd" = "$input" ]; then cmd=; else cmd=$(printf '%s' "$cmd" | sed -E 's/^ *"(([^"\\]|\\.)*)".*/\1/; s/\\[nt]/ /g'); fi
fi

if [ "$event" = PostToolUse ]; then
  case "$tool" in
    Bash) what=$(printf '%.200s' "$cmd") ;;
    Skill) what="$(field skill) $(field args)" ;;
    mcp__*) what=$(field name) ;;
    *) what=$(field file_path)$(field notebook_path) ;;
  esac
  log "$tool · $what"
  exit 0
fi

# Rule 2: files that hold credential values, wherever they live, and the user's stores.
secret_file() { # $1: normalized lowercase path
  case "$1" in
    "$home"/.aws/*|"$home"/.ssh/*|"$home"/.netrc|"$home"/.git-credentials|"$home"/.npmrc|"$home"/.config/gcloud/*|"$home"/.kube/*|"$home"/.docker/config.json|"$home"/.azure/*|"$home"/library/keychains/*|"$home"/.gradle/gradle.properties|"$home"/.m2/settings.xml|"$home"/.claude/.credentials.json) return 0 ;;
    *.env.example|*.env.sample|*.env.template|*.env.dist) return 1 ;;
    *.env|*/.env.*|*.pem|*.p12|*.pfx|*.jks|*.keystore) inside "$1" && return 1; return 0 ;;
  esac
  return 1
}
# inside <normalized lowercase path>: under the run's worktrees, <TS> or a temp folder.
inside() {
  { printf '%s\n' "$root" "$ts" "$(norm "$(field scratchpad_dir)")" "${TMPDIR:-}" /tmp /private/tmp; yaml worktree; } |
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    case "$1/" in "$(lc "$(norm "${d%/}")")/"*) exit 42 ;; esac
  done
  [ $? -eq 42 ]
}
# Known token formats. Generic passwords stay a promise (Rule 2): a regex for them denies test fixtures.
SECRET_RE="AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|xox[abprs]-[0-9A-Za-z-]{10,}|gh[pousr]_[0-9A-Za-z]{30,}|ATATT3[0-9A-Za-z_-]{20,}|ATBB[0-9A-Za-z]{20,}|sk-ant-[0-9A-Za-z_-]{20,}|AIza[0-9A-Za-z_-]{35}"

# Rule 2 on push: no credential file and no known token format in the outgoing diff.
scan_push() {
  dir=$cwd; prev=
  for w in $cmd; do [ "$prev" = -C ] && dir=$(norm "$w"); prev=$w; done
  git -C "$dir" rev-parse --git-dir >/dev/null 2>&1 || return
  base=$(git -C "$dir" rev-parse -q --verify '@{u}' 2>/dev/null)
  [ -n "$base" ] || for t in $targets; do base=$(git -C "$dir" rev-parse -q --verify "origin/$t" 2>/dev/null) && break; done
  [ -n "$base" ] || return
  f=$(git -C "$dir" diff --name-only --diff-filter=A "$base...HEAD" 2>/dev/null | grep -E '(^|/)\.env(\.[^./]+)?$|\.(pem|p12|pfx|jks|keystore)$' | grep -vE '\.env\.(example|sample|template|dist)$' | head -1)
  [ -z "$f" ] || deny R2-push "secrets by name (Rule 2): the outgoing commits add the credential file $f; remove it from the branch (its name may go in docs, its content never in git)"
  hit=$(git -C "$dir" diff -U0 --no-color "$base...HEAD" 2>/dev/null | awk '
    /^\+\+\+ / { f = substr($0, 7); next }
    /^@@/ { split($3, a, ","); n = substr(a[1], 2) + 0; next }
    /^\+/ { print f ":" n ":" substr($0, 2); n++ }' | grep -E -m1 "$SECRET_RE" | cut -d: -f1,2)
  [ -z "$hit" ] || deny R2-push "secrets by name (Rule 2): $hit adds what looks like a credential value; keep the value in the secret file and reference it by name"
}

# Rules 2, 3 and 5: credential stores, outward actions and hooks.
check_bash() {
  case " $(lc "$cmd") " in
    *.aws/*|*.ssh/*|*.netrc*|*.git-credentials*|*.kube/*|*/gcloud/*|*.docker/config.json*|*keychains*|*"security find-"*|*.credentials.json*|*~/.npmrc*|*'$home/.npmrc'*|*.azure/*|*" lpass "*|*"op read "*|*"op item "*)
      deny R2-store "secrets by name (Rule 2): credential stores and key files stay closed; use the secret's name and let the app read it" ;;
  esac
  case " $cmd " in
    *" --no-verify "*|*core.hooksPath*|*HUSKY=0*) deny R5-hooks "hooks run (Rule 5): commit and push without --no-verify, core.hooksPath or HUSKY=0" ;;
    *" gh pr merge "*|*" gh pr ready "*|*" gh pr close "*|*" gh pr reopen "*|*" gh pr comment "*|*" gh pr review "*|*" gh pr lock "*|*" gh pr unlock "*|*" gh issue comment "*|*" gh issue close "*|*" gh issue reopen "*|*" gh issue edit "*|*" gh issue delete "*|*" gh release "*|*" gh repo delete "*)
      deny R3-outward "outward actions (Rule 3): merging, readying, closing, commenting, reviewing and releasing stay with the user" ;;
    *" gh pr create "*) case " $cmd " in *" --draft "*|*" -d "*) ;; *) deny R3-draft "every PR is a draft: add --draft" ;; esac ;;
    *" gh api "*) case " $cmd " in *" -X "*|*" --method "*|*" -f "*|*" -F "*|*" --field "*|*" --raw-field "*|*" --input "*) deny R3-outward "gh api stays read-only (Rule 3)" ;; esac ;;
  esac
  targets=$(yaml target)
  mode=; push=
  for w in $cmd; do
    case "$mode:$w" in
      push:-f|push:--force|push:--force-with-lease*|push:--force-if-includes|push:--mirror|push:--all|push:--prune|push:--delete|push:-d|push:-[a-zA-Z]*f*|push:+*|push::*)
        deny R3-push "outward actions (Rule 3): push the run's own branch with a plain push; no force, delete, mirror or --all" ;;
      commit:-n|commit:-[a-zA-Z]*n*) deny R5-hooks "hooks run (Rule 5): commit without -n" ;;
      commit:-m|commit:-am|commit:-F|commit:--message*|commit:--file*|commit:\"*|commit:\'*) mode=msg ;;
      push:-*) ;;
      push:*) ref=${w#*:}; for t in $targets; do [ "$ref" = "$t" ] || [ "$ref" = "refs/heads/$t" ] && deny R3-push "pushes go to the run's own branch, never to the target $t (Rule 3)"; done ;;
    esac
    case "$w" in push) mode=push; push=1 ;; commit) mode=commit ;; "&&"|"||"|";"|"|") mode= ;; esac
  done
  [ -z "$push" ] || scan_push
}

# Rule 4: repo writes stay inside the run's worktrees.
check_path() {
  path=$(field file_path); [ -n "$path" ] || path=$(field notebook_path)
  path=$(norm "$path")
  case "$path" in /*) ;; *) return ;; esac
  inside "$(lc "$path")" || deny R4-path "repo writes stay inside the run's worktrees and ~/.warstack (Rule 4): $path is outside them"
}

# Rule 2: reads of credential files.
check_read() {
  path=$(norm "$(field file_path)")
  case "$path" in /*) ;; *) return ;; esac
  secret_file "$(lc "$path")" && deny R2-store "secrets by name (Rule 2): $path holds credential values; use the secret's name and let the app read it"
}

# Rules 3 and 6: Atlassian writes and the user's own browser.
check_mcp() {
  case "$tool" in
    mcp__claude-in-chrome__*) deny R6-headless "runs are headless (Rule 6): the user's own browser stays out" ;;
    *[Aa]tlassian*) ;;
    *) return ;;
  esac
  case "${tool##*__}" in
    executeWrite)
      op=$(field name)
      case "$op" in
        createBitbucketRepoPullRequest) printf '%s' "$input" | grep -q '"draft": *true' || deny R3-draft "every PR is a draft: pass draft: true" ;;
        updateBitbucketRepoPullRequest) printf '%s' "$input" | grep -q '"draft": *false' && deny R3-draft "every PR stays a draft: readying it is the user's call" ;;
        runBitbucketRepoPipeline) ;;
        *) deny R3-atlassian "executeWrite is open only for createBitbucketRepoPullRequest, updateBitbucketRepoPullRequest and runBitbucketRepoPipeline (Rule 3); $op stays with the user" ;;
      esac ;;
    executeDestructive|create*|update*|edit*|transition*|delete*|remove*|add*|run*|post*|merge*|approve*|decline*)
      deny R3-atlassian "Jira, Confluence and Bitbucket stay read-only except draft PRs (Rule 3)" ;;
  esac
}

case "$tool" in
  Bash) check_bash ;;
  Edit|Write|MultiEdit|NotebookEdit) check_path ;;
  Read) check_read ;;
  mcp__*) check_mcp ;;
esac
exit 0

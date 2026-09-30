#!/bin/sh
# Negative tests for hooks/guard.sh: every input a run must not get away with, and the ones it needs.
# Run: sh hooks/guard-test.sh. It works in a temporary HOME and touches nothing of yours.
# The graduation evidence for the harness (docs/conventions.md → Rules → Harness) is this script passing.

G=$(cd "$(dirname "$0")" && pwd)/guard.sh
FIX=$(mktemp -d); export HOME=$FIX/home; export TMPDIR=$FIX/tmp
trap 'rm -rf "$FIX"' EXIT
CWD=$FIX/repo/.claude/worktrees/guard-test
OTHER=$FIX/other/.claude/worktrees/guard-test
RUN=$HOME/.warstack/runs/guard-test
mkdir -p "$RUN" "$CWD" "$OTHER" "$TMPDIR" "$HOME/.aws" "$HOME/.claude"
cat > "$RUN/state.md" <<STATE
---
run: guard-test
status: running      # intake | running | stopped | parked | done
repos:
  - key: local-repo
    checkout: $FIX/repo
    worktree: $CWD
    branch: feat/guard-test
    target: develop
  - key: local-other
    checkout: $FIX/other
    worktree: $OTHER
    branch: feat/guard-test
    target: main
---
STATE

fail=0
t() { # expected-exit, label, json
  out=$(printf '%s' "$3" | sh "$G" 2>&1); rc=$?
  if [ "$rc" = "$1" ]; then echo "ok   $2"; else echo "FAIL $2: exit $rc, wanted $1: $out"; fail=1; fi
}
bash() { printf '{"session_id":"sess1234abcd","cwd":"%s","scratchpad_dir":"%s/scratch","hook_event_name":"%s","tool_name":"Bash","tool_input":{"command":"%s","description":"d"}}' "$1" "$FIX" "$2" "$3"; }
edit() { printf '{"session_id":"sess1234abcd","cwd":"%s","scratchpad_dir":"%s/scratch","hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":"%s","old_string":"a","new_string":"b"}}' "$1" "$FIX" "$2"; }
read_() { printf '{"session_id":"sess1234abcd","cwd":"%s","scratchpad_dir":"%s/scratch","hook_event_name":"PreToolUse","tool_name":"Read","tool_input":{"file_path":"%s"}}' "$CWD" "$FIX" "$1"; }
mcp() { printf '{"session_id":"sess1234abcd","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"%s","tool_input":%s}' "$CWD" "$1" "$2"; }

echo "# gate"
t 0 "outside a run: force push allowed"      "$(bash "$FIX/repo" PreToolUse 'git push --force origin x')"
t 0 "unknown run worktree: allowed"          "$(bash /x/.claude/worktrees/nope PreToolUse 'git push --force origin x')"

echo "# rule 3: pushes"
t 2 "force push"                             "$(bash "$CWD" PreToolUse 'git push --force origin feat/x')"
t 2 "-f push via git -C"                     "$(bash "$CWD" PreToolUse "git -C $OTHER push -f origin feat/x")"
t 2 "-uf push"                               "$(bash "$CWD" PreToolUse 'git push -uf origin feat/x')"
t 2 "force-with-lease"                       "$(bash "$CWD" PreToolUse 'git push --force-with-lease=feat/x:abc origin feat/x')"
t 2 "delete remote branch"                   "$(bash "$CWD" PreToolUse 'git push origin --delete feat/x')"
t 2 "colon refspec delete"                   "$(bash "$CWD" PreToolUse 'git push origin :feat/x')"
t 2 "plus refspec"                           "$(bash "$CWD" PreToolUse 'git push origin +feat/x')"
t 2 "push to target"                         "$(bash "$CWD" PreToolUse 'git push origin develop')"
t 2 "push HEAD:target of other repo"         "$(bash "$CWD" PreToolUse 'git push origin HEAD:main')"
t 2 "push refs/heads/target"                 "$(bash "$CWD" PreToolUse 'git push origin HEAD:refs/heads/develop')"
t 2 "second command in chain force"          "$(bash "$CWD" PreToolUse 'git fetch origin && git push origin --force feat/x')"
t 2 "multiline force"                        "$(bash "$CWD" PreToolUse 'git add a\ngit push --force origin x')"
t 0 "plain push"                             "$(bash "$CWD" PreToolUse 'git push -u origin feat/guard-test')"
t 0 "push HEAD"                              "$(bash "$CWD" PreToolUse 'git push origin HEAD')"
t 0 "push then log -n"                       "$(bash "$CWD" PreToolUse 'git push -u origin feat/x && git log --oneline -n 3')"

echo "# rule 5: hooks"
t 2 "commit -n"                              "$(bash "$CWD" PreToolUse 'git commit -n -m \"x\"')"
t 2 "commit --no-verify"                     "$(bash "$CWD" PreToolUse 'git commit --no-verify -m \"x\"')"
t 2 "push --no-verify"                       "$(bash "$CWD" PreToolUse 'git push --no-verify origin feat/x')"
t 2 "core.hooksPath"                         "$(bash "$CWD" PreToolUse 'git -c core.hooksPath=/dev/null commit -m x')"
t 2 "HUSKY=0"                                "$(bash "$CWD" PreToolUse 'HUSKY=0 git commit -m x')"
t 0 "commit with -n inside message"          "$(bash "$CWD" PreToolUse 'git commit -m \"feat: support -n flag\"')"
t 0 "commit -am"                             "$(bash "$CWD" PreToolUse 'git commit -am \"x\"')"
t 0 "multiline command"                      "$(bash "$CWD" PreToolUse 'git add src/a.ts\ngit commit -m \"feat: a\"')"

echo "# rule 3: gh"
t 2 "gh pr merge"                            "$(bash "$CWD" PreToolUse 'gh pr merge 12 --squash')"
t 2 "gh pr ready"                            "$(bash "$CWD" PreToolUse 'gh pr ready 12')"
t 2 "gh pr comment"                          "$(bash "$CWD" PreToolUse 'gh pr comment 12 --body hi')"
t 2 "gh pr create without draft"             "$(bash "$CWD" PreToolUse 'gh pr create --base develop --head feat/x --title t --body-file f')"
t 0 "gh pr create --draft"                   "$(bash "$CWD" PreToolUse 'gh pr create --draft --base develop --head feat/x --title t --body-file f')"
t 0 "gh pr edit"                             "$(bash "$CWD" PreToolUse 'gh pr edit 12 --body \"Merge after: x\"')"
t 0 "gh pr checks"                           "$(bash "$CWD" PreToolUse 'gh pr checks feat/x')"
t 0 "gh api read"                            "$(bash "$CWD" PreToolUse 'gh api repos/o/r/pulls/12')"
t 2 "gh api write"                           "$(bash "$CWD" PreToolUse 'gh api -X POST repos/o/r/pulls/12/reviews')"
t 2 "gh release"                             "$(bash "$CWD" PreToolUse 'gh release create v1')"
t 0 "npm test"                               "$(bash "$CWD" PreToolUse 'npm test -- --watch=false')"

echo "# rule 4: writes"
t 0 "edit inside worktree"                   "$(edit "$CWD" "$CWD/src/a.ts")"
t 0 "edit relative"                          "$(edit "$CWD" 'src/a.ts')"
t 0 "edit secondary worktree"                "$(edit "$CWD" "$OTHER/src/a.ts")"
t 0 "edit run folder"                        "$(edit "$CWD" "$RUN/decisions.md")"
t 0 "edit warstack with trailing slash"    "$(edit "$CWD" "$HOME/.warstack/")"
t 0 "edit scratchpad"                        "$(edit "$CWD" "$FIX/scratch/n.txt")"
t 0 "edit TMPDIR"                            "$(edit "$CWD" "$TMPDIR/n.txt")"
t 0 "edit /tmp"                              "$(edit "$CWD" "/tmp/n.txt")"
t 2 "edit main checkout"                     "$(edit "$CWD" "$FIX/repo/src/a.ts")"
t 2 "edit other run worktree"                "$(edit "$CWD" "$FIX/repo/.claude/worktrees/other-run/a.ts")"
t 2 "edit home"                              "$(edit "$CWD" "$HOME/.claude/skills/warstack/skills/auto/SKILL.md")"
t 2 "edit sibling of warstack dir"         "$(edit "$CWD" "$HOME/.warstack-probe/n.txt")"
t 2 "edit /tmpfoo"                           "$(edit "$CWD" "/tmpfoo/n.txt")"
t 2 "edit from deeper cwd"                   "$(edit "$CWD/src/deep" "$FIX/repo/src/a.ts")"
t 0 "edit windows inside"                    "$(edit 'C:\\Users\\me\\repo\\.claude\\worktrees\\guard-test' 'C:\\Users\\me\\repo\\.claude\\worktrees\\guard-test\\src\\a.ts')"
t 2 "edit windows outside"                   "$(edit 'C:\\Users\\me\\repo\\.claude\\worktrees\\guard-test' 'C:\\Users\\me\\repo\\src\\a.ts')"

echo "# rule 2: credential stores"
t 2 "read ~/.aws/credentials"                "$(read_ "$HOME/.aws/credentials")"
t 2 "read ~/.ssh key"                        "$(read_ "$HOME/.ssh/id_ed25519")"
t 2 "read ~/.netrc"                          "$(read_ "$HOME/.netrc")"
t 2 "read claude credentials"                "$(read_ "$HOME/.claude/.credentials.json")"
t 2 "read main checkout .env"                "$(read_ "$FIX/repo/apps/e2e/.env")"
t 2 "read .env.local elsewhere"              "$(read_ "$HOME/Code/x/.env.local")"
t 2 "read pem elsewhere"                     "$(read_ "$HOME/certs/dev.pem")"
t 0 "read worktree .env"                     "$(read_ "$CWD/apps/e2e/.env")"
t 0 "read .env.example anywhere"             "$(read_ "$FIX/repo/apps/e2e/.env.example")"
t 0 "read worktree source"                   "$(read_ "$CWD/src/a.ts")"
t 0 "read run folder"                        "$(read_ "$RUN/task.md")"
t 0 "read uppercase-case path"               "$(read_ "$CWD/ENV/.envrc")"
t 2 "cat ~/.aws"                             "$(bash "$CWD" PreToolUse 'cat ~/.aws/credentials')"
t 2 "grep .ssh"                              "$(bash "$CWD" PreToolUse 'grep -r x $HOME/.ssh/')"
t 2 "keychain"                               "$(bash "$CWD" PreToolUse 'security find-generic-password -s x -w')"
t 2 "lpass"                                  "$(bash "$CWD" PreToolUse 'lpass show --password x')"
t 2 "gcloud config"                          "$(bash "$CWD" PreToolUse 'cat ~/.config/gcloud/application_default_credentials.json')"
t 0 "cp .env into worktree"                  "$(bash "$CWD" PreToolUse "cp -p $FIX/repo/apps/e2e/.env $CWD/apps/e2e/.env")"
t 0 "gcloud cli"                             "$(bash "$CWD" PreToolUse 'gcloud auth print-identity-token')"
t 0 "ssh-agent unrelated"                    "$(bash "$CWD" PreToolUse 'git push -u origin feat/x')"

echo "# rule 2: push scan"
git init -q -b develop "$CWD" && cd "$CWD" || exit 1
gitc() { git -c user.name=t -c user.email=t@t -c commit.gpgsign=false "$@"; }
echo base > a.txt && gitc add a.txt && gitc commit -qm base
git update-ref refs/remotes/origin/develop HEAD
git checkout -qb feat/guard-test
printf 'const key = "AKIAIOSFODNN7EXAMPLE";\n' > k.ts && gitc add k.ts && gitc commit -qm key
t 2 "push with AWS key in diff"              "$(bash "$CWD" PreToolUse 'git push -u origin feat/guard-test')"
gitc reset -q --hard origin/develop
printf 'token = "ATATT3xFfGF0abcdefghijklmnopqrstuvwxyz"\n' > k.txt && gitc add k.txt && gitc commit -qm tok
t 2 "push with Atlassian token via git -C"   "$(bash "$OTHER" PreToolUse "git -C $CWD push origin HEAD")"
gitc reset -q --hard origin/develop
printf 'SZ_PASSWORD=hunter2hunter2\n' > .env && gitc add -f .env && gitc commit -qm env
t 2 "push adding .env"                       "$(bash "$CWD" PreToolUse 'git push -u origin feat/guard-test')"
gitc reset -q --hard origin/develop
printf 'SZ_PASSWORD=your-password\n' > .env.example && gitc add .env.example && gitc commit -qm example
printf 'const token = process.env.ATATT_TOKEN;\n' > k.ts && gitc add k.ts && gitc commit -qm ok
t 0 "push clean diff"                        "$(bash "$CWD" PreToolUse 'git push -u origin feat/guard-test')"
printf 'const key = "AKIAIOSFODNN7EXAMPLE";\n' > k.ts && gitc commit -qam key
git update-ref refs/remotes/origin/feat/guard-test HEAD && git config remote.origin.url . && git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*" && git config branch.feat/guard-test.remote origin && git config branch.feat/guard-test.merge refs/heads/feat/guard-test
t 0 "push scan uses @{u}, not the target"    "$(bash "$CWD" PreToolUse 'git push')"
gitc reset -q --hard origin/develop
cd "$FIX"

echo "# rules 3 and 6: mcp"
t 2 "chrome"                                 "$(mcp mcp__claude-in-chrome__navigate '{"url":"http://x"}')"
t 0 "mobile-mcp"                             "$(mcp mcp__plugin_mobile-mcp_mobile-mcp__mobile_take_screenshot '{}')"
t 0 "jira read"                              "$(mcp mcp__claude_ai_Atlassian_MCP__getJiraIssue '{"cloudId":"c","issueIdOrKey":"X-1"}')"
t 0 "executeRead"                            "$(mcp mcp__claude_ai_Atlassian_MCP__executeRead '{"name":"getBitbucketRepoPullRequest","cloudId":"c","inputs":{}}')"
t 0 "atlassianUserInfo"                      "$(mcp mcp__claude_ai_Atlassian_MCP__atlassianUserInfo '{}')"
t 0 "search"                                 "$(mcp mcp__claude_ai_Atlassian_MCP__search '{"query":"x"}')"
t 0 "createPR draft"                         "$(mcp mcp__claude_ai_Atlassian_MCP__executeWrite '{"name":"createBitbucketRepoPullRequest","cloudId":"c","inputs":{"title":"t","draft":true}}')"
t 2 "createPR no draft"                      "$(mcp mcp__claude_ai_Atlassian_MCP__executeWrite '{"name":"createBitbucketRepoPullRequest","cloudId":"c","inputs":{"title":"t"}}')"
t 0 "updatePR"                               "$(mcp mcp__claude_ai_Atlassian_MCP__executeWrite '{"name":"updateBitbucketRepoPullRequest","cloudId":"c","inputs":{"description":"d"}}')"
t 2 "updatePR undraft"                       "$(mcp mcp__claude_ai_Atlassian_MCP__executeWrite '{"name":"updateBitbucketRepoPullRequest","cloudId":"c","inputs":{"draft":false}}')"
t 0 "rerun pipeline"                         "$(mcp mcp__claude_ai_Atlassian_MCP__executeWrite '{"name":"runBitbucketRepoPipeline","cloudId":"c","inputs":{}}')"
t 2 "executeWrite jira"                      "$(mcp mcp__claude_ai_Atlassian_MCP__executeWrite '{"name":"editJiraIssue","cloudId":"c","inputs":{}}')"
t 2 "executeWrite PR comment"                "$(mcp mcp__claude_ai_Atlassian_MCP__executeWrite '{"name":"createBitbucketRepoPullRequestComment","cloudId":"c","inputs":{}}')"
t 2 "executeDestructive"                     "$(mcp mcp__claude_ai_Atlassian_MCP__executeDestructive '{"name":"deleteBitbucketBranch","cloudId":"c","inputs":{}}')"
t 2 "editJiraIssue"                          "$(mcp mcp__claude_ai_Atlassian_MCP__editJiraIssue '{}')"
t 2 "jira comment"                           "$(mcp mcp__claude_ai_Atlassian_MCP__addOrEditJiraIssueComment '{}')"
t 2 "confluence create"                      "$(mcp mcp__claude_ai_Atlassian_MCP__createConfluenceContent '{}')"
t 2 "other prefix atlassian write"           "$(mcp mcp__atlassian__updateConfluencePage '{}')"

echo "# input shapes"
t 0 "pretty-printed json"                    "$(printf '{\n  "session_id": "s",\n  "cwd": "%s",\n  "hook_event_name": "PreToolUse",\n  "tool_name": "Bash",\n  "tool_input": {\n    "command": "git push -u origin feat/x",\n    "description": "d"\n  }\n}' "$CWD")"
t 2 "pretty-printed force"                   "$(printf '{\n  "cwd": "%s",\n  "hook_event_name": "PreToolUse",\n  "tool_name": "Bash",\n  "tool_input": {\n    "command": "git push --force origin feat/x"\n  }\n}' "$CWD")"

echo "# audit"
rm -f "$RUN/audit.log"
t 0 "post bash logs"                         "$(bash "$CWD" PostToolUse 'npm test')"
t 0 "post edit logs"                         "$(printf '{"cwd":"%s","hook_event_name":"PostToolUse","tool_name":"Edit","tool_input":{"file_path":"%s/src/a.ts"},"tool_response":{"filePath":"x","command":"nope"}}' "$CWD" "$CWD")"
t 0 "post skill logs"                        "$(printf '{"cwd":"%s","hook_event_name":"PostToolUse","tool_name":"Skill","tool_input":{"skill":"warstack:implement","args":"guard-test"},"tool_response":{"text":"ok"}}' "$CWD")"
t 0 "post mcp logs"                          "$(printf '{"cwd":"%s","hook_event_name":"PostToolUse","tool_name":"mcp__claude_ai_Atlassian_MCP__executeRead","tool_input":{"name":"getBitbucketRepoPullRequest"},"tool_response":{"text":"ok"}}' "$CWD")"
t 2 "deny logs too"                          "$(bash "$CWD" PreToolUse 'git push --force origin feat/x')"
a() { grep -qE "$1" "$RUN/audit.log" && echo "ok   audit: $2" || { echo "FAIL audit: $2"; fail=1; }; }
a '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z · sess1234 · Bash · npm test$' "bash line with session id"
a ' · - · Edit · .*/src/a.ts$' "edit line without session id"
a ' · Skill · warstack:implement guard-test$' "skill line"
a ' · mcp__claude_ai_Atlassian_MCP__executeRead · getBitbucketRepoPullRequest$' "mcp line"
a ' · sess1234 · DENIED · R3-push · Bash · ' "denial with rule id"
[ "$(grep -c '' "$RUN/audit.log")" = 5 ] && echo "ok   audit: 5 lines" || { echo "FAIL audit: $(grep -c '' "$RUN/audit.log") lines"; fail=1; }

echo "# gate off"
sed 's/^status: running/status: done/' "$RUN/state.md" > "$RUN/s" && mv "$RUN/s" "$RUN/state.md"
t 0 "done run: force push not the guard's"  "$(bash "$CWD" PreToolUse 'git push --force origin feat/x')"

[ $fail = 0 ] && echo "ALL OK" || { echo "SOME FAILED"; exit 1; }

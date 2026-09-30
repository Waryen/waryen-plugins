#!/bin/sh
# Tests for skills/afk/afk.sh, with a fake `claude` that plays one scripted outcome per call.
# Run: sh skills/afk/afk-test.sh. It works in a temporary HOME and touches nothing of yours.

A=$(cd "$(dirname "$0")" && pwd)/afk.sh
FIX=$(mktemp -d); export HOME=$FIX/home AFK_AWAKE=1 AFK_WAIT=0
trap 'rm -rf "$FIX"' EXIT
mkdir -p "$FIX/bin" "$FIX/q" "$FIX/repo"
export PATH=$FIX/bin:$PATH

# Fake claude: `claude -p "/warstack:auto <run-id> …"`. Pops the run's next outcome: done, crash or limit.
cat > "$FIX/bin/claude" <<'FAKE'
#!/bin/sh
cat > /dev/null
set -- $2; run=$2; shift 2
st=$HOME/.warstack/runs/$run/state.md
echo "$run $* · $(sed -n 's/^status: *//p' "$st")" >> "$HOME/calls"
b=$HOME/behave/$run; next=$(head -1 "$b"); sed 1d "$b" > "$b.t"; mv "$b.t" "$b"
case "$next" in
  done) printf -- '---\nstatus: done\n---\n' > "$st" ;;
  crash) printf -- '---\nstatus: running      # comment\n---\n' > "$st"; exit 1 ;;
  limit) printf -- '---\nstatus: running\n---\n' > "$st"; echo "Claude usage limit reached"; exit 1 ;;
  hang) printf -- '---\nstatus: running\n---\n' > "$st"; echo $$ > "$HOME/hung"; sleep 30 ;;
esac
FAKE
chmod +x "$FIX/bin/claude"

run() { # run-id, outcomes…
  r=$1; shift
  mkdir -p "$HOME/.warstack/runs/$r" "$HOME/behave"
  printf -- '---\nstatus: parked\n---\n' > "$HOME/.warstack/runs/$r/state.md"
  printf '%s\n' "$@" > "$HOME/behave/$r"
  printf '%s\t%s\t%s --target develop\n' "$FIX/repo" "$r" "$r" >> "$FIX/q/queue.tsv"
}
fail=0
t() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
calls() { grep -c "^$1 " "$HOME/calls"; }

run A done
run B crash done
run C limit limit done
run D crash crash crash
sh "$A" "$FIX/q" 1

t "a run that finishes is called once"            '[ "$(calls A)" = 1 ]'
t "the first call passes the queued arguments"    'grep -qx "A --target develop · parked" "$HOME/calls"'
t "a crashed run is resumed by its id, stopped"   'grep -q "^B  · stopped " "$HOME/calls"'
t "a crashed run ends done"                       '[ "$(calls B)" = 2 ]'
t "usage limits are waited out, not counted"      '[ "$(calls C)" = 3 ] && [ "$(grep -c "C · LIMIT" "$FIX/q/afk.log")" = 2 ]'
t "a run that keeps dying is given up after 3"    '[ "$(calls D)" = 3 ] && grep -q "D · GAVE UP" "$FIX/q/afk.log"'
t "a given-up run is left stopped, comment kept" 'grep -q "^status: stopped      # comment" "$HOME/.warstack/runs/D/state.md"'
t "the queue is not eaten by claude's stdin"      '[ "$(calls D)" -gt 0 ]'
t "the log ends"                                  'tail -1 "$FIX/q/afk.log" | grep -q "· END"'

: > "$HOME/calls"; : > "$FIX/q/afk.log"
sh "$A" "$FIX/q" 0
t "no run starts after the deadline"              '[ ! -s "$HOME/calls" ] && [ "$(grep -c SKIPPED "$FIX/q/afk.log")" = 4 ]'

: > "$FIX/q/queue.tsv"; : > "$FIX/q/afk.log"
run E hang
sh "$A" "$FIX/q" 1 &
i=0; while [ ! -s "$HOME/hung" ] && [ $i -lt 50 ]; do sleep 0.1; i=$((i + 1)); done
kill "$(cat "$FIX/q/pid")"; wait
t "kill stops the driver and logs it"             'grep -q "STOPPED · killed" "$FIX/q/afk.log"'
t "kill ends the run's session"                   '! kill -0 "$(cat "$HOME/hung")" 2>/dev/null'
t "kill leaves the run stopped, resumable"        'grep -q "^status: stopped" "$HOME/.warstack/runs/E/state.md"'

[ "$fail" = 0 ] && echo "all passed"
exit "$fail"

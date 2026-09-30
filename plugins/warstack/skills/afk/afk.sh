#!/bin/sh
# warstack afk driver: works through a queue of /warstack:auto runs, one at a time, headless, while the user is away.
# Usage: sh afk.sh <afk folder> <hours>. The folder holds queue.tsv: <checkout> TAB <run-id> TAB <auto arguments>.
# A run that ends done, parked or stopped is left as it is. A session that dies with its run in flight
# (crash, usage limit) is resumed. No run starts after <hours>. `kill <pid in the folder>` stops it.
# POSIX sh. skills/afk/afk-test.sh is its test; run it after every change.

dir=$1; hours=${2:-10}
if [ -z "$AFK_AWAKE" ] && command -v caffeinate >/dev/null 2>&1; then
  AFK_AWAKE=1 exec caffeinate -i sh "$0" "$@"
fi
wait=${AFK_WAIT:-1800}   # seconds to wait out a usage limit
end=$(( $(date +%s) + hours * 3600 ))
runs=$HOME/.warstack/runs
tab=$(printf '\t')
child=

log() { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) · $1" >> "$dir/afk.log"; }
status() { sed -n 's/^status: *\([a-z]*\).*/\1/p' "$runs/$1/state.md" 2>/dev/null | head -1; }
# auto will not resume a `running` run updated in the last 6 hours: it assumes another session drives it.
stop_run() { f=$runs/$1/state.md; sed 's/^status: *running/status: stopped/' "$f" > "$f.afk" && mv "$f.afk" "$f"; }

echo $$ > "$dir/pid"
trap '[ -n "$child" ] && kill "$child" 2>/dev/null && wait "$child"; [ "$(status "$run")" = running ] && stop_run "$run"; log "STOPPED · killed"; exit 1' INT TERM
log "START · pid $$ · ${hours}h"

while IFS="$tab" read -r checkout run args; do
  [ -n "$run" ] || continue
  deaths=0
  while :; do
    [ "$(date +%s)" -lt "$end" ] || { log "$run · SKIPPED · time is up"; continue 2; }
    log "$run · START · /warstack:auto $args"
    (cd "$checkout" && exec claude -p "/warstack:auto $args" --permission-mode auto) </dev/null >> "$dir/$run.log" 2>&1 &
    child=$!; wait "$child"; child=
    s=$(status "$run")
    case "$s" in done|parked|stopped) log "$run · ${s}"; break ;; esac

    # The session died with the run in flight.
    [ "$s" = running ] && stop_run "$run"
    args=$run
    if tail -n 20 "$dir/$run.log" | grep -qiE 'usage limit|rate limit|limit reached'; then
      log "$run · LIMIT · waiting ${wait}s"; sleep "$wait"
    else
      deaths=$((deaths + 1))
      [ "$deaths" -lt 3 ] || { log "$run · GAVE UP · the session died 3 times, see $run.log"; break; }
      log "$run · DIED · resuming ($deaths)"
    fi
  done
done < "$dir/queue.tsv"

log "END"
command -v osascript >/dev/null 2>&1 && osascript -e 'display notification "Queue finished. Run /warstack:status." with title "warstack afk"'
exit 0

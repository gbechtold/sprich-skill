#!/bin/bash
# Stop hook: speak the last output without anyone typing a command.
#
#   sprich-stop-hook.sh            as a hook, Stop event JSON on stdin
#   sprich-stop-hook.sh on|off     turn auto-speak on or off
#   sprich-stop-hook.sh status     show the switch
#
# The switch is a file. If it is missing the hook does nothing and exits at once.
# Synthesis and playback run detached, so the session never waits on them.
set -uo pipefail

STATE="${SPRICH_STATE:-$HOME/.claude/skills/sprich/.state}"
FLAG="$STATE/auto"
SPEAK="${SPRICH_SKILL:-$HOME/.claude/skills/sprich}/speak.sh"
EXTRACT="${SPRICH_SCRIPTS:-$HOME/.claude/scripts}/sprich-last-output.py"
VOICE="${SPRICH_AUTO_VOICE:-medium}"
MAX_WORDS="${SPRICH_AUTO_WORDS:-90}"

case "${1:-}" in
  on)     mkdir -p "$STATE"; touch "$FLAG"; echo "Vorlesen: an ($VOICE, max $MAX_WORDS Wörter)"; exit 0 ;;
  off)    rm -f "$FLAG"; echo "Vorlesen: aus"; exit 0 ;;
  status) [[ -f "$FLAG" ]] && echo "Vorlesen: an" || echo "Vorlesen: aus"; exit 0 ;;
esac

[[ -f "$FLAG" ]] || exit 0

PAYLOAD=$(cat)
TRANSCRIPT=$(printf '%s' "$PAYLOAD" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("transcript_path",""))' 2>/dev/null)
[[ -f "$TRANSCRIPT" ]] || exit 0

(
  TEXT=$(python3 "$EXTRACT" "$TRANSCRIPT" "$MAX_WORDS" 2>/dev/null)
  [[ -n "$TEXT" ]] || exit 0
  "$SPEAK" stop >/dev/null 2>&1
  "$SPEAK" --voice "$VOICE" "$TEXT" >/dev/null 2>&1
) </dev/null >/dev/null 2>&1 &
disown
exit 0

#!/bin/bash
# Stop hook: offer the last output as speech without anyone typing a command.
#
#   sprich-stop-hook.sh            as a hook, Stop event JSON on stdin
#   sprich-stop-hook.sh on         notify first, speak when the banner is clicked
#   sprich-stop-hook.sh now        speak immediately, no banner
#   sprich-stop-hook.sh off        neither
#   sprich-stop-hook.sh status     show the switch
#   sprich-stop-hook.sh play <id>  speak what is waiting for that session
#
# Why the banner is the default: several sessions finish at their own pace, and
# a hook that speaks on its own turns two finished terminals into two voices at
# once. The banner names the project, waits, and speaks only the one clicked.
# Clicking a second one interrupts the first instead of layering on top of it.
#
# The switch is a file holding the mode. If it is missing the hook does nothing
# and exits at once. Synthesis and playback run detached, the session never waits.
set -uo pipefail

STATE="${SPRICH_STATE:-$HOME/.claude/skills/sprich/.state}"
FLAG="$STATE/auto"
PENDING="$STATE/pending"
SPEAK="${SPRICH_SKILL:-$HOME/.claude/skills/sprich}/speak.sh"
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
EXTRACT="${SPRICH_LAST_OUTPUT:-$(dirname "$SELF")/sprich-last-output.py}"
VOICE="${SPRICH_AUTO_VOICE:-medium}"
MAX_WORDS="${SPRICH_AUTO_WORDS:-90}"
KEEP_MIN="${SPRICH_KEEP_MIN:-60}"

mode() { cat "$FLAG" 2>/dev/null || echo ""; }

case "${1:-}" in
  on)
    mkdir -p "$STATE"; echo notify > "$FLAG"
    echo "Vorlesen: an, Banner zuerst ($VOICE, max $MAX_WORDS Wörter)"; exit 0 ;;
  now)
    mkdir -p "$STATE"; echo now > "$FLAG"
    echo "Vorlesen: an, sofort ohne Banner ($VOICE, max $MAX_WORDS Wörter)"; exit 0 ;;
  off)
    rm -f "$FLAG"; echo "Vorlesen: aus"; exit 0 ;;
  status)
    case "$(mode)" in
      notify) echo "Vorlesen: an, Banner zuerst" ;;
      now)    echo "Vorlesen: an, sofort" ;;
      *)      echo "Vorlesen: aus" ;;
    esac; exit 0 ;;
  play)
    SID="${2:-}"
    FILE="$PENDING/$SID.txt"
    [[ -s "$FILE" ]] || exit 0
    # Whoever is clicked now wins the speakers. Stopping first is what keeps two
    # banners clicked in a row from turning into two voices.
    "$SPEAK" stop >/dev/null 2>&1
    "$SPEAK" --voice "$VOICE" "$(cat "$FILE")" >/dev/null 2>&1
    rm -f "$FILE"
    exit 0 ;;
esac

MODE="$(mode)"
[[ "$MODE" == "notify" || "$MODE" == "now" ]] || exit 0

PAYLOAD=$(cat)
TRANSCRIPT=$(printf '%s' "$PAYLOAD" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("transcript_path",""))' 2>/dev/null)
[[ -f "$TRANSCRIPT" ]] || exit 0

(
  FIELDS=$(python3 "$EXTRACT" --json "$TRANSCRIPT" "$MAX_WORDS" 2>/dev/null)
  [[ -n "$FIELDS" ]] || exit 0
  eval "$(printf '%s' "$FIELDS" | python3 -c '
import json, shlex, sys
d = json.load(sys.stdin)
for key in ("project", "task", "body", "speech"):
    print("{}={}".format(key.upper(), shlex.quote(d.get(key) or "")))
')"
  [[ -n "$SPEECH" ]] || exit 0

  if [[ "$MODE" == "now" ]]; then
    "$SPEAK" stop >/dev/null 2>&1
    "$SPEAK" --voice "$VOICE" "$SPEECH" >/dev/null 2>&1
    exit 0
  fi

  mkdir -p "$PENDING"
  find "$PENDING" -type f -name '*.txt' -mmin +"$KEEP_MIN" -delete 2>/dev/null
  SID=$(basename "$TRANSCRIPT" .jsonl)
  printf '%s' "$SPEECH" > "$PENDING/$SID.txt"

  command -v terminal-notifier >/dev/null || exit 0
  terminal-notifier \
    -title "${PROJECT:-Ohne Projekt}" \
    -subtitle "${TASK:-Antwort steht}" \
    -message "$(printf '%s' "$BODY" | cut -c1-120)" \
    -group "sprich-$SID" \
    -execute "$(printf '%q' "$SELF") play $(printf '%q' "$SID")" \
    >/dev/null 2>&1
) </dev/null >/dev/null 2>&1 &
disown
exit 0

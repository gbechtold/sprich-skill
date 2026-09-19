#!/bin/bash
# Speak German text with Piper TTS (offline, local, no API).
# Streams audio so playback starts on the first sentence instead of
# waiting for the full synthesis.
#
# Usage:
#   echo "Text" | speak.sh
#   speak.sh "Text"
#   speak.sh --voice medium "Text"        # faster, slightly flatter
#   speak.sh --save out.wav "Text"
#   speak.sh --repeat                     # replay the last utterance, no synthesis
#   speak.sh --last-text                  # print what was said last, don't speak
#
# Override locations with PIPER_VOICES / PIPER_PYTHON / SPRICH_STATE.
set -uo pipefail

VOICE_DIR="${PIPER_VOICES:-$HOME/.local/share/piper-voices}"
STATE="${SPRICH_STATE:-$HOME/.claude/skills/sprich/.state}"
VOICE="de_DE-thorsten-high"
RATE=22050
SAVE=""

find_piper_python() {
  [[ -n "${PIPER_PYTHON:-}" && -x "${PIPER_PYTHON}" ]] && { echo "$PIPER_PYTHON"; return; }
  local c
  for c in "$HOME/.local/share/uv/tools/piper-tts/bin/python" \
           "$HOME/.local/pipx/venvs/piper-tts/bin/python"; do
    [[ -x "$c" ]] && { echo "$c"; return; }
  done
  command -v python3 2>/dev/null
}

play_raw() {  # $1 = raw file, $2 = sample rate
  ffplay -f s16le -ar "$2" -ch_layout mono -nodisp -autoexit -loglevel quiet -i "$1" 2>/dev/null
}

# --- Zustandsmodi: brauchen weder Piper noch Text ---
case "${1:-}" in
  --repeat)
    [[ -s "$STATE/last.raw" ]] || { echo "speak.sh: nichts zu wiederholen — noch nichts gesprochen" >&2; exit 2; }
    play_raw "$STATE/last.raw" "$(cat "$STATE/last.rate" 2>/dev/null || echo 22050)"
    exit $? ;;
  --last-text)
    [[ -s "$STATE/last.txt" ]] || { echo "speak.sh: noch nichts gesprochen" >&2; exit 2; }
    cat "$STATE/last.txt"; exit 0 ;;
esac

while [[ $# -gt 0 ]]; do
  case "$1" in
    --voice)
      case "$2" in
        high)      VOICE="de_DE-thorsten-high" ;;
        medium)    VOICE="de_DE-thorsten-medium" ;;
        emotional) VOICE="de_DE-thorsten_emotional-medium" ;;
        kerstin)   VOICE="de_DE-kerstin-low" ;;
        eva)       VOICE="de_DE-eva_k-x_low" ;;
        *)         VOICE="$2" ;;
      esac
      shift 2 ;;
    --save) SAVE="$2"; shift 2 ;;
    --help) sed -n '2,15p' "$0"; exit 0 ;;
    *) break ;;
  esac
done

if [[ $# -gt 0 ]]; then TEXT="$*"; else TEXT="$(cat)"; fi
[[ -z "${TEXT// }" ]] && { echo "speak.sh: kein Text übergeben" >&2; exit 1; }

PY="$(find_piper_python)"
[[ -n "$PY" && -x "$PY" ]] || { echo "speak.sh: Piper nicht gefunden. Setup: uv tool install piper-tts" >&2; exit 1; }
"$PY" -c "import piper" 2>/dev/null || { echo "speak.sh: Python ohne piper-Modul ($PY). Setup: uv tool install piper-tts" >&2; exit 1; }

# Read the real sample rate from the voice config instead of assuming it.
if [[ -f "$VOICE_DIR/$VOICE.onnx.json" ]]; then
  R=$("$PY" -c "import json,sys; print(json.load(open(sys.argv[1]))['audio']['sample_rate'])" \
        "$VOICE_DIR/$VOICE.onnx.json" 2>/dev/null) && [[ -n "$R" ]] && RATE="$R"
else
  echo "speak.sh: Stimme $VOICE fehlt in $VOICE_DIR — siehe install.sh" >&2; exit 1
fi

mkdir -p "$STATE"

if [[ -n "$SAVE" ]]; then
  printf '%s' "$TEXT" | "$PY" -m piper -m "$VOICE" --data-dir "$VOICE_DIR" -f "$SAVE" >/dev/null 2>&1 || exit 1
  # WAV-Header (44 Byte) abschneiden, damit der Cache dasselbe Rohformat hat
  tail -c +45 "$SAVE" > "$STATE/last.raw"
  command -v afplay >/dev/null && afplay "$SAVE"
else
  # tee schreibt den Cache, waehrend ffplay schon abspielt
  printf '%s' "$TEXT" \
    | "$PY" -m piper -m "$VOICE" --data-dir "$VOICE_DIR" --output-raw 2>/dev/null \
    | tee "$STATE/last.raw" \
    | play_raw - "$RATE"
fi

printf '%s' "$TEXT" > "$STATE/last.txt"
printf '%s' "$RATE"  > "$STATE/last.rate"
printf '%s' "$VOICE" > "$STATE/last.voice"

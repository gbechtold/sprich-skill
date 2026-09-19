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
#
# Override locations with PIPER_VOICES / PIPER_PYTHON if you installed
# things elsewhere.
set -uo pipefail

VOICE_DIR="${PIPER_VOICES:-$HOME/.local/share/piper-voices}"
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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --voice)
      case "$2" in
        high)      VOICE="de_DE-thorsten-high" ;;
        medium)    VOICE="de_DE-thorsten-medium" ;;
        emotional) VOICE="de_DE-thorsten_emotional-medium" ;;
        kerstin)   VOICE="de_DE-kerstin-low"; RATE=16000 ;;
        eva)       VOICE="de_DE-eva_k-x_low"; RATE=16000 ;;
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

if [[ -n "$SAVE" ]]; then
  printf '%s' "$TEXT" | "$PY" -m piper -m "$VOICE" --data-dir "$VOICE_DIR" -f "$SAVE" >/dev/null 2>&1 \
    && { command -v afplay >/dev/null && afplay "$SAVE" || true; }
else
  printf '%s' "$TEXT" \
    | "$PY" -m piper -m "$VOICE" --data-dir "$VOICE_DIR" --output-raw 2>/dev/null \
    | ffplay -f s16le -ar "$RATE" -ch_layout mono -nodisp -autoexit -loglevel quiet -i - 2>/dev/null
fi

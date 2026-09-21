#!/bin/bash
# Speak German text with Piper TTS (offline, local, no API).
#
# Playback runs detached in the background so the session is not blocked and
# the utterance can be paused, resumed and rewound while other work continues.
#
#   speak.sh "Text"                 synthesise, play, print one status line
#   speak.sh --title "Slug" "Text"  give the file a speaking name
#   speak.sh --full "Text"          read a whole output out, not a briefing
#   speak.sh --voice medium "Text"  faster voice
#   speak.sh pp | rw | stop         play/pause · rewind to start · stop
#   speak.sh again                  replay the last utterance, no synthesis
#   speak.sh text                   print what was said last
#   speak.sh ls                     list cached utterances
#
# Audio is cached under .state/audio and swept after one hour.
# Override with PIPER_VOICES / PIPER_PYTHON / SPRICH_STATE / SPRICH_KEEP_MIN.
set -uo pipefail

VOICE_DIR="${PIPER_VOICES:-$HOME/.local/share/piper-voices}"
STATE="${SPRICH_STATE:-$HOME/.claude/skills/sprich/.state}"
AUDIO="$STATE/audio"
KEEP_MIN="${SPRICH_KEEP_MIN:-60}"
VOICE="de_DE-thorsten-high"
RATE=22050
TITLE=""
OPTIONS=()
# Vollstaendige Ausgabe statt Briefing. Vorbelegt aus dem Zustand, damit pp, rw
# und again dieselbe Zeile zeigen wie der Lauf, der die Datei erzeugt hat; ein
# neuer Sprechauftrag setzt sie unten wieder zurueck.
FULL=$(cat "${SPRICH_STATE:-$HOME/.claude/skills/sprich/.state}/last.full" 2>/dev/null || echo 0)

mkdir -p "$AUDIO"

# Sweep old audio on every invocation. -mmin, not -mtime: -mtime counts whole
# days and would never match a one-hour window.
sweep() { find "$AUDIO" -type f -name '*.wav' -mmin +"$KEEP_MIN" -delete 2>/dev/null; }

# Dauer aus der Dateigroesse statt ueber sox: Piper schreibt PCM 16 bit mono mit
# 44 Byte Kopf, das rechnet sich exakt und braucht kein weiteres Werkzeug.
wav_dauer() {  # $1 = wav -> "m:ss"
  local b r
  b=$(wc -c < "$1" 2>/dev/null | tr -d ' ')
  r=$(cat "$STATE/last.rate" 2>/dev/null || echo 22050)
  [[ -n "$b" && -n "$r" && "$r" -gt 0 ]] || return 1
  awk -v b="$b" -v r="$r" 'BEGIN{s=(b-44)/(r*2); if(s<0)s=0; printf "%d:%02d", int(s/60), int(s+0.5)%60}'
}

pid_alive() { [[ -s "$STATE/play.pid" ]] && kill -0 "$(cat "$STATE/play.pid")" 2>/dev/null; }
pid_state() { ps -o state= -p "$(cat "$STATE/play.pid" 2>/dev/null)" 2>/dev/null | tr -d ' '; }

start_play() {  # $1 = wav
  pid_alive && kill "$(cat "$STATE/play.pid")" 2>/dev/null
  nohup afplay "$1" >/dev/null 2>&1 &
  local p=$!
  disown "$p" 2>/dev/null
  echo "$p" > "$STATE/play.pid"
  printf '%s' "$1" > "$STATE/play.file"
}

# Kurzform: nur der sprechende Titel, nicht der volle Dateiname. Der Zeitstempel
# bleibt auf der Platte, im Terminal ist er Ballast.
#
# Keine Symbole fuer die Steuerung: im Terminal ist nichts davon anklickbar, also
# ist ein Icon nur Zierrat. Der Zustand steht als Wort da, die Befehle stehen in
# der Skill-Beschreibung.
# Die Dauer steht nur im --full-Modus dabei. Bei einem Briefing ist sie Ballast —
# es sind immer rund vierzig Sekunden. Bei einer vollstaendigen Ausgabe ist sie
# die eine Zahl, die man vorher wissen will: zwei Minuten hoert man mit, sieben
# liest man lieber.
status_line() {  # $1 = wav, $2 = zustand: play|pause|stop
  local n d=""; n="$(basename "$1")"; n="${n#* Response }"
  [[ "${FULL:-0}" == 1 ]] && d=" · $(wav_dauer "$1")"
  case "$2" in
    pause) printf '%s — pausiert%s\n' "$n" "$d" ;;
    stop)  printf '%s — gestoppt%s\n' "$n" "$d" ;;
    *)     printf '%s — läuft%s\n' "$n" "$d" ;;
  esac
}

# Optionen unter der Statuszeile. Bewusst die einzige Ausnahme von der
# Ein-Zeilen-Regel: eine gehoerte Option, die man nicht nachlesen kann, ist nach
# zehn Sekunden weg. Nummeriert mit [1], [2] — derselbe Ziffer, mit der der User
# antwortet, und ueberall gleich gerendert.
option_lines() {
  local i=1 o
  [[ ${#OPTIONS[@]} -eq 0 ]] && return 0
  for o in "${OPTIONS[@]}"; do
    [[ -z "$o" ]] && continue
    printf '  [%d] %s\n' "$i" "$o"
    i=$((i+1))
  done
}

load_opts() {  # bash 3.2 hat kein mapfile
  OPTIONS=()
  [[ -s "$STATE/last.opts" ]] || return 0
  while IFS= read -r l; do [[ -n "$l" ]] && OPTIONS+=("$l"); done < "$STATE/last.opts"
}

# ---------- Steuerbefehle: brauchen weder Piper noch Text ----------
case "${1:-}" in
  pp|--toggle|--pause|--play)
    pid_alive || { echo "nichts aktiv — !sprich again spielt die letzte Ausgabe"; exit 0; }
    if [[ "$(pid_state)" == T* ]]; then kill -CONT "$(cat "$STATE/play.pid")"; S="play"; else kill -STOP "$(cat "$STATE/play.pid")"; S="pause"; fi
    RATE=$(cat "$STATE/last.rate" 2>/dev/null || echo 22050)
    status_line "$(cat "$STATE/play.file")" "$S"; exit 0 ;;
  rw|--rewind|again|--repeat)
    F="$(cat "$STATE/play.file" 2>/dev/null)"
    [[ -s "${F:-}" ]] || { echo "nichts im Zwischenspeicher"; exit 2; }
    RATE=$(cat "$STATE/last.rate" 2>/dev/null || echo 22050)
    start_play "$F"; status_line "$F" play; load_opts; option_lines; exit 0 ;;
  stop|--stop)
    pid_alive && kill "$(cat "$STATE/play.pid")" 2>/dev/null
    F="$(cat "$STATE/play.file" 2>/dev/null)"; : > "$STATE/play.pid"
    [[ -s "${F:-}" ]] && status_line "$F" stop || echo "gestoppt"; exit 0 ;;
  text|--last-text)
    [[ -s "$STATE/last.txt" ]] || { echo "noch nichts gesprochen" >&2; exit 2; }
    cat "$STATE/last.txt"; exit 0 ;;
  ls|--list)
    sweep; ls -1t "$AUDIO"/*.wav 2>/dev/null | head -20 | while read -r f; do n="$(basename "$f")"; echo "${n#* Response }"; done; exit 0 ;;
  --help|-h) sed -n '2,20p' "$0"; exit 0 ;;
esac

FULL=0   # der geerbte Wert galt nur fuer die Steuerbefehle oben
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
    --full) FULL=1; shift ;;
    --title) TITLE="$2"; shift 2 ;;
    --option) OPTIONS+=("$2"); shift 2 ;;
    *) break ;;
  esac
done

if [[ $# -gt 0 ]]; then TEXT="$*"; else TEXT="$(cat)"; fi
[[ -z "${TEXT// }" ]] && { echo "speak.sh: kein Text übergeben" >&2; exit 1; }

PY=""
for c in "${PIPER_PYTHON:-}" "$HOME/.local/share/uv/tools/piper-tts/bin/python" \
         "$HOME/.local/pipx/venvs/piper-tts/bin/python"; do
  [[ -n "$c" && -x "$c" ]] && { PY="$c"; break; }
done
[[ -n "$PY" ]] || PY="$(command -v python3)"
"$PY" -c "import piper" 2>/dev/null || { echo "speak.sh: Piper fehlt. Setup: uv tool install piper-tts" >&2; exit 1; }

[[ -f "$VOICE_DIR/$VOICE.onnx.json" ]] || { echo "speak.sh: Stimme $VOICE fehlt in $VOICE_DIR — siehe install.sh" >&2; exit 1; }
R=$("$PY" -c "import json,sys; print(json.load(open(sys.argv[1]))['audio']['sample_rate'])" \
      "$VOICE_DIR/$VOICE.onnx.json" 2>/dev/null) && [[ -n "$R" ]] && RATE="$R"

# Sprechender Dateiname: YYMMDDHHMMSS Response <Titel>.wav
if [[ -z "$TITLE" ]]; then
  TITLE=$(printf '%s' "$TEXT" | tr '\n' ' ' | cut -c1-40 | sed 's/[^[:alnum:]äöüÄÖÜß ]//g; s/  */ /g; s/^ //; s/ $//')
  [[ -z "$TITLE" ]] && TITLE="Ausgabe"
fi
TITLE=$(printf '%s' "$TITLE" | sed 's#[/:]#-#g' | cut -c1-48)
WAV="$AUDIO/$(date +%y%m%d%H%M%S) Response $TITLE.wav"

printf '%s' "$TEXT" | "$PY" -m piper -m "$VOICE" --data-dir "$VOICE_DIR" -f "$WAV" >/dev/null 2>&1
[[ -s "$WAV" ]] || { echo "speak.sh: Synthese lieferte nichts" >&2; exit 1; }

printf '%s' "$TEXT"  > "$STATE/last.txt"
printf '%s' "$RATE"  > "$STATE/last.rate"
printf '%s' "$VOICE" > "$STATE/last.voice"
printf '%s' "$FULL"  > "$STATE/last.full"

: > "$STATE/last.opts"
[[ ${#OPTIONS[@]} -gt 0 ]] && printf '%s\n' "${OPTIONS[@]}" > "$STATE/last.opts"

start_play "$WAV"
sweep
status_line "$WAV" play
option_lines

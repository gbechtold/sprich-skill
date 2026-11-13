#!/bin/bash
# Install the "sprich" skill: Piper TTS + German voices + the skill itself.
#
#   ./install.sh           install skill, transport and auto-speak scripts
#   ./install.sh --hook     also register the Stop hook in settings.json
set -euo pipefail

VOICE_DIR="${PIPER_VOICES:-$HOME/.local/share/piper-voices}"
SKILL_DIR="${CLAUDE_SKILLS:-$HOME/.claude/skills}/sprich"
SCRIPT_DIR="${SPRICH_SCRIPTS:-$HOME/.claude/scripts}"
BIN_DIR="${SPRICH_BIN:-$HOME/.local/bin}"
SETTINGS="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WITH_HOOK=0
[[ "${1:-}" == "--hook" ]] && WITH_HOOK=1

command -v uv >/dev/null || { echo "uv fehlt: https://docs.astral.sh/uv/getting-started/installation/" >&2; exit 1; }
command -v ffplay >/dev/null || echo "Hinweis: ffplay fehlt (brew install ffmpeg) — ohne ffplay kein Streaming-Playback." >&2

echo "→ Piper installieren"
uv tool install piper-tts

PY="$HOME/.local/share/uv/tools/piper-tts/bin/python"

echo "→ Stimmen nach $VOICE_DIR"
mkdir -p "$VOICE_DIR"
"$PY" -m piper.download_voices --data-dir "$VOICE_DIR" \
  de_DE-thorsten-high \
  de_DE-thorsten-medium \
  de_DE-thorsten_emotional-medium \
  de_DE-kerstin-low \
  de_DE-eva_k-x_low

echo "→ Skill nach $SKILL_DIR"
mkdir -p "$SKILL_DIR"
cp "$HERE/SKILL.md" "$HERE/speak.sh" "$SKILL_DIR/"
chmod +x "$SKILL_DIR/speak.sh"

echo "→ Auto-speak nach $SCRIPT_DIR"
mkdir -p "$SCRIPT_DIR"
cp "$HERE/sprich-stop-hook.sh" "$HERE/sprich-last-output.py" "$SCRIPT_DIR/"
chmod +x "$SCRIPT_DIR/sprich-stop-hook.sh" "$SCRIPT_DIR/sprich-last-output.py"

echo "→ Transport nach $BIN_DIR"
mkdir -p "$BIN_DIR"
cp "$HERE/sprich" "$BIN_DIR/sprich"
chmod +x "$BIN_DIR/sprich"
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "   Hinweis: $BIN_DIR liegt nicht im PATH." >&2 ;;
esac

HOOK_CMD="$SCRIPT_DIR/sprich-stop-hook.sh"

if [[ "$WITH_HOOK" == "1" ]]; then
  echo "→ Stop-Hook in $SETTINGS"
  python3 - "$SETTINGS" "$HOOK_CMD" <<'PY'
import json, os, shutil, sys
path, cmd = sys.argv[1], sys.argv[2]
data = {}
if os.path.exists(path):
    shutil.copyfile(path, path + ".bak-sprich")
    with open(path) as fh:
        data = json.load(fh)
blocks = data.setdefault("hooks", {}).setdefault("Stop", [])
if not blocks:
    blocks.append({"hooks": []})
existing = [h.get("command") for b in blocks for h in b.get("hooks", [])]
if cmd in existing:
    print("   schon eingetragen")
else:
    blocks[0].setdefault("hooks", []).append(
        {"type": "command", "command": cmd, "timeout": 10, "statusMessage": "Output vorlesen"})
    with open(path, "w") as fh:
        json.dump(data, fh, indent=2, ensure_ascii=False)
    print("   eingetragen")
PY
else
  echo
  echo "Auto-speak ist installiert, aber noch nicht verdrahtet. Entweder"
  echo "  ./install.sh --hook"
  echo "oder von Hand in $SETTINGS unter hooks.Stop:"
  echo "  {\"type\": \"command\", \"command\": \"$HOOK_CMD\", \"timeout\": 10}"
fi

echo "→ Test"
"$SKILL_DIR/speak.sh" "Der Skill ist eingerichtet. Wenn du das hörst, läuft alles."
echo "Fertig. In Claude Code: /sprich — Vorlesen schalten: sprich auto on"

#!/bin/bash
# Install the "sprich" skill: Piper TTS + German voices + the skill itself.
set -euo pipefail

VOICE_DIR="${PIPER_VOICES:-$HOME/.local/share/piper-voices}"
SKILL_DIR="${CLAUDE_SKILLS:-$HOME/.claude/skills}/sprich"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

echo "→ Test"
"$SKILL_DIR/speak.sh" "Der Skill ist eingerichtet. Wenn du das hörst, läuft alles."
echo "Fertig. In Claude Code: /sprich"

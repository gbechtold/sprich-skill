#!/usr/bin/env python3
"""Take the last assistant text out of a session transcript and make it speakable.

    sprich-last-output.py <transcript.jsonl> [max_words]

Prints the finished text on stdout, or nothing when there is nothing to speak.
Strips what only gets in the way when heard: code blocks, paths, URLs, tables,
markup. A path read out loud is noise; the sentence around it is the content.
"""
import json
import re
import sys

DEFAULT_MAX_WORDS = 90


def last_text(path):
    """Return the text of the last assistant turn, joined across its blocks."""
    latest = ""
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            # Cheap prefilter: transcripts hold tool results and attachments too.
            if not line or '"assistant"' not in line:
                continue
            try:
                entry = json.loads(line)
            except ValueError:
                continue
            if entry.get("type") != "assistant":
                continue
            content = (entry.get("message") or {}).get("content")
            if not isinstance(content, list):
                continue
            parts = [b.get("text", "") for b in content
                     if isinstance(b, dict) and b.get("type") == "text"]
            text = "\n".join(p for p in parts if p.strip())
            if text.strip():
                latest = text
    return latest


def speakable(text, max_words):
    # Code blocks go entirely. Spoken code is noise.
    text = re.sub(r"```.*?```", " ", text, flags=re.S)
    text = re.sub(r"```.*", " ", text, flags=re.S)
    # Table rows go.
    text = "\n".join(l for l in text.split("\n") if not l.lstrip().startswith("|"))
    # Links keep their anchor text, the address drops.
    text = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", text)
    text = re.sub(r"https?://\S+", " ", text)

    # Inline code: a path is unhearable, a short identifier is not.
    def inline(match):
        inner = match.group(1)
        return " " if ("/" in inner or len(inner.split()) > 4) else inner

    text = re.sub(r"`([^`]*)`", inline, text)
    text = re.sub(r"(?<!\w)[~/][\w./@~-]{6,}", " ", text)
    # Markup and structure.
    text = re.sub(r"^#{1,6}\s*", "", text, flags=re.M)
    text = re.sub(r"\*\*([^*]+)\*\*", r"\1", text)
    text = re.sub(r"(?<!\w)\*([^*\n]+)\*(?!\w)", r"\1", text)
    text = re.sub(r"^\s*[-*+]\s+", "", text, flags=re.M)
    text = re.sub(r"^\s*>\s?", "", text, flags=re.M)
    text = re.sub(r"^\s*[-*_]{3,}\s*$", " ", text, flags=re.M)
    # Emoji and leftover symbols.
    text = re.sub(r"[\U0001F000-\U0001FAFF☀-➿️]", " ", text)

    # Line ends become sentence ends so the voice sets pauses. A full stop is
    # added only where the line has none, otherwise it sticks to the next word.
    lines = []
    for line in text.split("\n"):
        line = line.strip()
        if not line:
            continue
        if line[-1] not in ".!?:;,":
            line += "."
        lines.append(line)
    text = re.sub(r"\s{2,}", " ", " ".join(lines)).strip()

    words = text.split()
    if len(words) > max_words:
        clipped = " ".join(words[:max_words])
        cut = max(clipped.rfind(". "), clipped.rfind("? "), clipped.rfind("! "))
        text = clipped[: cut + 1] if cut > 40 else clipped + " …"
    return text


def main():
    if len(sys.argv) < 2:
        return 1
    max_words = int(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_MAX_WORDS
    raw = last_text(sys.argv[1])
    if not raw.strip():
        return 0
    done = speakable(raw, max_words)
    # Two words are a fragment, not a briefing. Stay silent rather than confuse.
    if len(done.split()) < 3:
        return 0
    print(done)
    return 0


if __name__ == "__main__":
    sys.exit(main())

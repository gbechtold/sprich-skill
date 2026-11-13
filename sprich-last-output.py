#!/usr/bin/env python3
"""Take the last assistant text out of a session transcript and make it speakable.

    sprich-last-output.py <transcript.jsonl> [max_words]   speech, ready to synthesise
    sprich-last-output.py --preamble <transcript.jsonl>    just the two bearing sentences
    sprich-last-output.py --json <transcript.jsonl> [n]    the parts separately

Two sentences of bearings come first: which project this is, and what the task
is. Spoken output has no scrollback, so someone who looks up after a minute away
has no way back to the context. The preamble is that way back, and it does not
count against the word ceiling - the ceiling governs the content.

Everything that only gets in the way when heard is stripped: code blocks, paths,
URLs, tables, markup. A path read out loud is noise; the sentence around it is
the content.
"""
import json
import os
import re
import sys

DEFAULT_MAX_WORDS = 90

# Folders that group projects rather than being one. The segment after them is
# the project. Override with SPRICH_PROJECT_CONTAINERS, comma separated.
CONTAINERS = set(
    c.strip() for c in
    os.environ.get("SPRICH_PROJECT_CONTAINERS", "BusinessProjects,Clients,Kunden").split(",")
    if c.strip()
)
PROJECT_ROOT = os.environ.get("SPRICH_PROJECT_ROOT", "Projects")

# Worktrees and scratch directories are named by a UUID or a hash. Spoken, that
# is thirty characters of noise in front of every briefing.
OPAQUE = re.compile(
    r"^(?:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|[0-9a-f]{12,}|\d+)$",
    re.I,
)


def read_entries(path):
    """Yield the parsed transcript lines, skipping anything unreadable."""
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                yield json.loads(line)
            except ValueError:
                continue


def collect(path):
    """One pass over the transcript for everything the output needs."""
    found = {"text": "", "cwd": "", "title": "", "prompt": ""}
    for entry in read_entries(path):
        kind = entry.get("type")
        if kind == "assistant":
            if entry.get("cwd"):
                found["cwd"] = entry["cwd"]
            content = (entry.get("message") or {}).get("content")
            if isinstance(content, list):
                parts = [b.get("text", "") for b in content
                         if isinstance(b, dict) and b.get("type") == "text"]
                text = "\n".join(p for p in parts if p.strip())
                if text.strip():
                    found["text"] = text
        elif kind == "ai-title" and entry.get("aiTitle"):
            found["title"] = entry["aiTitle"]
        elif kind == "last-prompt" and entry.get("lastPrompt"):
            found["prompt"] = entry["lastPrompt"]
    return found


def readable(text):
    """Strip folder bookkeeping so a name survives being read out loud."""
    words = []
    for word in text.split():
        # A date or number prefix identifies a folder, not a project.
        word = re.sub(r"^\d{2,8}[-_]", "", word)
        # StarsBridge is two words to a listener, one to a filesystem.
        word = re.sub(r"([a-z])([A-Z])", r"\1 \2", word)
        if word:
            words.append(word)
    return " ".join(words)


def tidy(name):
    """Turn one path segment into something worth hearing, or nothing."""
    name = re.sub(r"^\d{2,8}[-_]", "", name)
    if OPAQUE.match(name):
        return ""
    return readable(name.replace("-", " ").replace("_", " "))


def locate(cwd):
    """Name where the work happens, and say whether that is a project.

    Returns (name, is_project). Calling a stray working directory a project
    would be a claim the path does not support, so the caller words it
    differently instead.
    """
    if not cwd:
        return "", False
    cwd = cwd.rstrip("/")
    if cwd == os.path.expanduser("~").rstrip("/"):
        return "", False
    segments = [s for s in cwd.split("/") if s]
    if PROJECT_ROOT in segments:
        rest = [s for s in segments[segments.index(PROJECT_ROOT) + 1:]
                if s not in CONTAINERS]
        for segment in rest:
            name = tidy(segment)
            if name:
                return name, True
    # No project root in the path. Walk back from the end to the first segment
    # that is a name rather than an identifier.
    for segment in reversed(segments):
        name = tidy(segment)
        if name:
            return name, False
    return "", False


def shorten(text, max_words):
    """Cut to a sentence boundary where one is near, otherwise to the word."""
    words = text.split()
    if len(words) <= max_words:
        return text
    clipped = " ".join(words[:max_words])
    cut = max(clipped.rfind(". "), clipped.rfind("? "), clipped.rfind("! "))
    return clipped[: cut + 1] if cut > 40 else clipped + " …"


def task_name(found):
    """The task as one short line: the session title, else the last prompt."""
    task = readable((found.get("title") or "").strip())
    if not task:
        task = shorten(readable(re.sub(r"\s+", " ", found.get("prompt", "")).strip()), 14)
    return task


def preamble(found):
    """Two sentences: which project, and what the task is."""
    project, is_project = locate(found.get("cwd", ""))
    if is_project:
        first = "Projekt {}.".format(project)
    elif project:
        first = "Ordner {}, kein Projekt.".format(project)
    else:
        first = "Ohne Projekt, Heimverzeichnis."
    task = task_name(found)
    if not task:
        return first
    if task[-1] not in ".!?":
        task += "."
    return "{} Aufgabe: {}".format(first, task)


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
    return shorten(re.sub(r"\s{2,}", " ", " ".join(lines)).strip(), max_words)


def main():
    argv = sys.argv[1:]
    mode = "speech"
    if argv and argv[0] in ("--preamble", "--json"):
        mode = argv[0][2:]
        argv = argv[1:]
    if not argv:
        return 1
    max_words = int(argv[1]) if len(argv) > 1 else DEFAULT_MAX_WORDS

    found = collect(argv[0])
    head = preamble(found)
    if mode == "preamble":
        print(head)
        return 0

    body = ""
    if found["text"].strip():
        candidate = speakable(found["text"], max_words)
        # Two words are a fragment, not a briefing. Stay silent rather than
        # confuse someone who cannot scroll back.
        if len(candidate.split()) >= 3:
            body = candidate

    if mode == "json":
        # The caller wants the parts separately: a notification puts the project
        # in the title and the task in the subtitle, where one long line would
        # be truncated by the window rather than by us.
        print(json.dumps({
            "project": locate(found.get("cwd", ""))[0],
            "task": task_name(found),
            "preamble": head,
            "body": body,
            "speech": "{} {}".format(head, body) if body else "",
        }, ensure_ascii=False))
        return 0

    if not body:
        return 0
    print("{} {}".format(head, body))
    return 0


if __name__ == "__main__":
    sys.exit(main())

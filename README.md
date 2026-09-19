# sprich — spoken session briefings for Claude Code

A Claude Code skill that **reads your session status out loud** in German, using
a local Piper TTS voice. No API, no network, no per-call cost.

You type `/sprich` and you hear the last thing that happened — the result of the
last step, in language you can act on. Ask again without anything having changed
and it simply repeats itself, word for word, from cache.

For the full picture, `/sprich briefing` gives you four things:

1. which project you are in,
2. what the current task is and why,
3. **what the last step actually produced** — the number, the finding,
4. two or three numbered options, each with its cost and consequence.

Then you answer with `2`.

## The point: decidable, not abstract

Most status output is written to be skimmed. Spoken status has no scrollbar — if
you miss a word, you cannot glance back. So this skill enforces a different
standard, and that standard is most of what it is:

**No state words without content.** "done", "tested", "works", "created" describe
that something happened, not what came out of it. Every one of them has to carry
the number or finding that makes it actionable.

**Every option carries three things** — what happens if you pick it, what it
costs, and what it unblocks. An option label like "fix the environment" is not an
option: to choose it you would already need to know what is broken and what the
repair costs, which is exactly what the briefing is supposed to tell you.

Bad — nothing here is decidable:

> The skill is built and tested. Your options. One: try the skill.
> Two: repair the broken environment. Three: close the session.

Good — each option stands on its own:

> The skill runs. For a half-minute briefing it computes six seconds, so it never
> falls behind playback. Your options. First: repair the environment — the paths
> broke when the folder was renamed, about ten minutes of work, after which the
> voice-cloning app runs again. Second: leave it and wrap up — the repair will
> keep.

The full rule set lives in [`SKILL.md`](SKILL.md): a hard 110-word ceiling
(~40 seconds), a ban on speaking paths, URLs, filenames, hashes and flags, ordinal
numbers instead of digits (Piper reads "1." as a date), and the requirement to
always print the same content to the terminal so the options can be answered by
typing.

## Install

```bash
git clone https://github.com/gbechtold/sprich-skill.git
cd sprich-skill
./install.sh
```

Needs [uv](https://docs.astral.sh/uv/) and `ffmpeg` (for `ffplay`). The installer
adds Piper, downloads five German voices (~322 MB) to
`~/.local/share/piper-voices`, and copies the skill to `~/.claude/skills/sprich`.

## Use

| Command | What happens |
|---|---|
| `/sprich` | Speak the last output. Already spoken? Repeat it verbatim. |
| `/sprich briefing` | Full four-part briefing from the current context |
| `/sprich <text>` | Speak exactly that text |
| `/sprich medium` | Same as the default, with the faster voice |

**Repeating is free.** Every utterance is cached as raw audio, so `--repeat`
replays it with no synthesis at all — 0.16 s of CPU instead of 4.9 s. It also
sounds identical, which is the point: someone asking "again" wants the same
words back, not a paraphrase they have to parse a second time.

## One line, with transport controls

The skill prints exactly one line and nothing else:

```
▶ 260919145843 Response Steuerungs-Probe.wav · 0:20 · ⏮ !sprich rw · ⏯ !sprich pp · ⏹ !sprich stop · 📄 !sprich text
```

**Playback runs detached in the background.** The call returns as soon as
synthesis finishes — about four seconds for a half-minute utterance, not thirty —
so the session keeps working while it speaks. That is also what makes pause
meaningful: you cannot pause something that blocks the turn.

| Command | Effect |
|---|---|
| `sprich pp` | pause / resume (toggle) |
| `sprich rw` | rewind to the start |
| `sprich stop` | stop |
| `sprich again` | replay the last utterance, no synthesis |
| `sprich text` | print the last spoken wording |
| `sprich ls` | list cached utterances |

Files are named `YYMMDDHHMMSS Response <Title>.wav` and live in `.state/audio`.
Every invocation sweeps anything older than an hour (`SPRICH_KEEP_MIN` changes
the window). Note `-mmin`, not `-mtime`: `-mtime` counts whole days and would
never match a one-hour window.

The trade-off is worth stating: with a single line, **the options are heard, not
read**. An option you cannot remember after hearing it once is useless — keep
them short and keep them to three. `sprich text` prints the wording when you need
to look something up.

The script also works standalone:

```bash
./speak.sh --title "Morning" "Guten Morgen."
echo "Aus einer Pipe." | ./speak.sh --title "Pipe"
```

| Flag | Effect |
|---|---|
| *(none)* | `thorsten-high` — the chosen voice |
| `--title "…"` | speaking filename |
| `--voice medium` | `thorsten-medium` — faster, slightly flatter |
| `--voice emotional` | `thorsten_emotional`, multi-speaker (`-s 0…6`) |
| `--voice kerstin` / `--voice eva` | female voices, 16 kHz |

Override locations with `PIPER_VOICES`, `PIPER_PYTHON` and `SPRICH_STATE`.

## Voice benchmarks

Fourteen German voices measured head to head — Piper against all nine macOS `say`
voices, including the finding that eight of the nine macOS personas share one
prosody engine and differ only in timbre: [`docs/voice-comparison.md`](docs/voice-comparison.md).

## Notes

- Playback is detached, so it survives the call that started it and keeps going
  while the session works. `sprich stop` ends it.
- Briefing content and rules are German. The mechanism is language-agnostic:
  swap the voice in `speak.sh` and rewrite `SKILL.md` for your language.
- Runs on CPU via onnxruntime. No GPU needed.

## License

MIT

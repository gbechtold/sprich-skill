# sprich — spoken session briefings for Claude Code

A Claude Code skill that **reads your session status out loud** in German, using
a local Piper TTS voice. No API, no network, no per-call cost.

You type `/sprich`, and you hear four things:

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
| `/sprich` | Build a briefing from the current context and speak it |
| `/sprich <text>` | Speak exactly that text |
| `/sprich medium` | Briefing with the faster voice |

The script also works standalone:

```bash
./speak.sh "Guten Morgen."
echo "Aus einer Pipe." | ./speak.sh
./speak.sh --voice medium --save out.wav "Gespeichert und gesprochen."
```

| Flag | Effect |
|---|---|
| *(none)* | `thorsten-high` — best quality, 4.3× realtime |
| `--voice medium` | `thorsten-medium` — 20× realtime, slightly flatter |
| `--voice emotional` | `thorsten_emotional`, multi-speaker (`-s 0…6`) |
| `--voice kerstin` / `--voice eva` | female voices, 16 kHz |
| `--save FILE.wav` | also write a WAV |

Playback is streamed: Piper writes raw audio, `ffplay` starts on the first
sentence, so you do not wait for the full synthesis.

Override locations with `PIPER_VOICES` and `PIPER_PYTHON`.

## Voice benchmarks

Fourteen German voices measured head to head — Piper against all nine macOS `say`
voices, including the finding that eight of the nine macOS personas share one
prosody engine and differ only in timbre: [`docs/voice-comparison.md`](docs/voice-comparison.md).

## Notes

- The skill blocks the turn while speaking. A 30-second briefing costs 30 seconds
  before work resumes. That is deliberate — in the background the audio would
  collide with the next tool output.
- Briefing content and rules are German. The mechanism is language-agnostic:
  swap the voice in `speak.sh` and rewrite `SKILL.md` for your language.
- Runs on CPU via onnxruntime. No GPU needed.

## License

MIT

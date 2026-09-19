# German voice comparison — Piper vs. macOS `say`

Measured 2026-09-19 on an Intel Mac, same sentence for every voice:

> Guten Tag, hier ist Stars Media IT. Ihre Kampagne läuft seit dem 19. September
> und hat bereits 1.240 Klicks erzielt. Für Rückfragen erreichen Sie uns jederzeit.

## Piper

| Voice | Audio | Rate | Synthesis | Realtime factor |
|---|---|---|---|---|
| `de_DE-thorsten-high` | 11.28 s | 22 kHz | 3.34 s | 3.4× |
| `de_DE-thorsten-medium` | 10.73 s | 22 kHz | 0.79 s | 13.6× |
| `de_DE-thorsten_emotional-medium` | 11.37 s | 22 kHz | 0.82 s | 13.9× |
| `de_DE-kerstin-low` | 12.10 s | 16 kHz | 0.93 s | 13.0× |
| `de_DE-eva_k-x_low` | 13.92 s | 16 kHz | 0.73 s | 19.1× |

On a longer briefing (~70 words) the gap widens: `thorsten-high` needs 5.9 s of
compute for 25.4 s of audio, `thorsten-medium` only 1.3 s. Both stay well ahead
of playback, so streaming never stutters.

`thorsten_emotional` is multi-speaker — `-s 0…6` selects the emotion.

## macOS `say`, German voices

| Voice | Audio | Rate | Synthesis |
|---|---|---|---|
| Anna (legacy) | 12.56 s | 22 kHz | 0.94 s |
| Eddy, Flo, Grandma, Grandpa, Reed, Rocko, Sandy, Shelley | **13.69 s each** | 22 kHz | ~0.47 s |

The eight modern personas produce **byte-identical durations**. They share one
prosody engine and differ only in timbre — verified distinct by md5, so it is not
a fallback to a single voice, but you get no variation in rhythm or pacing.
Anna is the old legacy voice and the only one with its own timing.

## Why Piper for this skill

`say` is faster to start and needs no install. But a briefing you listen to
several times a day benefits from the more natural cadence, and Piper's
`thorsten-high` is noticeably less flat on long sentences. Piper also gives you
the same voice on Linux, which `say` does not.

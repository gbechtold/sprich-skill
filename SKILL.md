---
name: sprich
description: Liest den aktuellen Sitzungsstand laut vor — Projekt, Aufgabe mit Ziel, Ergebnis des letzten Schritts und nummerierte Optionen, wie es weitergeht. Lokale Sprachausgabe über Piper (Thorsten High, offline, keine API). Nutze diesen Skill bei "/sprich", "lies mir vor", "sag mir wo wir stehen", "Status vorlesen", "Briefing" — und wenn der User erkennbar vom Bildschirm weg ist und einen Stand hören will. Mit Argument "/sprich <Text>" wird genau dieser Text gesprochen statt des Briefings.
---

# sprich

Sprachausgabe des Sitzungsstands. Offline, lokal, ohne API-Call.

## Zwei Modi

| Aufruf | Verhalten |
|---|---|
| `/sprich` | Briefing aus dem aktuellen Kontext bauen und vorlesen |
| `/sprich <Text>` | Genau diesen Text vorlesen, kein Briefing |
| `/sprich medium` | Briefing mit der schnelleren Stimme (Thorsten Medium) |

## Das Briefing — Aufbau

Genau vier Teile, in dieser Reihenfolge:

1. **Projekt** — ein Satz. Welches Projekt, worum es geht.
2. **Aufgabe mit Ziel** — ein Satz. Woran wir arbeiten und wozu.
3. **Letzter Output** — ein bis zwei Sätze. Nicht *dass* etwas fertig ist,
   sondern **was herauskam**: die Zahl, der Befund, die Konsequenz.
4. **Optionen** — zwei bis drei, jeweils zwölf bis zwanzig Wörter, jede mit
   Handlung, Kosten und Nutzen.

## Regel 1 — entscheidbar sprechen

Das Briefing hat einen einzigen Zweck: **der User soll sofort danach entscheiden
können, ohne nachzufragen und ohne auf den Bildschirm zu schauen.** Alles andere
ist Dekoration.

Daraus folgt die wichtigste Regel: **keine Zustandswörter ohne Inhalt.**
„fertig", „getestet", „läuft", „angelegt", „geprüft", „erfolgreich" sagen für sich
genommen nichts. Sie beschreiben, dass etwas passiert ist — nicht *was dabei
herauskam*. Jedes dieser Wörter muss die Zahl, den Befund oder die Konsequenz
mitbringen, die es trägt.

Und jede Option muss **drei Dinge** hörbar machen:

1. **Was passiert**, wenn er sie wählt — konkrete Handlung, kein Etikett.
2. **Was es kostet** — Zeit, Risiko, Aufwand. Grob reicht, „ein paar Minuten".
3. **Warum sie zur Wahl steht** — was sie löst oder freimacht.

Ein Optionsetikett wie „Umgebung reparieren" ist keine Option. Um es zu wählen,
müsste man schon wissen, was kaputt ist und was die Reparatur kostet — genau das
Wissen, das das Briefing liefern soll.

### Vorher / Nachher

Schlecht — abstrakt, man kann nichts entscheiden:

> Letzter Output: der Skill ist gebaut und getestet. Deine Optionen. Erstens:
> Skill erproben. Zweitens: die defekte Chatterbox-Umgebung reparieren.
> Drittens: Session abschließen.

Gut — jede Option steht für sich:

> Der Vorlese-Skill läuft. Für ein halbminütiges Briefing rechnet er sechs
> Sekunden, hängt also nie hinterher. Deine Optionen. Erstens: die Chatterbox-Umgebung
> reparieren — die Pfade sind seit einer Ordner-Umbenennung kaputt, gut zehn Minuten
> Arbeit, danach läuft die Stimmklon-App wieder. Zweitens: es dabei belassen und
> abschließen — die Reparatur läuft dir nicht weg.

## Regel 2 — hörbar schreiben

Gesprochener Text hat keine Scrollbar. Wer etwas überhört, kann nicht
zurückspringen. Deshalb:

- **Höchstens 110 Wörter**, rund 40 Sekunden. Lieber **drei** Optionen mit
  Kontext als fünf ohne. Wenn es eng wird, fällt eine Option weg — nie der Kontext.
- **Keine Pfade, URLs, Dateinamen, Hashes, IDs, Flags, Code.** Das klingt
  gesprochen wie Kauderwelsch. Statt `/Users/…/260919-voice-test/out/` sag
  „der Testordner im Chatterbox-Projekt". Statt `exit code 1` sag „mit Fehler
  abgebrochen". Statt `de_DE-thorsten-high` sag „Thorsten High".
- **Fachbegriffe übersetzen oder erklären.** „venv", „map_location", „Symlink"
  versteht man beim Hören nicht nebenbei. Entweder umschreiben („die
  Python-Umgebung") oder in einem Halbsatz erden.
- **Zahlen ausschreiben, wo sie stolpern:** „vierzehn Sprachproben". Bei
  Geldbeträgen, Uhrzeiten und Daten ist die Ziffer richtig.
- **Optionen mit Ordnungszahl** — „Erstens", „Zweitens". Piper liest „1." als Datum.
- **Kurze Hauptsätze**, ein Gedanke pro Satz (AGENTS.md §4).
- Bei Fehlern: **erst der Blocker**, dann die Optionen. Nicht beschönigen.
- Gibt es eine Frist oder einen Preis fürs Nichtstun, gehört er ins Briefing.

## Regel 3 — immer auch ins Terminal

Sprache allein reicht nicht: geantwortet wird getippt. Vor dem Sprechen denselben
Inhalt kompakt zeigen, Optionen nummeriert, **jede mit ihrer Konsequenz** — nicht
die Kurzfassung, sonst fehlt beim Nachlesen genau das, was die Wahl trägt:

```
Projekt   — …
Aufgabe   — …
Ergebnis  — … (mit Zahl/Befund, nicht „erledigt")

1. … — Kosten/Folge
2. … — Kosten/Folge
3. … — Kosten/Folge
```

So genügt „2" als Antwort.

## Ausführen

Text an das Skript geben, es synthetisiert und spielt ab. Playback startet beim
ersten Satz, es wird also nicht auf die vollständige Synthese gewartet.

```bash
"$HOME"/.claude/skills/sprich/speak.sh "Der fertige Briefing-Text."
```

Längere Texte über stdin, das spart Quoting-Ärger:

```bash
cat <<'EOF' | "$HOME"/.claude/skills/sprich/speak.sh
Der fertige Briefing-Text.
EOF
```

Das Skript blockiert bis zum Ende der Wiedergabe. Ein 30-Sekunden-Briefing hält
den Turn also 30 Sekunden auf — das ist so gewollt, nicht in den Hintergrund
schicken.

## Optionen des Skripts

| Flag | Wirkung |
|---|---|
| *(ohne)* | Thorsten High — beste Qualität, 4,3× Echtzeit |
| `--voice medium` | Thorsten Medium — 20× Echtzeit, minimal flacher |
| `--voice emotional` | Thorsten Emotional, multi-speaker (`-s 0…6` im Modell) |
| `--voice kerstin` / `--voice eva` | weibliche Stimmen, nur 16 kHz |
| `--save /pfad/datei.wav` | zusätzlich als WAV sichern |

## Setup-Zustand

Piper liegt als uv-Tool unter `$HOME/.local/bin/piper`, die Stimmen
in `$HOME/.local/share/piper-voices` (fünf deutsche, 322 MB).
Weitere Stimmen:

```bash
$HOME/.local/share/uv/tools/piper-tts/bin/python -m piper.download_voices \
  --data-dir $HOME/.local/share/piper-voices <name>
```

Läuft vollständig offline auf CPU über onnxruntime. Kein Netzwerk, keine API,
keine Kosten pro Aufruf.

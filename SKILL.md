---
name: sprich
description: Spricht den Sitzungsstand laut vor — lokal über Piper (Thorsten High, offline, keine API). Ohne Argument wird der letzte Output gesprochen; war der schon zu hören, wird er wörtlich wiederholt. `/sprich briefing` gibt das volle Vier-Teile-Briefing (Projekt, Aufgabe mit Ziel, Ergebnis, nummerierte Optionen mit Kosten und Nutzen). Nutze diesen Skill bei "/sprich", "lies mir vor", "sag mir wo wir stehen", "nochmal", "wiederhol das", "Status vorlesen" — und wenn der User erkennbar vom Bildschirm weg ist. `/sprich <Text>` spricht genau diesen Text.
---

# sprich

Sprachausgabe des Sitzungsstands. Offline, lokal, ohne API-Call.

## Was bei welchem Aufruf passiert

| Aufruf | Verhalten |
|---|---|
| `/sprich` | **Den letzten Output sprechen.** Wurde der bereits gesprochen: nur wiederholen. |
| `/sprich briefing` | Volles Vier-Teile-Briefing aus dem Kontext |
| `/sprich <Text>` | Genau diesen Text sprechen |
| `/sprich medium` | wie der Default, aber mit der schnelleren Stimme |

## Der Default: letzter Output, sonst Wiederholung

Bei `/sprich` ohne Argument sind es **zwei Schritte, in dieser Reihenfolge**:

**Schritt 1 — nachsehen, was zuletzt gesprochen wurde.**

```bash
"$HOME"/.claude/skills/sprich/speak.sh text
```

**Schritt 2 — vergleichen und entscheiden.**

- Ist seitdem **nichts sachlich Neues** passiert — der letzte Output ist derselbe, den
  der Cache enthält —, dann **wörtlich wiederholen**, nicht neu formulieren:

  ```bash
  "$HOME"/.claude/skills/sprich/speak.sh again
  ```

  Das spielt das zwischengespeicherte Audio ab, ohne neu zu synthetisieren: statt fünf
  Sekunden Rechenzeit null. Und es klingt identisch — wer „nochmal" sagt, will dasselbe
  hören, nicht eine Variante davon. Eine umformulierte Wiederholung zwingt zum erneuten
  Zuhören statt zum Nachhören.

- Gibt es einen **neuen** letzten Output, dann diesen nach den Regeln unten sprechbar
  machen und sprechen. Der Cache aktualisiert sich dabei von selbst.

Der letzte Output ist das, was zuletzt an den User berichtet wurde — das Ergebnis des
letzten Arbeitsschritts, nicht der Prozess dorthin. Enthielt er Optionen, gehören sie
mit; enthielt er keine, wird keine erfunden. Projekt und Aufgabe kommen nur dazu, wenn
der Output ohne sie unverständlich wäre. Es gilt trotzdem alles aus den Regeln unten:
Wortgrenze, keine Pfade, Ordnungszahlen — und die Statuszeile in die Antwort übernehmen.

Exit-Code 2 von `text` oder `again` heißt: in dieser Session wurde noch nichts
gesprochen. Dann ist der letzte Output zwangsläufig neu — normal sprechen.

## Das Briefing — Aufbau (`/sprich briefing`)

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

## Regel 3 — die Statuszeile gehört in die Antwort, nicht in die Tool-Ausgabe

**Das Wichtigste zuerst: der User sieht die Ausgabe des Skripts nicht.** Sie landet in
der Tool-Ausgabe, und die wird ihm nicht zuverlässig angezeigt. Ein direkter Weg ins
Terminal existiert nicht — der Prozess hat kein TTY (`tty` meldet `not a tty`, ein
`> /dev/tty` scheitert mit `device not configured`).

Deshalb: **die Zeile, die das Skript ausgibt, wörtlich in die eigene Antwort übernehmen**,
als Codeblock. Das ist keine Dopplung — es ist die einzige Fassung, die der User zu
sehen bekommt.

```
[>]  260919150252 Response ASCII-Probe.wav  0:03  |<< !sprich rw   >|| !sprich pp   [x] !sprich stop   [=] !sprich text
     [1] Dateinamen zurueckdrehen - eine Minute
     [2] Optionszeilen dauerhaft mitdrucken - sofort wirksam
     [3] So lassen und im Alltag erproben
```

Reines ASCII, damit nichts an Terminal-Schrift oder Zeichenbreite hängt. Das
Transport-Icon links zeigt den Zustand: `[>]` läuft, `[||]` pausiert, `[x]` gestoppt.
Gilt genauso für die Steuerbefehle — auch nach `pp`, `rw` oder `again` gehört die
zurückgegebene Zeile in die Antwort, sonst sieht der User den Zustandswechsel nicht.

**Und sonst nichts.** Kein Block mit Projekt und Aufgabe darüber, keine Zusammenfassung
des Gesprochenen darunter. Höchstens ein kurzer Satz, wenn etwas zu sagen ist, das
nicht im Gesprochenen steckt. Wer hören will, soll hören — sonst steht alles doppelt
da und die Sprachausgabe war überflüssig.

Die Optionen stehen aus einem Grund dabei: eine gehörte Option, die man nicht nachlesen
kann, ist nach zehn Sekunden weg — man müsste sich beim Zuhören Notizen machen, um
antworten zu können. Übergib sie mit `--option`, einmal pro Option, in derselben
Reihenfolge und Formulierung wie gesprochen:

```bash
speak.sh --title "Offene Entscheidungen" \
  --option "Dateinamen zurueckdrehen - eine Minute" \
  --option "So lassen und erproben" \
  "Der gesprochene Text mit Erstens und Zweitens."
```

Kurz halten: die Zeile ist die Gedächtnisstütze zum Gehörten, nicht seine Wiederholung.
Ein Halbsatz mit der Kostenangabe reicht. Ohne Optionen im Text wird `--option`
weggelassen — dann bleibt es bei der einen Zeile.

Gesprochen wird mit Ordnungszahlen („Erstens", „Zweitens"), gedruckt mit `[1]`, `[2]`.
Beides meint dieselbe Option, und der User antwortet mit der Ziffer.

## Ausführen

```bash
"$HOME"/.claude/skills/sprich/speak.sh --title "Kurzer Titel" "Der fertige Text."
```

Längeres über stdin, das spart Quoting-Ärger:

```bash
cat <<'EOF' | "$HOME"/.claude/skills/sprich/speak.sh --title "Kurzer Titel"
Der fertige Text.
EOF
```

**Die Wiedergabe läuft im Hintergrund.** Das Skript kehrt zurück, sobald die Synthese
fertig ist — bei einem halbminütigen Briefing nach rund vier Sekunden, nicht nach
dreißig. Die Sitzung arbeitet weiter, während gesprochen wird. Nicht auf das Ende
warten und nicht nachschieben.

`--title` gibt der Datei einen sprechenden Namen. Ohne Titel werden die ersten Wörter
des Textes genommen, was meist schlechter ist — also immer einen setzen, drei bis fünf
Wörter, die den Inhalt benennen.

## Steuerung

Die Zeile nennt sie mit, der User tippt sie mit `!` davor:

| Befehl | Wirkung |
|---|---|
| `!sprich pp` | Pause bzw. Fortsetzen (Umschalter), Icon wechselt `[>]` ↔ `[||]` |
| `!sprich rw` | von vorn abspielen |
| `!sprich stop` | beenden |
| `!sprich again` | letzte Ausgabe erneut, ohne Synthese — samt ihrer Optionszeilen |
| `!sprich text` | zuletzt gesprochenen Wortlaut ausgeben |
| `!sprich ls` | zwischengespeicherte Ausgaben auflisten |

Audiodateien liegen unter `.state/audio` und werden bei jedem Aufruf gekehrt:
alles älter als eine Stunde fliegt raus (`SPRICH_KEEP_MIN` ändert das Fenster).

## Optionen des Skripts

| Flag | Wirkung |
|---|---|
| *(ohne)* | Thorsten High — die gesetzte Stimme, nicht ohne Rücksprache ändern |
| `--title "…"` | sprechender Dateiname |
| `--option "…"` | eine Optionszeile, wiederholbar; Nummerierung setzt das Skript |
| `--voice medium` | Thorsten Medium — schneller, minimal flacher |
| `--voice emotional` | Thorsten Emotional, multi-speaker (`-s 0…6` im Modell) |
| `--voice kerstin` / `--voice eva` | weibliche Stimmen, 16 kHz |

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

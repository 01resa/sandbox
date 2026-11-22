---
description: Ein GitHub-Issue analysieren und den Umsetzungsplan als Kommentar ins Issue schreiben
---

Du planst die Umsetzung eines GitHub-Issues. In diesem Durchgang wird **nichts
implementiert**, kein Branch angelegt und nichts committet.

## Issue

$ARGUMENTS

Issue-Nummer oder Issue-URL. Fehlt die Angabe, frage danach, bevor du beginnst.

## Schritt 0: Kontext ermitteln

Fuehre das zuerst aus und verwende die Ausgabe in allen weiteren Schritten:

```sh
echo "Verzeichnis: $(pwd)"
R="$(gh repo view "$(git remote get-url origin 2>/dev/null)" --json nameWithOwner -q .nameWithOwner 2>/dev/null)"
echo "Ziel-Repo:   ${R:-nicht ermittelbar (kein Git-Repository oder kein origin)}"
[ -n "$R" ] && gh repo view "$R" --json isFork,parent \
  -q 'if .isFork then "Fork:        ja, von \(.parent.owner.login)/\(.parent.name)" else "Fork:        nein" end'
echo "Branch:      $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '-')"
```

Den Wert `Ziel-Repo` gibst du bei **jedem** `gh`-Aufruf mit `--repo` an. In
einem Fork zielt `gh` sonst auf das Original.

## Vorgehen

1. **Issue lesen.** Titel, Beschreibung, Labels, vorhandene Kommentare und
   verlinkte Pull Requests - ueber die GitHub-Werkzeuge des MCP-Servers oder
   `gh issue view <nr> --repo <Ziel-Repo> --comments`.

   Gibt es bereits einen Kommentar, der mit `## Umsetzungsplan` beginnt, wird
   nicht neu geplant:
   - Sind danach weitere Kommentare entstanden oder wurde die Beschreibung
     geaendert, brich ab und verweise auf `/replan-item <nummer>`.
   - Sonst melde, dass der Plan aktuell ist, und frage, ob er trotzdem
     vollstaendig neu geschrieben werden soll. Nur bei ausdruecklicher
     Zustimmung weiter.

2. **Code verstehen.** Suche die betroffenen Stellen im Repository, sieh dir
   vergleichbare Implementierungen an und lies die Build- und Testbefehle aus
   README, Makefile, package.json, go.mod o. ae. ab. Rate nichts, was du
   nachlesen kannst.

3. **Rueckfragen.** Sind die Anforderungen widerspruechlich oder lueckenhaft,
   stelle hoechstens drei gezielte Fragen und warte auf Antwort.

4. **Plan formulieren** mit genau diesen Abschnitten:
   - *Ziel* - ein bis drei Saetze
   - *Betroffene Dateien* - mit kurzer Begruendung je Datei
   - *Schritte* - nummeriert, jeder einzeln umsetzbar und ueberpruefbar
   - *Tests* - welche, wie ausgefuehrt, was neu dazukommt
   - *Offene Punkte*
   - *Definition of Done* - uebernimmt die `### Akzeptanzkriterien` des Issues
     als Checkliste und ergaenzt Tests, Doku und Build; fehlen
     Akzeptanzkriterien, leite sie aus dem Issue ab und nenne das unter
     *Offene Punkte*
   - *Aenderungshistorie* - beim ersten Plan genau eine Zeile:
     `- **v1** (JJJJ-MM-TT): erster Plan`

5. **Plan ins Issue schreiben.** Als Kommentar, dessen erste Zeile genau
   `## Umsetzungsplan` lautet - daran findet `/implement-item` ihn spaeter
   wieder. Wird ein bestehender Plan auf ausdruecklichen Wunsch neu
   geschrieben (siehe Schritt 1), bearbeite diesen Kommentar, statt einen
   zweiten anzulegen.

6. **Zusammenfassung.** Fuenf bis zehn Zeilen: was geplant ist und was als
   naechstes zu entscheiden waere. Schliesse mit dem Hinweis, dass die
   Umsetzung ueber `/implement-item <nummer>` laeuft - und dass nach Antworten
   auf die offenen Punkte `/replan-item <nummer>` den Plan nachzieht.

## Regeln

- Keine Codeaenderungen, keine Commits, keine Branches, keine Pull Requests.
- Was du nicht sicher weisst, gehoert unter *Offene Punkte* - nicht in die
  Schritte.
- Schreibe den Plan so, dass ihn jemand ohne diesen Chatverlauf abarbeiten kann.
- Antworte auf Deutsch.

---
description: Den geplanten Stand eines GitHub-Issues umsetzen, testen und als Pull Request einreichen
---

Du setzt ein geplantes GitHub-Issue um und reichst das Ergebnis als Pull Request
ein.

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
echo "Ziel-Branch: ${GIT_DEFAULT_BRANCH:-main}"
git status -sb | head -20
```

Den Wert `Ziel-Repo` gibst du bei **jedem** `gh`-Aufruf mit `--repo` an. In
einem Fork zielt `gh` sonst auf das Original - auch `gh pr create`. Ist das
Repo ein Fork, frage einmal nach, ob der Pull Request gegen den Fork oder
gegen das Original gehen soll; voreingestellt ist der Fork.

## Vorgehen

1. **Plan holen.** Lies die Kommentare des Issues und nimm den Kommentar, der
   mit `## Umsetzungsplan` beginnt - ueber die GitHub-Werkzeuge des MCP-Servers
   oder `gh issue view <nr> --repo <Ziel-Repo> --comments`. Gibt es keinen,
   brich ab und weise darauf hin, dass zuerst `/plan-item <nummer>` laufen
   sollte.

   **Ist der Plan noch aktuell?** Stichtag ist das `updated_at` des
   Plan-Kommentars:

   ```sh
   gh api "repos/<Ziel-Repo>/issues/<nr>/comments" --paginate \
     --jq '.[] | {id, created_at, updated_at, first_line: (.body | split("\n")[0])}'
   ```

   Gibt es danach Kommentare, deren erste Zeile nicht mit `## Umsetzungsplan`,
   `### Umsetzungsplan aktualisiert` oder `## Review` beginnt, oder wurde die
   Issue-Beschreibung danach geaendert, halte an: nenne die neuen Beitraege und
   empfiehl `/replan-item <nummer>`. Nur wenn der Nutzer ausdruecklich sagt,
   dass sie den Plan nicht beruehren, geht es weiter.

2. **Arbeitsstand pruefen.** Sind uncommittete Aenderungen vorhanden, frage, wie
   damit verfahren werden soll. Hole dann den Ziel-Branch auf den neuesten Stand
   und lege davon `feature/<nummer>-<slug>` an.

3. **Schrittweise umsetzen.** Arbeite die Schritte des Plans der Reihe nach ab
   und halte dich an die vorhandenen Muster im Projekt. Weicht die Umsetzung vom
   Plan ab, halte die Abweichung mit Begruendung fest.

   *Offene Punkte* des Plans: Hat ein Punkt einen *Vorschlag*, uebernimm ihn und
   nenne ihn im PR-Text als getroffene Entscheidung. Hat er keinen, frage nach,
   bevor du den betroffenen Schritt umsetzt.

4. **Pruefen.** Fuehre Tests, Linter und Build aus, so wie es das Projekt
   vorsieht. Gibt es keine Tests fuer den geaenderten Bereich, lege welche an,
   sofern das zum Projekt passt. Erst weiter, wenn alles gruen ist.

5. **Committen.** Kleine, nachvollziehbare Commits; Betreff im Imperativ,
   Koerper mit dem Warum. Jeder Commit verweist mit `Refs #<nummer>` auf das
   Issue.

6. **Pull Request anlegen.** Branch pushen, Pull Request gegen den Ziel-Branch
   erstellen - ueber die GitHub-Werkzeuge des MCP-Servers oder
   `gh pr create --repo <Ziel-Repo> --base <Ziel-Branch> --head <branch>`.
   Soll der PR aus einem Fork ins Original gehen, lautet es
   `--repo <Original> --head <fork-owner>:<branch>`.
   Der Beschreibungstext enthaelt:
   - was geaendert wurde und warum
   - wie es getestet wurde
   - bewusste Abweichungen vom Plan
   - abschliessend `Closes #<nummer>`

7. **Zusammenfassung.** Nenne PR-URL, Branch, geaenderte Dateien, Testergebnis
   und alles, was offen bleibt. Schliesse mit dem Hinweis, dass die Pruefung
   vor dem Merge ueber `/review-pr <PR-Nummer>` laeuft.

## Regeln

- Niemals direkt auf den Ziel-Branch committen oder pushen.
- Kein `git push --force`, kein `git reset --hard` auf fremde Commits, keine
  Branches oder Issues loeschen.
- Keine Zugangsdaten in Commits; `.env`-Dateien werden weder veraendert noch
  eingecheckt.
- Bleibt ein Schritt unklar, frage nach, statt eine Annahme zu implementieren.
- Antworte auf Deutsch.

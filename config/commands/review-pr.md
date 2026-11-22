---
description: Einen Pull Request vor dem Merge gegen Umsetzungsplan und Akzeptanzkriterien pruefen und das Ergebnis als GitHub-Review mit Inline-Kommentaren einstellen
---

Du pruefst einen Pull Request, bevor er gemergt wird. Massstab sind die
Akzeptanzkriterien des verknuepften Issues, dessen Umsetzungsplan und die
Gepflogenheiten des Projekts. Du **aenderst keinen Code** im Pull Request und
**mergst nicht**.

## Pull Request

$ARGUMENTS

PR-Nummer oder PR-URL. Fehlt die Angabe, frage danach, bevor du beginnst.

## Schritt 0: Kontext ermitteln

Fuehre das zuerst aus und verwende die Ausgabe in allen weiteren Schritten:

```sh
echo "Verzeichnis: $(pwd)"
R="$(gh repo view "$(git remote get-url origin 2>/dev/null)" --json nameWithOwner -q .nameWithOwner 2>/dev/null)"
echo "Ziel-Repo:   ${R:-nicht ermittelbar (kein Git-Repository oder kein origin)}"
[ -n "$R" ] && gh repo view "$R" --json isFork,parent \
  -q 'if .isFork then "Fork:        ja, von \(.parent.owner.login)/\(.parent.name)" else "Fork:        nein" end'
echo "Ich bin:     $(gh api user --jq .login 2>/dev/null || echo '?')"
git status -sb | head -5
```

Den Wert `Ziel-Repo` (`<owner>/<repo>`) gibst du bei **jedem** `gh`-Aufruf mit
`--repo` an bzw. setzt ihn in `repos/<Ziel-Repo>/...` ein.

## Vorgehen

1. **Pull Request lesen.**

   ```sh
   gh pr view <pr> --repo <Ziel-Repo> --json number,title,body,author,baseRefName,headRefName,headRefOid,isDraft,mergeable,commits,files,closingIssuesReferences,url
   gh pr diff <pr> --repo <Ziel-Repo>
   gh pr checks <pr> --repo <Ziel-Repo>
   ```

   Meldet `gh pr checks` "no checks reported" (mit Exit-Code ungleich 0), ist
   im Repository keine CI eingerichtet. Das ist kein Befund; halte es unter
   *Lokale Pruefung* fest.

   Ist der PR ein Entwurf (`isDraft`), weise darauf hin und frage, ob trotzdem
   geprueft werden soll.

2. **Massstab holen.** Aus `closingIssuesReferences` oder `Closes #<nr>` im
   PR-Text das Issue bestimmen. Dann:
   - Issue-Text, insbesondere `### Akzeptanzkriterien`
   - den Kommentar, dessen erste Zeile `## Umsetzungsplan` lautet, samt
     *Definition of Done* und *Aenderungshistorie*
   - fruehere Reviews mit erster Zeile `## Review` - bereits genannte Befunde
     pruefst du gezielt nach, statt sie neu zu erfinden
   - nicht aufgeloeste Review-Threads samt Antworten:

     ```sh
     gh api graphql -F o=<owner> -F r=<repo> -F n=<pr> -f query='
       query($o:String!,$r:String!,$n:Int!){repository(owner:$o,name:$r){
         pullRequest(number:$n){reviewThreads(first:100){nodes{
           isResolved path line
           comments(first:30){nodes{author{login} body url createdAt}}}}}}}' \
       --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved | not)'
     ```

     Beginnt der letzte Kommentar eines Threads mit `**Umgesetzt**`,
     `**Widersprochen**` oder `**Zurueckgestellt**`, ist er beantwortet
     (so antwortet `/address-review`). Bewerte die Antwort:
     - **tragfaehig** - Befund behoben bzw. Begruendung ueberzeugt: sage das im
       Review ausdruecklich und empfiehl dem Nutzer, den Thread aufzuloesen.
     - **nicht tragfaehig** - der Befund bleibt bestehen; beim Einstellen des
       Reviews (Schritt 7) antwortest du im Thread mit einer Zeile, die mit
       `**Bleibt offen**` beginnt, und der Begruendung. Erst damit gilt der
       Thread fuer `/item-status` und `/address-review` wieder als offen.

   Gibt es kein verknuepftes Issue oder keinen Plan, pruefe trotzdem und halte
   im Review fest, dass der Massstab fehlt.

3. **Lokal pruefen - ohne den Arbeitsstand anzufassen.** In einem eigenen
   Worktree:

   ```sh
   git fetch origin "pull/<pr>/head"
   git worktree add --detach "/tmp/review-pr-<pr>" FETCH_HEAD
   ```

   Dort Abhaengigkeiten installieren und Tests, Linter und Build ausfuehren, so
   wie es das Projekt vorsieht (README, Makefile, package.json, go.mod, CI-
   Konfiguration unter `.github/workflows/`). Am Ende aufraeumen:
   `git worktree remove --force "/tmp/review-pr-<pr>"`.

4. **Pruefen.** Arbeite diese Punkte ab:
   - **Abdeckung:** Jedes Akzeptanzkriterium und jeder Plan-Schritt ist
     *erfuellt*, *teilweise* oder *fehlt* - mit Fundstelle.
   - **Abweichungen vom Plan:** sind sie im PR-Text begruendet und sinnvoll?
   - **Korrektheit:** Logikfehler, Randfaelle, Fehlerbehandlung, Nebenlaeufigkeit.
   - **Tests:** gibt es neue oder angepasste Tests fuer das geaenderte Verhalten,
     pruefen sie das Richtige, laufen sie gruen?
   - **Sicherheit:** Zugangsdaten oder `.env` im Diff, ungepruefte Eingaben,
     Injection, zu weite Rechte.
   - **Projektgepflogenheiten:** Stil, Struktur, Benennung wie im restlichen Code;
     keine fachfremden Aenderungen im Diff.
   - **Zustand:** CI-Checks, Merge-Konflikte, Abstand zum Ziel-Branch.

5. **Befunde einstufen.** Jeder Befund bekommt genau eine Stufe:
   - **Blocker** - falsch, unsicher, Akzeptanzkriterium fehlt, Tests rot
   - **Sollte** - deutlich besser, aber kein Merge-Hindernis
   - **Hinweis** - Geschmack, Kleinigkeit, Idee fuer spaeter

   Zu jedem Befund: Datei und Zeile im neuen Stand, was das Problem ist,
   warum, und ein konkreter Vorschlag. Melde nur, was du belegen kannst -
   lieber wenige sichere Befunde als viele vage.

   **Empfehlung** - genau eine von drei:
   - *nachbessern*, wenn es mindestens einen Blocker gibt
   - *mergebar nach manueller Pruefung*, wenn es keinen Blocker gibt, aber
     Pruefungen offen sind, die nur ein Mensch machen kann (anderes
     Betriebssystem, echte Infrastruktur, Geraete, Zugangsdaten) - etwa ein
     DoD-Punkt, der sich in der Sandbox nicht pruefen laesst
   - *mergebar* sonst

6. **Entwurf zeigen und Freigabe einholen.** Zeige den Review-Text und die
   Inline-Kommentare. Poste erst, wenn der Nutzer zustimmt.

   Der Review-Text beginnt mit genau dieser ersten Zeile, daran finden
   `/address-review` und `/item-status` ihn wieder:

   ```
   ## Review
   **Empfehlung: mergebar | mergebar nach manueller Pruefung | nachbessern** - geprueft auf Stand <kurzer SHA>

   ### Abdeckung
   | Kriterium / Plan-Schritt | Stand | Fundstelle |
   |---|---|---|

   ### Befunde
   - **Blocker** `pfad/datei.ext:42` - ...
   - **Sollte** ...
   - **Hinweis** ...

   ### Lokale Pruefung
   Tests / Linter / Build: Befehl und Ergebnis

   ### Manuelle Pruefung
   (nur bei *mergebar nach manueller Pruefung*) je Pruefung: Befehl,
   Umgebung, erwartetes Ergebnis

   ### Offene Threads
   (nur wenn vorhanden) je Thread: beantwortet ja/nein, Bewertung der Antwort,
   Empfehlung "aufloesen" oder "bleibt offen"
   ```

7. **Review einstellen.** Als ein einziges Review mit Inline-Kommentaren. Die
   JSON-Datei erzeugst du mit `jq` oder Python, damit Zeilenumbrueche und
   Anfuehrungszeichen sauber maskiert sind:

   ```json
   {
     "commit_id": "<headRefOid>",
     "event": "COMMENT",
     "body": "## Review\n...",
     "comments": [
       { "path": "pfad/datei.ext", "line": 42, "side": "RIGHT", "body": "**Blocker** - ..." }
     ]
   }
   ```

   ```sh
   gh api -X POST "repos/<Ziel-Repo>/pulls/<pr>/reviews" --input <datei>.json
   ```

   `event` ist **immer** `COMMENT`. Laeuft alles ueber dasselbe Token, ist der
   Autor des PRs meist der Nutzer selbst, und GitHub erlaubt bei eigenen PRs
   weder `APPROVE` noch `REQUEST_CHANGES`. Die Empfehlung steht deshalb im Text.

   Inline-Kommentare sind nur auf Zeilen moeglich, die im Diff vorkommen.
   Lehnt GitHub einen Kommentar ab (HTTP 422), nimm ihn aus `comments` heraus;
   er steht ohnehin unter *Befunde* im Review-Text.

   Antworten `**Bleibt offen**` aus Schritt 2 gehen danach einzeln an den
   jeweiligen Thread (erste Kommentar-ID des Threads):

   ```sh
   gh api -X POST "repos/<Ziel-Repo>/pulls/<pr>/comments/<id>/replies" -f body="**Bleibt offen** - ..."
   ```

8. **Zusammenfassung.** Empfehlung, Anzahl Befunde je Stufe, Review-URL.
   Naechster Schritt: bei *nachbessern* `/address-review <pr>`; bei
   *mergebar nach manueller Pruefung* die genannten Pruefungen, dann der Merge
   durch den Nutzer; bei *mergebar* der Merge durch den Nutzer. Zum Aufloesen
   empfohlene Threads nennst du mit Link.

## Regeln

- Kein Merge, kein Push, keine Commits, keine Aenderungen am PR-Branch.
- Keine Review-Threads aufloesen, keine Kommentare anderer aendern oder loeschen.
- Kein `APPROVE` und kein `REQUEST_CHANGES` - immer `COMMENT`.
- Den eigenen Arbeitsstand nicht veraendern: kein Checkout im Hauptverzeichnis,
  gepruefte Staende nur im Worktree unter `/tmp`.
- Keine Zugangsdaten oder Inhalte aus `.env`-Dateien in Kommentare uebernehmen.
- Antworte auf Deutsch.

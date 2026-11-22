---
description: Befunde aus einem Pull-Request-Review und rote CI-Checks abarbeiten, als Fix-Commits pushen und jeden Review-Thread beantworten
---

Du arbeitest die offenen Punkte eines Pull Requests ab: Befunde aus dem
letzten `## Review`, offene Review-Threads und fehlgeschlagene CI-Checks. Das
Ergebnis sind zusaetzliche Commits auf dem PR-Branch und eine Antwort in jedem
bearbeiteten Thread. Du **mergst nicht**.

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
echo "Ziel-Branch: ${GIT_DEFAULT_BRANCH:-main}"
git status -sb | head -20
```

Den Wert `Ziel-Repo` (`<owner>/<repo>`) gibst du bei **jedem** `gh`-Aufruf mit
`--repo` an bzw. setzt ihn in `repos/<Ziel-Repo>/...` ein.

## Vorgehen

1. **Offene Punkte sammeln.**

   - **PR und letztes Review:**

     ```sh
     gh pr view <pr> --repo <Ziel-Repo> --json number,title,body,headRefName,headRefOid,closingIssuesReferences,reviews,url
     ```

     Massgeblich ist das juengste Review, dessen Text mit `## Review` beginnt,
     dazu alle Reviews anderer Personen.

   - **Offene Review-Threads:**

     ```sh
     gh api graphql -F o=<owner> -F r=<repo> -F n=<pr> -f query='
       query($o:String!,$r:String!,$n:Int!){repository(owner:$o,name:$r){
         pullRequest(number:$n){reviewThreads(first:100){nodes{
           isResolved isOutdated path line
           comments(first:30){nodes{databaseId author{login} body url createdAt}}}}}}}' \
       --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved | not)'
     ```

     Die `databaseId` des **ersten** Kommentars eines Threads brauchst du
     spaeter fuer die Antwort.

   - **Rote Checks:**

     ```sh
     gh pr checks <pr> --repo <Ziel-Repo>
     gh run list --repo <Ziel-Repo> --branch <headRefName> --limit 5
     gh run view <run-id> --repo <Ziel-Repo> --log-failed
     ```

   Gibt es nichts Offenes, melde das und verweise auf `/review-pr <pr>` fuer
   eine erneute Pruefung.

2. **Einordnen und Freigabe einholen.** Zeige eine Liste aller Punkte mit
   Quelle (Review, Thread, CI), Stufe (*Blocker* / *Sollte* / *Hinweis*) und
   deinem Vorschlag:
   - **umsetzen** - mit einem Satz, wie
   - **widersprechen** - mit Begruendung, z. B. weil der Befund auf einem
     Missverstaendnis beruht oder dem Plan widerspricht
   - **zurueckstellen** - Hinweis fuer ein spaeteres Issue

   Blocker werden umgesetzt oder begruendet widersprochen, nie stillschweigend
   uebergangen. Erst nach Zustimmung des Nutzers weiter.

3. **Arbeitsstand pruefen.** Sind uncommittete Aenderungen vorhanden, frage,
   wie damit verfahren werden soll. Dann den PR-Branch holen:

   ```sh
   gh pr checkout <pr> --repo <Ziel-Repo>
   git pull --ff-only
   ```

4. **Umsetzen.** Punkt fuer Punkt, im Stil des vorhandenen Codes. Bei roten
   Checks zuerst die Ursache aus dem Log bestimmen und lokal nachstellen, dann
   beheben - nicht den Test abschwaechen, damit er gruen wird.

5. **Pruefen.** Tests, Linter und Build so, wie es das Projekt vorsieht. Erst
   weiter, wenn alles gruen ist.

6. **Committen.** Ein Commit je Befund oder je eng zusammengehoeriger Gruppe;
   Betreff im Imperativ, Koerper mit dem Warum und dem Bezug auf den Befund.
   Jeder Commit verweist mit `Refs #<issue>` auf das Issue.

7. **Pushen.** Normaler Push auf den PR-Branch, kein Force-Push:
   `git push`.

8. **Threads beantworten.** Zu jedem bearbeiteten Thread eine Antwort - mit
   Commit-Link bei *umgesetzt*, mit Begruendung bei *widersprochen* oder
   *zurueckgestellt*:

   ```sh
   gh api -X POST "repos/<Ziel-Repo>/pulls/<pr>/comments/<databaseId>/replies" -f body="..."
   ```

   Befunde aus dem `## Review`-Text ohne eigenen Thread beantwortest du
   gesammelt in **einem** PR-Kommentar mit derselben Gliederung.

   Threads loest du **nicht** selbst auf - das bleibt beim Reviewer.

9. **PR-Text ergaenzen.** Entstehen dabei bewusste Abweichungen vom Plan,
   ergaenze sie im PR-Text unter den Abweichungen
   (`gh pr edit <pr> --repo <Ziel-Repo> --body-file <datei>`). Den Rest des
   Textes, insbesondere `Closes #<nr>`, laesst du unveraendert.

10. **Zusammenfassung.** Umgesetzte, widersprochene und zurueckgestellte Punkte,
    neue Commits, Testergebnis, Stand der Checks. Naechster Schritt:
    `/review-pr <pr>` fuer eine erneute Pruefung.

## Regeln

- Niemals direkt auf den Ziel-Branch committen oder pushen.
- Kein `git push --force`, kein `git reset --hard` auf fremde Commits, keine
  Branches oder Issues loeschen, keine Kommentare anderer aendern.
- Keine Review-Threads aufloesen und nicht mergen.
- Tests nicht abschwaechen, ueberspringen oder loeschen, um Checks gruen zu
  bekommen.
- Keine Zugangsdaten in Commits; `.env`-Dateien werden weder veraendert noch
  eingecheckt.
- Bleibt ein Befund unklar, frage nach, statt eine Annahme zu implementieren.
- Antworte auf Deutsch.

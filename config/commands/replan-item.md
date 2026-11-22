---
description: Den Umsetzungsplan eines GitHub-Issues ueberarbeiten, wenn nach der Planung neue Kommentare oder Aenderungen am Issue hinzugekommen sind
---

Du ueberarbeitest einen bestehenden Umsetzungsplan. Grundlage ist alles, was
seit dem letzten Stand des Plans im Issue hinzugekommen ist. In diesem
Durchgang wird **nichts implementiert**, kein Branch angelegt und nichts
committet.

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

Den Wert `Ziel-Repo` (`<owner>/<repo>`) gibst du bei **jedem** `gh`-Aufruf mit `--repo` an bzw.
setzt ihn in `repos/<Ziel-Repo>/...` ein.

## Vorgehen

1. **Plan und Kommentare holen.** Alle Kommentare mit Zeitstempeln:

   ```sh
   gh api "repos/<Ziel-Repo>/issues/<nr>/comments" --paginate \
     --jq '.[] | {id, user: .user.login, created_at, updated_at, url: .html_url, first_line: (.body | split("\n")[0])}'
   ```

   Der Plan ist der Kommentar, dessen erste Zeile genau `## Umsetzungsplan`
   lautet. Gibt es keinen, brich ab und verweise auf `/plan-item <nummer>`.
   Den vollstaendigen Plantext liest du mit
   `gh api "repos/<Ziel-Repo>/issues/comments/<id>" --jq .body`.

   Stichtag ist das `updated_at` des Plan-Kommentars.

2. **Neues ermitteln.**
   - **Kommentare** mit `created_at` nach dem Stichtag. Nicht mitgezaehlt
     werden Kommentare, deren erste Zeile mit `## Umsetzungsplan`,
     `### Umsetzungsplan aktualisiert` oder `## Review` beginnt.
   - **Geaenderte Kommentare** mit `created_at` vor, aber `updated_at` nach dem
     Stichtag - inhaltlich pruefen, ob sich etwas Relevantes geaendert hat.
   - **Geaenderte Issue-Beschreibung:**

     ```sh
     gh api graphql -F o=<owner> -F r=<repo> -F n=<nr> -f query='
       query($o:String!,$r:String!,$n:Int!){repository(owner:$o,name:$r){
         issue(number:$n){title body lastEditedAt labels(first:20){nodes{name}}}}}' \
       --jq .data.repository.issue
     ```

     Liegt `lastEditedAt` nach dem Stichtag, vergleiche Beschreibung und Plan.

   Ist nichts davon vorhanden, melde "Plan ist aktuell", nenne den Stichtag und
   beende den Durchgang **ohne** etwas zu schreiben.

3. **Fortschritt pruefen.** Gibt es schon Arbeit an dem Issue?

   ```sh
   git ls-remote --heads origin "feature/<nr>-*"
   gh issue view <nr> --repo <Ziel-Repo> --json closedByPullRequestsReferences \
     --jq '.closedByPullRequestsReferences[] | {number, url}'
   gh pr list --repo <Ziel-Repo> --state all --limit 200 --json number,state,headRefName,url \
     --jq '.[] | select(.headRefName | startswith("feature/<nr>-"))'
   ```

   Existiert ein Branch oder PR, sieh dir dessen Commits an und stelle fest,
   welche Plan-Schritte bereits erledigt sind.

4. **Neues einordnen.** Ordne jeden neuen oder geaenderten Beitrag genau einer
   Kategorie zu:
   - *Anforderungsaenderung* - Ziel, Umfang oder Akzeptanzkriterien aendern sich
   - *Antwort auf offenen Punkt* - loest einen Eintrag unter *Offene Punkte*
   - *Neue Frage* - wird zum neuen offenen Punkt
   - *Ohne Auswirkung* - Dank, Statusmeldung, Diskussion ohne Ergebnis

   Widersprechen sich Beitraege, oder ist unklar, ob etwas eine verbindliche
   Anforderung ist, stelle **hoechstens drei** gezielte Fragen und warte.

5. **Plan ueberarbeiten.** Gleicher Aufbau wie bei `/plan-item`:
   *Ziel*, *Betroffene Dateien*, *Schritte*, *Tests*, *Offene Punkte*,
   *Definition of Done* - und am Ende neu oder fortgeschrieben:

   ```
   ### Aenderungshistorie
   - **v2** (JJJJ-MM-TT): <was sich geaendert hat> - ausgeloest durch <Kommentar-Link>, <Kommentar-Link>
   - **v1** (JJJJ-MM-TT): erster Plan
   ```

   Die Version zaehlst du aus der vorhandenen Historie hoch; fehlt sie, ist der
   bisherige Stand v1. Beantwortete offene Punkte wandern als Entscheidung in
   die passenden Schritte und verschwinden aus *Offene Punkte*.

   Gibt es bereits Branch oder PR: erledigte Schritte behalten ihre Nummer und
   bekommen den Zusatz `(erledigt)`. Neue Arbeit kommt als zusaetzliche
   Schritte ans Ende, statt bestehende umzuschreiben.

6. **Freigabe einholen.** Zeige zuerst eine kurze Aenderungsuebersicht
   (welcher Beitrag -> welche Aenderung am Plan), dann den neuen Plantext.
   Schreibe erst, wenn der Nutzer zustimmt.

7. **Plan aktualisieren.** Den **bestehenden** Kommentar bearbeiten, keinen
   zweiten anlegen. Die erste Zeile bleibt genau `## Umsetzungsplan` - daran
   findet `/implement-item` den Plan wieder.

   ```sh
   gh api -X PATCH "repos/<Ziel-Repo>/issues/comments/<id>" -F body=@<datei>
   ```

8. **Beteiligte benachrichtigen.** Das Bearbeiten eines Kommentars loest keine
   Benachrichtigung aus. Lege deshalb einen kurzen Kommentar an:

   ```
   ### Umsetzungsplan aktualisiert
   Version vN. Aenderungen: <ein bis drei Stichpunkte>. Plan: <Link zum Plan-Kommentar>
   ```

9. **Zusammenfassung.** Fuenf bis zehn Zeilen: neue Version, was sich geaendert
   hat, verbleibende offene Punkte. Schliesse mit dem passenden naechsten
   Schritt: `/implement-item <nummer>` - oder, wenn schon ein PR existiert,
   dort weiterarbeiten und danach `/review-pr <PR>`.

## Regeln

- Keine Codeaenderungen, keine Commits, keine Branches, keine Pull Requests.
- Nur den Plan-Kommentar bearbeiten - niemals Kommentare anderer Personen
  aendern oder loeschen.
- Was du nicht sicher weisst, gehoert unter *Offene Punkte* - nicht in die
  Schritte.
- Schreibe den Plan so, dass ihn jemand ohne diesen Chatverlauf abarbeiten kann.
- Antworte auf Deutsch.

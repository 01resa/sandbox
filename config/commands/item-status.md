---
description: Zeigen, in welcher Phase offene GitHub-Issues und ihre Pull Requests stehen und welcher Befehl als naechstes dran ist - nur lesend
---

Du ermittelst, wo ein Issue oder alle offenen Issues im Ablauf stehen, und
nennst zu jedem den naechsten Befehl. Dieser Befehl **schreibt nichts** - weder
auf GitHub noch im Repository.

## Auswahl

$ARGUMENTS

Eine Issue-Nummer fuer die Detailansicht. Leer: Uebersicht ueber alle offenen
Issues (die 30 zuletzt aktualisierten).

## Schritt 0: Kontext ermitteln

Fuehre das zuerst aus und verwende die Ausgabe in allen weiteren Schritten:

```sh
echo "Verzeichnis: $(pwd)"
R="$(gh repo view "$(git remote get-url origin 2>/dev/null)" --json nameWithOwner -q .nameWithOwner 2>/dev/null)"
echo "Ziel-Repo:   ${R:-nicht ermittelbar (kein Git-Repository oder kein origin)}"
[ -n "$R" ] && gh repo view "$R" --json isFork,parent,hasIssuesEnabled \
  -q '(if .isFork then "Fork:        ja, von \(.parent.owner.login)/\(.parent.name)" else "Fork:        nein" end), "Issues:      \(if .hasIssuesEnabled then "aktiv" else "ABGESCHALTET" end)"'
```

Sind Issues abgeschaltet, sage das und beende den Durchgang.

## Vorgehen

1. **Daten holen.** Eine Abfrage liefert alle Marker und Zeitstempel. Fuer die
   Uebersicht so ausfuehren; fuer ein einzelnes Issue danach mit
   `select(.issue == <nr>)` filtern:

   ```sh
   R="$(gh repo view "$(git remote get-url origin)" --json nameWithOwner -q .nameWithOwner)"
   gh api graphql -F o="${R%/*}" -F r="${R#*/}" -f query='
     query($o:String!,$r:String!){repository(owner:$o,name:$r){
       issues(states:OPEN,first:30,orderBy:{field:UPDATED_AT,direction:DESC}){nodes{
         number title lastEditedAt
         comments(last:50){nodes{createdAt lastEditedAt body}}
         closedByPullRequestsReferences(first:5,includeClosedPrs:false){nodes{
           number isDraft mergeable headRefName author{login}
           commits(last:1){nodes{commit{committedDate statusCheckRollup{state}}}}
           reviews(last:20){nodes{createdAt body}}
           reviewThreads(first:100){nodes{isResolved comments(last:1){nodes{author{login} createdAt}}}}}}}}}}' \
     --jq '.data.repository.issues.nodes[] | {
       issue: .number, title, body_edited: .lastEditedAt,
       plan: ([.comments.nodes[] | select(.body | startswith("## Umsetzungsplan")) | (.lastEditedAt // .createdAt)] | last),
       plan_body: ([.comments.nodes[] | select(.body | startswith("## Umsetzungsplan")) | .body] | last),
       last_comment: ([.comments.nodes[] | select(.body | test("^(## Umsetzungsplan|### Umsetzungsplan aktualisiert|## Review)") | not) | .createdAt] | last),
       prs: [.closedByPullRequestsReferences.nodes[] | .author.login as $a
         | ([.reviews.nodes[] | select(.body | startswith("## Review"))] | last) as $rv
         | [.reviewThreads.nodes[] | select(.isResolved | not)
            | {answered: (($rv != null) and (.comments.nodes[0].author.login == $a) and (.comments.nodes[0].createdAt > $rv.createdAt))}] as $th
         | {
         pr: .number, draft: .isDraft, mergeable, branch: .headRefName,
         ci: (.commits.nodes[0].commit.statusCheckRollup.state // "KEINE"),
         last_commit: .commits.nodes[0].commit.committedDate,
         review: (if $rv then {at: $rv.createdAt, verdict: ($rv.body | capture("Empfehlung: (?<v>mergebar nach manueller Pruefung|mergebar|nachbessern)").v? // "?")} else null end),
         open_threads: ([$th[] | select(.answered | not)] | length),
         answered_threads: ([$th[] | select(.answered)] | length)}]}'
   ```

   Pull Requests werden ueber `Closes #<nr>` mit dem Issue verknuepft. Findet
   die Abfrage keinen, pruefe zusaetzlich offene PRs mit dem Branch
   `feature/<nr>-*`:
   `gh pr list --repo <Ziel-Repo> --state open --json number,headRefName --jq '.[] | select(.headRefName | startswith("feature/<nr>-"))'`

   Felder, die die Phase bestimmen:
   - `ci`: `KEINE` heisst, im Repository ist keine CI eingerichtet - das ist
     kein Fehler.
   - `open_threads`: nicht aufgeloeste Threads, die **noch nicht beantwortet**
     sind.
   - `answered_threads`: nicht aufgeloeste Threads, deren letzter Kommentar vom
     PR-Autor stammt und nach dem letzten `## Review` liegt - typischerweise
     von `/address-review` beantwortet. Sie blockieren nicht; aufloesen muss sie
     der Reviewer.

2. **Phase bestimmen.** Pruefe die Regeln **von oben nach unten**; die erste,
   die zutrifft, gilt:

   | Phase | Bedingung | Naechster Befehl |
   |---|---|---|
   | *Mergebar* | PR vorhanden, letztes `## Review` sagt *mergebar*, Review juenger als `last_commit`, CI `SUCCESS` oder `KEINE`, `open_threads` 0, `mergeable` nicht `CONFLICTING` | Merge durch den Nutzer |
   | *Manuelle Pruefung* | wie *Mergebar*, aber das Review sagt *mergebar nach manueller Pruefung* | die Pruefungen aus `### Manuelle Pruefung` im Review von Hand durchfuehren, dann Merge |
   | *Konflikt* | PR vorhanden, `mergeable` ist `CONFLICTING` | Ziel-Branch in den PR-Branch holen, dann `/review-pr <pr>` |
   | *Nachbessern* | PR vorhanden und: CI `FAILURE`/`ERROR`, oder `open_threads` > 0, oder das letzte Review sagt *nachbessern* **und** ist juenger als `last_commit` | `/address-review <pr>` |
   | *Review veraltet* | PR vorhanden, Review aelter als `last_commit` | `/review-pr <pr>` |
   | *Review offen* | PR vorhanden, kein `## Review` | `/review-pr <pr>` (bei Entwurf: erst fertigstellen) |
   | *Plan veraltet* | Plan vorhanden und `last_comment` oder `body_edited` nach `plan` | `/replan-item <nr>` |
   | *Wartet auf Antwort* | Plan vorhanden, unter *Offene Punkte* steht mindestens ein Punkt **ohne** *Vorschlag* | Antworten im Issue abwarten, dann `/replan-item <nr>` |
   | *Geplant* | Plan vorhanden, sonst nichts | `/implement-item <nr>` |
   | *Ungeplant* | kein Plan | `/plan-item <nr>` |

   CI `PENDING` vermerkst du als "Checks laufen" und nimmst die Phase, die
   ohne CI-Bedingung zutrifft.

   Ein Review mit *nachbessern*, nach dem schon wieder committet wurde, gilt
   als *Review veraltet* - die Nachbesserung ist dann erfolgt und muss geprueft
   werden, nicht erneut gemacht.

   Offene Punkte, die einen *Vorschlag* enthalten, blockieren nicht:
   `/implement-item` uebernimmt den Vorschlag. Nenne sie in der Detailansicht
   trotzdem, damit der Nutzer vorher widersprechen kann.

3. **Ausgeben.**
   - **Uebersicht:** eine Tabelle mit den Spalten Issue, Titel (gekuerzt),
     Phase, PR, CI, naechster Befehl - sortiert nach Phase, die Phasen, die
     am naechsten an einem Merge stehen, zuerst. Darunter eine Zeile je Phase
     mit der Anzahl.
   - **Detailansicht:** Phase, alle Zeitstempel (Plan, letzter Kommentar,
     letzter Commit, letztes Review), Plan-Version aus der
     *Aenderungshistorie*, offene Punkte des Plans, CI-Status, offene und
     beantwortete Threads (beantwortete mit dem Hinweis, dass der Reviewer sie
     aufloesen sollte)
     und der naechste Befehl mit kurzer Begruendung.

## Regeln

- Ausschliesslich lesen: keine Kommentare, Labels, Reviews, Commits, Branches
  oder sonstige Aenderungen.
- Nur das berichten, was die Daten hergeben. Ist eine Phase nicht eindeutig,
  nenne beide Moeglichkeiten und den Grund.
- Antworte auf Deutsch.

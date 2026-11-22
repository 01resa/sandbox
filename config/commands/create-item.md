---
description: Aus einer Idee oder Fehlerbeschreibung ein sauber strukturiertes GitHub-Issue mit pruefbaren Akzeptanzkriterien anlegen
---

Du legst aus einer Idee ein neues GitHub-Issue an. Es soll so klar sein, dass
`/plan-item` daraus ohne Rueckfragen einen Umsetzungsplan machen kann. In
diesem Durchgang wird **kein Code geaendert**, kein Branch angelegt und nichts
committet.

## Idee

$ARGUMENTS

Freie Beschreibung, gern auch stichpunktartig. Fehlt sie, frage danach, bevor
du beginnst.

## Schritt 0: Kontext ermitteln

Fuehre das zuerst aus und verwende die Ausgabe in allen weiteren Schritten:

```sh
echo "Verzeichnis: $(pwd)"
R="$(gh repo view "$(git remote get-url origin 2>/dev/null)" --json nameWithOwner -q .nameWithOwner 2>/dev/null)"
echo "Ziel-Repo:   ${R:-nicht ermittelbar (kein Git-Repository oder kein origin)}"
[ -n "$R" ] && gh repo view "$R" --json isFork,parent \
  -q 'if .isFork then "Fork:        ja, von \(.parent.owner.login)/\(.parent.name)" else "Fork:        nein" end'
ls .github/ISSUE_TEMPLATE/ 2>/dev/null || echo "Issue-Vorlagen: keine"
[ -n "$R" ] && gh label list --repo "$R" --limit 100
```

Den Wert `Ziel-Repo` gibst du bei **jedem** `gh`-Aufruf mit `--repo` an. In
einem Fork zielt `gh` sonst auf das Original. Ist das Repo ein Fork, frage
einmal nach, ob das Issue in den Fork oder ins Original gehoert; voreingestellt
ist der Fork.

## Vorgehen

1. **Art bestimmen.** Bug, Feature oder Wartung (Chore, Refactoring, Doku,
   Abhaengigkeiten). Ist das nicht eindeutig, oder fehlen fuer ein brauchbares
   Issue wesentliche Angaben, stelle **hoechstens drei** gezielte Fragen und
   warte auf Antwort.

2. **Duplikate suchen.** Suche mit zwei, drei treffenden Begriffen in offenen
   und geschlossenen Issues:
   `gh issue list --repo <Ziel-Repo> --state all --search "<begriffe>" --limit 10`.
   Gibt es aehnliche Issues, nenne sie mit Nummer, Titel und Zustand und frage,
   ob trotzdem ein neues angelegt werden soll - oder ob die Information besser
   als Kommentar an das vorhandene Issue geht.

3. **Kurz in den Code sehen.** Nur so weit, dass betroffene Bereiche, Dateien
   oder Komponenten richtig benannt werden koennen. Keine Loesung entwerfen -
   das ist Aufgabe von `/plan-item`.

4. **Entwurf schreiben.** Gibt es unter `.github/ISSUE_TEMPLATE/` eine passende
   Vorlage, folge deren Aufbau. Sonst:

   - **Titel** - kurz und konkret, beschreibt das Ergebnis, nicht die Taetigkeit
     (gut: "CSV-Export fuer Rechnungsliste", schlecht: "Export bauen").
   - `### Problem / Kontext` - was fehlt oder stoert, fuer wen, warum es wichtig ist.
   - `### Ziel` - ein bis drei Saetze: wie es nach der Umsetzung aussieht.
   - `### Akzeptanzkriterien` - Checkliste `- [ ] ...`. Jedes Kriterium ist
     einzeln pruefbar, beobachtbar und ohne Interpretationsspielraum.
   - `### Nicht Teil dieses Issues` - bewusste Abgrenzung.
   - `### Hinweise` - betroffene Bereiche, Links, verwandte Issues.

   Bei einem **Bug** zusaetzlich, vor den Akzeptanzkriterien:

   - `### Reproduktion` - nummerierte Schritte.
   - `### Erwartet` und `### Tatsaechlich`
   - `### Umgebung` - Version, Betriebssystem, Konfiguration, soweit bekannt.

   Fuer einen Bug gilt als Akzeptanzkriterium immer auch: ein Test, der den
   Fehler nachstellt, schlaegt vor der Korrektur fehl und danach nicht mehr.

5. **Labels waehlen.** Nur Labels, die in Schritt 0 aufgelistet wurden. Lege
   keine neuen an. Passt keins, setze keins.

6. **Freigabe einholen.** Zeige Titel, Labels und den vollstaendigen Text. Lege
   das Issue erst an, wenn der Nutzer zustimmt; Aenderungswuensche arbeitest du
   ein und zeigst den Entwurf erneut.

7. **Anlegen.** Den Text in eine temporaere Datei schreiben, dann:
   `gh issue create --repo <Ziel-Repo> --title "<titel>" --body-file <datei> [--label <l1> --label <l2>]`

8. **Zusammenfassung.** Issue-Nummer und URL, gesetzte Labels, offene Fragen.
   Schliesse mit dem Hinweis, dass die Planung ueber `/plan-item <nummer>` laeuft.

## Regeln

- Keine Codeaenderungen, keine Commits, keine Branches, keine Pull Requests.
- Keine neuen Labels, Meilensteine oder Projekte anlegen.
- Nichts erfinden: Was der Nutzer nicht gesagt hat und sich nicht nachlesen
  laesst, kommt als offene Frage unter `### Hinweise`, nicht als Anforderung
  in die Akzeptanzkriterien.
- Keine Zugangsdaten, Tokens oder Inhalte aus `.env`-Dateien in das Issue.
- Antworte auf Deutsch.

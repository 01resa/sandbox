# Entwicklungs-Sandbox mit opencode

Ein abgeschotteter Docker-Container zum Programmieren. Innen laufen zwei
Coding-Agenten nebeneinander: [opencode](https://opencode.ai) und
[Claude Code](https://code.claude.com). Der Quellcode liegt weiterhin auf dem
Mac, nur die Werkzeugkette und die Agenten laufen im Container.

## Struktur

```
sandbox/
├── sandbox.sh              Start- und Steuerskript (macOS, Linux)
├── sandbox.ps1             dasselbe fuer Windows (PowerShell)
├── sandbox.bat             Starthilfe fuer die Eingabeaufforderung
├── compose.yaml            Dienstdefinition, Mounts, Volumes, Grenzen
├── .env                    persoenliche Einstellungen (nicht ins Git)
├── .env.example            Vorlage mit allen Schaltern
├── docker/
│   ├── Dockerfile          Image: Debian + Go/Node/Python + opencode
│   ├── entrypoint.sh       Startlogik (Git-Identitaet, Verzeichnisse)
│   └── bashrc.d/sandbox.sh Begruessung und Prompt im Container
├── .gitattributes          haelt LF-Zeilenenden fuer den Container
├── config/
│   ├── commands/           die geteilten Befehle - eine Quelle fuer beide
│   │   ├── create-item.md      Issue sauber anlegen
│   │   ├── plan-item.md        Umsetzungsplan als Issue-Kommentar
│   │   ├── replan-item.md      Plan nach neuen Kommentaren ueberarbeiten
│   │   ├── implement-item.md   Plan umsetzen, Pull Request anlegen
│   │   ├── review-pr.md        Pull Request vor dem Merge pruefen
│   │   ├── address-review.md   Review-Befunde und rote Checks abarbeiten
│   │   └── item-status.md      Phase und naechster Schritt (nur lesend)
│   ├── skills/             duenne SKILL.md-Huellen auf dieselben Texte
│   ├── opencode/opencode.json   Konfiguration inkl. GitHub-MCP-Server
│   └── claude/settings.json Vorlage fuer Claude Code
└── workspace/              Projekte -> im Container unter /work
```

## Erste Schritte

1. Docker Desktop starten.
2. In `.env` den `ANTHROPIC_API_KEY` eintragen (oder leer lassen, siehe unten).
3. Sandbox starten:

macOS und Linux:

```bash
cd ~/Desktop/sandbox
./sandbox.sh
```

Windows (PowerShell):

```powershell
cd $HOME\Desktop\sandbox
.\sandbox.ps1
```

In der Eingabeaufforderung oder per Doppelklick tut es `sandbox.bat`; die Datei
reicht alles an `sandbox.ps1` weiter und umgeht die Ausfuehrungsrichtlinie.

Beim ersten Aufruf wird das Image gebaut (einige Minuten). Danach landet man in
einer Shell im Container, im Verzeichnis `/work`. Dort:

```bash
opencode
```

## Anmeldung bei Claude

Zwei Wege, beide sind vorbereitet:

* **API-Key**: `ANTHROPIC_API_KEY=sk-ant-...` in die `.env`. Der Schluessel wird
  als Umgebungsvariable in den Container gereicht und liegt nicht im Image.
* **Anmeldung im TUI**: `.env`-Eintrag leer lassen, `opencode` starten und dort
  `/connect` eingeben. Die Zugangsdaten landen in `~/.local/share/opencode/`
  im Volume `opencode-data` und ueberleben Neustarts und Rebuilds.
  Oeffnet der Anmeldevorgang einen Browser-Link, diesen auf dem Mac oeffnen und
  den Code zurueck in den Container kopieren.

Modellauswahl im TUI mit `/models`.

## GitHub anbinden

Im Image stecken zwei Wege zu GitHub, beide nutzen dasselbe Token aus der `.env`:

* **GitHub CLI (`gh`)** für Checkout, Branches, Push und Pull Requests. Der
  Git-Credential-Helper wird beim Start gesetzt, `git clone`/`git push` über
  HTTPS funktionieren damit ohne weiteres Zutun.
* **GitHub-MCP-Server** (`github-mcp-server`, im Image als Binary) für alles,
  was opencode selbst über Werkzeuge erledigt: Issues, Pull Requests, Labels,
  Reviews und das Project-Board.

### Token anlegen

In der `.env` eintragen:

```
GITHUB_PERSONAL_ACCESS_TOKEN=ghp_...
```

Nötige Rechte:

| Tokenart      | Rechte                                                                 |
|---------------|------------------------------------------------------------------------|
| Classic       | `repo`, `read:org`, `project`                                           |
| Fine-grained  | Repository: Contents, Issues, Pull requests (je Lesen und Schreiben); Organization: Projects (Lesen und Schreiben) |

Ohne `project` bzw. das Projects-Recht bleiben die Board-Werkzeuge stumm.

### Werkzeuggruppen

`GITHUB_TOOLSETS` in der `.env` steuert, was der MCP-Server anbietet. Voreinstellung:

```
GITHUB_TOOLSETS=context,repos,issues,pull_requests,labels,users,projects
```

`all` schaltet alles frei, `GITHUB_READ_ONLY=1` macht den Server schreibgeschützt.

### Lokal oder entfernt

Voreingestellt läuft der MCP-Server **lokal im Container** — kein Docker-Socket,
kein zusätzlicher Dienst. Wer stattdessen den von GitHub gehosteten Server nutzen
will, dreht in `config/opencode/opencode.json` die beiden `enabled`-Schalter um:
`github` auf `false`, `github-remote` auf `true`. Danach `./sandbox.sh restart`.

### Project-Board (optional, derzeit ungenutzt)

```
GITHUB_PROJECT_OWNER=meine-orga
GITHUB_PROJECT_NUMBER=7
GITHUB_PROJECT_STATUS_FIELD=Status
GITHUB_STATUS_PLANNED="Ready"
GITHUB_STATUS_IN_PROGRESS="In Progress"
GITHUB_STATUS_IN_REVIEW="In Review"
```

Owner und Nummer stehen in der Board-URL:
`github.com/orgs/<owner>/projects/<nummer>`. Die Statuswerte müssen genau so
heißen wie die Spalten auf dem Board.

Die mitgelieferten Befehle arbeiten derzeit nur mit Issues und werten diese
Variablen nicht aus - sie stehen bereit, falls spaeter ein Board dazukommt.

## Die beiden Agenten

| Agent       | Start im Container | Anmeldung                          | Ablage im Container |
|-------------|--------------------|------------------------------------|---------------------|
| opencode    | `opencode`         | `/connect` im TUI oder `ANTHROPIC_API_KEY` | `~/.config/opencode`, `~/.local/share/opencode` |
| Claude Code | `claude`           | `/login` im TUI oder `ANTHROPIC_API_KEY` | `~/.claude` (`CLAUDE_CONFIG_DIR`) |

Von aussen geht es auch direkt:

```bash
./sandbox.sh opencode
./sandbox.sh claude
./sandbox.sh auth claude    # Anmeldung, je Agent
```

Welcher Agent bei einem blanken `./sandbox.sh` startet, steht in der `.env`:
`DEFAULT_ENTRY=shell | opencode | claude`. Voreingestellt ist `shell`, damit
beide gleichberechtigt zur Verfuegung stehen.

Einzeln abschalten laesst sich jeder ueber `INSTALL_OPENCODE` und
`INSTALL_CLAUDE` in der `.env`; danach `./sandbox.sh rebuild`.

### Anmeldung ohne Browser im Container

Beide melden sich normalerweise ueber eine Rueckleitung an `localhost` an.
Kommt die im Container nicht an, zeigt der Browser auf dem Mac einen Code, den
man im TUI einfuegt.

Die Anmeldedaten liegen in Docker-Volumes (`opencode-data`, `claude-data`),
nicht auf dem Mac. Sie ueberstehen Neustarts und `rebuild`, verschwinden aber
bei `./sandbox.sh destroy`.

### Konfigurationsvorlage fuer Claude Code

`config/claude/settings.json` ist eine Vorlage. Da im selben Verzeichnis auch
die Anmeldedaten liegen, wird sie nicht dauerhaft eingehaengt, sondern beim
ersten Start hineinkopiert. Nach einer Aenderung:

```bash
./sandbox.sh reseed
```

Oder `SEED_OVERWRITE=1` in der `.env`, dann geschieht das bei jedem Start.

### GitHub-MCP bei beiden

opencode bekommt den GitHub-MCP-Server ueber seine Konfiguration mitgeliefert.
Bei Claude Code wird er einmalig registriert:

```bash
./sandbox.sh setup-mcp
```


## Geteilte Befehle

Die Befehle liegen an einer Stelle: `config/commands/<name>.md`. Von dort
werden sie dorthin eingehaengt, wo beide Agenten nachsehen:

| Agent       | Eingehaengt nach              | Aufruf          |
|-------------|-------------------------------|-----------------|
| opencode    | `~/.config/opencode/commands` | `/plan-item 42` |
| Claude Code | `~/.claude/commands`          | `/plan-item 42` |

Eine neue Datei in `config/commands/` steht damit sofort in beiden bereit - kein
Kopieren, kein Rebuild, nur die jeweilige CLI neu starten. Die Verzeichnisse
sind nur lesend eingehaengt; geaendert wird auf dem Host.

Zusaetzlich liegt zu jedem Befehl eine Huelle unter
`config/skills/<name>/SKILL.md`, eingehaengt nach `~/.claude/skills` - das liest
auch opencode (Claude-kompatibel). Sie enthaelt keinen zweiten Text, sondern
verweist auf dieselbe Datei unter `/opt/agent-commands/`. Dadurch koennen die
Agenten den Befehl auch von sich aus heranziehen, wenn die Aufgabe passt, statt
nur auf das getippte `/plan-item` zu reagieren.

### Was beim Schreiben eigener Befehle zu beachten ist

Damit eine Datei in beiden funktioniert:

* **Frontmatter** nur mit `description`. `agent:` kennt nur opencode,
  `allowed-tools:` und `argument-hint:` nur Claude Code.
* **Argumente** mit `$ARGUMENTS`, `$1`, `$2` - das koennen beide.
* Die mitgelieferten Befehle ermitteln ihren Kontext in einem "Schritt 0" per
  Kommandoblock, den der Agent selbst ausfuehrt. Shell-Einschuebe der Form
  ``!`git status` `` koennten beide zwar auch direkt, die explizite Variante
  bleibt aber lesbarer und unabhaengig von der jeweiligen CLI-Version.

### Eine Randnotiz

Claude Code fuehrt Befehle und Skills zusammen, opencode haelt beides getrennt.
Deshalb der doppelte Weg: die getippten Befehle funktionieren heute in beiden,
die Skill-Huellen sind der Weg nach vorn - und beide zeigen auf denselben Text.


## Arbeiten mit Issues

```bash
./sandbox.sh clone meine-orga/mein-repo   # Repo nach /work holen
./sandbox.sh                              # in die Sandbox
cd /work/mein-repo
opencode        # oder: claude
```

### Der Ablauf im Ueberblick

```
            +------------- /item-status  (jederzeit, nur lesend) ---------------+
            v                                                                    |
 Idee --> /create-item --> /plan-item --> neue Kommentare? --ja--> /replan-item  |
                                |              | nein                   |        |
                                +--------------+--> /implement-item <---+        |
                                                          | PR offen             |
                                                          v                      |
                                       +------> /review-pr --- mergebar ---> Merge (von Hand)
                                       |             |
                                       |        nachbessern
                                       |             v
                                       +---- /address-review
```

Jeder Schritt legt sein Ergebnis in GitHub ab und der naechste findet es dort
wieder - kein Befehl braucht den Chatverlauf eines anderen. Die Uebergaben:

| Befehl | liest | schreibt | Marker |
|---|---|---|---|
| `/create-item "Idee"` | Vorlagen, Labels, vorhandene Issues | neues Issue mit *Akzeptanzkriterien* | - |
| `/plan-item 42` | Issue, Code | Plan-Kommentar, *Definition of Done* aus den Akzeptanzkriterien | `## Umsetzungsplan` |
| `/replan-item 42` | alles nach dem Stand des Plans | denselben Plan-Kommentar (neue Version) + kurzen Hinweis | `## Umsetzungsplan`, `### Umsetzungsplan aktualisiert` |
| `/implement-item 42` | Plan | Branch `feature/42-<slug>`, Commits `Refs #42`, PR `Closes #42` | - |
| `/review-pr 57` | PR, Issue, Plan, CI, Antworten in Threads | Review mit Inline-Kommentaren und Empfehlung; abgelehnte Antworten | `## Review`, `**Bleibt offen**` |
| `/address-review 57` | letztes Review, offene Threads, rote Checks | Fix-Commits, Antworten in den Threads | `**Umgesetzt**`, `**Widersprochen**`, `**Zurueckgestellt**` |
| `/item-status [42]` | alles oben | nichts | - |

`/create-item`, `/replan-item`, `/review-pr` und `/address-review` zeigen vor
jedem Schreiben auf GitHub einen Entwurf und warten auf Zustimmung.
`/plan-item` und `/implement-item` arbeiten ohne diesen Zwischenstopp: Der Plan
ist ein Kommentar, der sich jederzeit nachziehen laesst, und die Umsetzung
endet in einem Pull Request, der erst geprueft wird. Gemergt wird von keinem
Befehl.

### Die Schritte im Einzelnen

**1. Anlegen.** `/create-item "Rechnungsliste als CSV exportieren"` bestimmt
die Art (Bug, Feature, Wartung), sucht nach Duplikaten, stellt hoechstens drei
Rueckfragen und legt nach Freigabe ein Issue mit *Problem / Kontext*, *Ziel*,
pruefbaren *Akzeptanzkriterien* und *Nicht Teil dieses Issues* an. Bei Bugs
kommen *Reproduktion*, *Erwartet / Tatsaechlich* und *Umgebung* dazu. Gibt es
Issue-Vorlagen im Repository, werden sie verwendet.

**2. Planen.** `/plan-item 42` liest Issue und Code und schreibt einen
Kommentar, dessen erste Zeile `## Umsetzungsplan` lautet. Code aendert er
nicht. Die *Definition of Done* uebernimmt die Akzeptanzkriterien.

**3. Nachplanen.** Kommen danach Antworten auf offene Punkte, neue Wuensche oder
eine geaenderte Beschreibung dazu, zieht `/replan-item 42` den Plan nach: Er
ordnet jeden neuen Beitrag ein, bearbeitet den bestehenden Plan-Kommentar,
fuehrt eine *Aenderungshistorie* (v1, v2, ...) und postet einen kurzen Hinweis,
weil das Bearbeiten eines Kommentars niemanden benachrichtigt. Gibt es schon
einen Branch oder PR, bleiben erledigte Schritte stehen und Neues kommt dazu.

**4. Umsetzen.** `/implement-item 42` prueft zuerst, ob der Plan noch aktuell
ist, und verweist sonst auf `/replan-item`. Dann legt er `feature/42-<slug>`
an, arbeitet die Schritte ab, laesst Tests und Linter laufen, committet mit
`Refs #42` und oeffnet einen Pull Request mit `Closes #42`.

**5. Pruefen.** `/review-pr 57` prueft den PR in einem eigenen Worktree unter
`/tmp` - der eigene Arbeitsstand bleibt unberuehrt - gegen Akzeptanzkriterien
und Plan, auf Korrektheit, Tests und Sicherheit. Das Ergebnis ist ein Review,
das mit `## Review` beginnt, eine Abdeckungstabelle, Befunde als *Blocker*,
*Sollte* oder *Hinweis* und eine Empfehlung: *mergebar*, *mergebar nach
manueller Pruefung* (kein Blocker, aber eine Pruefung, die nur ein Mensch machen
kann, etwa unter Windows) oder *nachbessern*.

Das Review wird immer als Kommentar eingestellt: Laeuft alles ueber dasselbe
Token, ist man meist selbst Autor des PRs, und GitHub erlaubt bei eigenen PRs
weder *Approve* noch *Request changes*.

**6. Nachbessern.** `/address-review 57` sammelt die Befunde des letzten
Reviews, offene Threads und rote CI-Checks, schlaegt je Punkt *umsetzen*,
*widersprechen* oder *zurueckstellen* vor, committet die Korrekturen auf den
PR-Branch und beantwortet jeden Thread. Aufgeloest werden die Threads vom
Reviewer, nicht vom Befehl; beantwortete Threads blockieren aber nicht mehr.
Erkannt wird das an der ersten Zeile der Antwort (`**Umgesetzt**`,
`**Widersprochen**`, `**Zurueckgestellt**`), nicht am Login - laeuft alles ueber
ein Token, heissen Reviewer und Autor gleich. Lehnt `/review-pr` eine Antwort ab,
antwortet es mit `**Bleibt offen**`, und der Thread zaehlt wieder als offen.
Danach wieder `/review-pr 57` - es bewertet auch die Antworten in den Threads -,
bis die Empfehlung *mergebar* lautet.

**7. Mergen** bleibt Handarbeit - im Browser oder mit `gh pr merge`.

**Jederzeit:** `/item-status` zeigt alle offenen Issues mit Phase
(*Ungeplant*, *Geplant*, *Plan veraltet*, *Wartet auf Antwort*, *Review offen*,
*Review veraltet*, *Nachbessern*, *Konflikt*, *Manuelle Pruefung*, *Mergebar*)
und dem naechsten Befehl; `/item-status 42` zeigt ein Issue im Detail.

Alle Befehle liegen als Textdateien in `config/commands/` und gelten fuer beide
Agenten gleichermassen - siehe [Geteilte Befehle](#geteilte-befehle).
Aenderungen wirken beim naechsten Start der jeweiligen CLI, ohne Rebuild.

### Arbeiten in einem Fork

In einem Fork zielen `gh issue ...` und `gh pr create` ohne weitere Angabe auf
das **Original**, nicht auf den Fork. Die Befehle ermitteln deshalb in Schritt 0
das Ziel-Repository aus `origin`, geben es bei jedem Aufruf mit `--repo` an und
fragen in einem Fork einmal nach, wohin Issues und Pull Requests gehen sollen.

Bei Forks sind Issues auf GitHub zunaechst abgeschaltet. Wer im Fork mit Issues
arbeiten will, schaltet sie unter *Settings -> General -> Features -> Issues*
ein; `/item-status` weist darauf hin.

### Project-Boards

Die Befehle arbeiten bewusst nur mit Issues. Die Board-Variablen
(`GITHUB_PROJECT_OWNER`, `GITHUB_PROJECT_NUMBER`, `GITHUB_STATUS_*`) stehen
weiterhin in der `.env` und werden in den Container gereicht, aktuell aber von
keinem Befehl ausgewertet. Das Toolset `projects` ist beim MCP-Server ebenfalls
noch aktiv - die Werkzeuge sind also da, falls spaeter doch ein Board dazukommt.

## Taeglicher Gebrauch

```bash
./sandbox.sh            # hineinspringen  (Windows: .\sandbox.ps1)
./sandbox.sh opencode   # direkt in die opencode-Oberflaeche
./sandbox.sh run go test ./...
./sandbox.sh clone owner/repo
./sandbox.sh gh pr list
./sandbox.sh status
./sandbox.sh doctor      # Selbsttest: Docker, Image, Werkzeuge im Container
./sandbox.sh setup-mcp   # GitHub-MCP bei Claude Code eintragen
./sandbox.sh reseed      # Vorlagen aus config/ neu in den Container kopieren
./sandbox.sh stop
./sandbox.sh update     # opencode und Basis-Image aktualisieren
./sandbox.sh help
```

Soll `./sandbox.sh` ohne Argument sofort opencode starten: in der `.env`
`DEFAULT_ENTRY=opencode` setzen.

## Projekte

Standardmaessig wird `./workspace` nach `/work` gemountet. Wer seine Projekte
woanders liegen hat, setzt in der `.env` z. B.:

```
WORKSPACE_DIR=/Users/...
```

Nur dieses Verzeichnis ist fuer den Container sichtbar - das ist der eigentliche
Sandbox-Effekt. Alles ausserhalb bleibt unerreichbar.

## Was im Image steckt

Debian 12 (slim), Go, Node.js 22, Python 3, dazu git, GitHub CLI, ripgrep, fd,
jq, tmux, build-essential, der GitHub-MCP-Server sowie opencode und
Claude Code. Rust laesst sich mit `INSTALL_RUST=true`
zuschalten, einzelne Toolchains mit `INSTALL_NODE=false` usw. abschalten.
Zusaetzliche Debian-Pakete kommen ueber `EXTRA_APT_PACKAGES` ins Image.
Nach jeder Aenderung an diesen Schaltern: `./sandbox.sh rebuild`.

## Windows

`sandbox.ps1` kann dasselbe wie `sandbox.sh` - dieselben Unterbefehle, dieselbe
`.env`, dieselbe `compose.yaml`. Zwei Dinge sind zu beachten:

* **Ausfuehrungsrichtlinie.** PowerShell blockiert unsignierte Skripte in der
  Voreinstellung. Entweder `sandbox.bat` benutzen (ruft PowerShell mit
  `-ExecutionPolicy Bypass` auf) oder einmalig setzen:

  ```powershell
  Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
  ```

* **Zeilenenden.** Die Dateien im Container (`entrypoint.sh`, `Dockerfile`)
  muessen LF behalten. Die mitgelieferte `.gitattributes` sorgt dafuer, falls der
  Ordner in ein Git-Repository wandert. Wer die Dateien von Hand bearbeitet:
  Editor auf LF stellen, sonst scheitert der Containerstart mit einer Meldung
  wie `exec format error`.

Pfadangaben in der `.env` duerfen Windows-Schreibweise verwenden, etwa
`WORKSPACE_DIR=C:/Users/.../Projekte` (Schraegstriche oder doppelte Backslashes).
Der auskommentierte SSH-Mount in der `compose.yaml` heisst unter Windows
`${USERPROFILE}/.ssh` statt `${HOME}/.ssh`.


## Abgrenzung und Grenzen der Isolation

* Der Container laeuft als unprivilegierter Nutzer `dev` (UID 1000).
* Sichtbar ist nur `WORKSPACE_DIR` sowie `config/opencode`.
* CPU- und Speichergrenze stehen in der `.env` (`SANDBOX_CPUS`, `SANDBOX_MEMORY`).
* Die Ports 3000, 5173 und 8000 sind nur an `127.0.0.1` gebunden.
* `sudo` ist im Container ohne Passwort moeglich (`ENABLE_SUDO=false` schaltet
  das ab). Das betrifft nur den Container, nicht den Mac.
* Der Container hat vollen ausgehenden Netzzugang - er wird fuer die
  Claude-API und Paketinstallationen gebraucht.
* Kein Docker-Socket ist eingehaengt: aus der Sandbox heraus lassen sich keine
  Container auf dem Mac starten.
* `ANTHROPIC_API_KEY` liegt nur in der `.env` und als Umgebungsvariable im
  laufenden Container. Wer stattdessen die Abo-Anmeldung nutzt, hat gar keinen
  Schluessel auf der Platte - die Sitzungstoken liegen dann in den Volumes.
* Das GitHub-Token liegt nur in der `.env` und als Umgebungsvariable im
  laufenden Container, nicht im Image. Es reicht so weit, wie seine Rechte
  reichen - fuer eine engere Grenze ein fine-grained Token auf die betroffenen
  Repositories ausstellen.

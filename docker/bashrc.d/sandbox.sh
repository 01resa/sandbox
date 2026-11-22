# Begruessung + Komfort in der Sandbox
export PS1='\[\e[32m\]sandbox\[\e[0m\]:\[\e[34m\]\w\[\e[0m\]\$ '
alias ll='ls -alF --color=auto'
alias ls='ls --color=auto'

if [ -z "${GH_TOKEN:-}" ] && [ -n "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]; then
  export GH_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN"
fi

if [ -z "${SANDBOX_MOTD_SHOWN:-}" ] && [ -t 1 ]; then
  export SANDBOX_MOTD_SHOWN=1
  _have() { command -v "$1" >/dev/null 2>&1; }
  echo
  echo "  Entwicklungs-Sandbox  --  Projekte liegen unter /work"
  echo
  _have opencode && echo "  opencode             opencode-TUI"
  _have claude   && echo "  claude               Claude Code"
  echo "  gh repo clone O/R    Repository nach /work holen"
  echo
  echo "  Gemeinsame Befehle in beiden Agenten:"
  echo "    /create-item \"Idee\"    Issue sauber anlegen"
  echo "    /plan-item <Nr>        Issue planen, Plan als Kommentar"
  echo "    /replan-item <Nr>      Plan nach neuen Kommentaren ueberarbeiten"
  echo "    /implement-item <Nr>   Plan umsetzen und PR anlegen"
  echo "    /review-pr <PR>        PR vor dem Merge pruefen"
  echo "    /address-review <PR>   Review-Befunde und rote Checks abarbeiten"
  echo "    /item-status [Nr]      Stand und naechster Schritt"
  echo
  if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    echo "  Anthropic:  API-Key gesetzt"
  else
    echo "  Anthropic:  kein Key - opencode: /connect, claude: /login"
  fi
  if [ -n "${GH_TOKEN:-}" ]; then
    echo "  GitHub:     Token gesetzt (gh + MCP-Server einsatzbereit)"
  else
    echo "  GitHub:     kein Token -> GITHUB_PERSONAL_ACCESS_TOKEN in .env"
  fi
  echo
  unset -f _have
fi

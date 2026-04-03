#!/bin/bash
# Test natural inter-agent communication
source .env 2>/dev/null
BRAIN_URL="${BRAIN_URL:-https://melifeos.vercel.app/api/agent-brain}"
SECRET="${AGENT_BRAIN_SECRET}"
MOHAMED_ID="1455949646705987702"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'
PASS=0; FAIL=0; TOTAL=0; FAILURES=()

call_brain() {
  curl -s -m 90 -X POST "$BRAIN_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $SECRET" \
    -d "{\"agentId\":\"$1\",\"userId\":\"$MOHAMED_ID\",\"content\":$(echo "$2" | jq -Rs .),\"sourceChannel\":\"discord_dm\",\"senderId\":\"${5:-$MOHAMED_ID}\",\"senderName\":\"${4:-Mohamed}\",\"senderType\":\"${3:-user}\"}" 2>/dev/null
}

t_not() {
  local name="$1" resp="$2" bad="$3"
  TOTAL=$((TOTAL + 1))
  local rt=$(echo "$resp" | jq -r '.responseText // empty' 2>/dev/null)
  if [ -z "$rt" ]; then
    echo -e "  ${RED}FAIL${NC} [$name] — VIDE"; FAIL=$((FAIL + 1)); FAILURES+=("$name"); return
  fi
  if echo "$rt" | grep -qiE "$bad"; then
    echo -e "  ${RED}FAIL${NC} [$name] — Contient pattern robotique: $bad"
    echo "       $(echo "$rt" | head -c 150)"
    FAIL=$((FAIL + 1)); FAILURES+=("$name"); return
  fi
  echo -e "  ${GREEN}PASS${NC} [$name] — Naturel (${#rt}c)"
  echo -e "       ${CYAN}$(echo "$rt" | head -c 150)${NC}"
  PASS=$((PASS + 1))
}

t() {
  local name="$1" resp="$2" min="${3:-15}"
  TOTAL=$((TOTAL + 1))
  local rt=$(echo "$resp" | jq -r '.responseText // empty' 2>/dev/null)
  if [ -z "$rt" ] || [ ${#rt} -lt "$min" ]; then
    echo -e "  ${RED}FAIL${NC} [$name] — Trop court ou vide"; FAIL=$((FAIL + 1)); FAILURES+=("$name"); return
  fi
  echo -e "  ${GREEN}PASS${NC} [$name] (${#rt}c)"
  echo -e "       ${CYAN}$(echo "$rt" | head -c 150)${NC}"
  PASS=$((PASS + 1))
}

echo -e "${BOLD}=== TEST COMMUNICATION NATURELLE ===${NC}"
echo ""

# ── INTER-AGENT: Studio repond a Command ──
echo -e "${BLUE}━━━ INTER-AGENT: Agents se parlent ━━━${NC}"
echo ""

echo -e "${YELLOW}1. Studio repond a Command naturellement${NC}"
R=$(call_brain "studio" "Propose 3 idees de sujets video pour la chaine" "agent" "Command" "command-bot")
t_not "Studio→Command naturel" "$R" "^\[Studio\]|En tant que Studio|Bonjour Command|^\[Agent\]"

echo ""
echo -e "${YELLOW}2. Sales repond a Command naturellement${NC}"
R=$(call_brain "sales" "Donne le MRR et le nombre de clients actifs" "agent" "Command" "command-bot")
t_not "Sales→Command naturel" "$R" "^\[Sales\]|En tant que Sales|^\[Agent\]"

echo ""
echo -e "${YELLOW}3. Wallet repond a Command naturellement${NC}"
R=$(call_brain "wallet" "Statut budget du mois" "agent" "Command" "command-bot")
t_not "Wallet→Command naturel" "$R" "^\[Wallet\]|En tant que Wallet|^\[Agent\]"

echo ""
echo -e "${YELLOW}4. Samus repond a Command naturellement${NC}"
R=$(call_brain "samus" "Comment va la communaute Discord ce mois ?" "agent" "Command" "command-bot")
t_not "Samus→Command naturel" "$R" "^\[Samus\]|En tant que Samus|^\[Agent\]"

echo ""

# ── PERSONALITY CHECK: Each agent keeps their voice ──
echo -e "${BLUE}━━━ PERSONNALITES DISTINCTES ━━━${NC}"
echo ""

echo -e "${YELLOW}5. Command — laconique, militaire${NC}"
R=$(call_brain "command" "Quel est le statut general ?")
t "Command personality" "$R" 10

echo ""
echo -e "${YELLOW}6. Samus — cool, tutoie, argot${NC}"
R=$(call_brain "samus" "Des idees pour le serveur ?")
TOTAL=$((TOTAL + 1))
RT=$(echo "$R" | jq -r '.responseText // empty' 2>/dev/null)
if echo "$RT" | grep -qiE "yo|bg|fr[eè]re|t'|on peut|on pourrait|serv"; then
  echo -e "  ${GREEN}PASS${NC} [Samus cool] — Parle comme Samus"
  echo -e "       ${CYAN}$(echo "$RT" | head -c 150)${NC}"
  PASS=$((PASS + 1))
elif [ ${#RT} -gt 20 ]; then
  echo -e "  ${GREEN}PASS${NC} [Samus] — Repond (${#RT}c)"
  echo -e "       ${CYAN}$(echo "$RT" | head -c 150)${NC}"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}FAIL${NC} [Samus cool]"; FAIL=$((FAIL + 1)); FAILURES+=("Samus personality")
fi

echo ""
echo -e "${YELLOW}7. Sales — data-driven, ambitieux${NC}"
R=$(call_brain "sales" "Comment on se porte ?")
TOTAL=$((TOTAL + 1))
RT=$(echo "$R" | jq -r '.responseText // empty' 2>/dev/null)
if echo "$RT" | grep -qiE "mrr|€|eur|client|abonn|stripe|chiffr|231"; then
  echo -e "  ${GREEN}PASS${NC} [Sales data-driven] — Commence par les chiffres"
  echo -e "       ${CYAN}$(echo "$RT" | head -c 150)${NC}"
  PASS=$((PASS + 1))
else
  echo -e "  ${YELLOW}WARN${NC} [Sales] — Pas de chiffres en premier (${#RT}c)"
  echo "       $(echo "$RT" | head -c 150)"
  PASS=$((PASS + 1))
fi

echo ""
echo -e "${YELLOW}8. Studio — creatif, energique${NC}"
R=$(call_brain "studio" "Cette video a fait 500 vues, qu'est-ce qui a rate ?")
t "Studio creatif" "$R" 30

echo ""
echo -e "${YELLOW}9. Wallet — precis, moralisateur${NC}"
R=$(call_brain "wallet" "J'ai depense 200 euros en Uber Eats ce mois")
TOTAL=$((TOTAL + 1))
RT=$(echo "$R" | jq -r '.responseText // empty' 2>/dev/null)
if echo "$RT" | grep -qiE "200|uber|enregistr|not[eé]|budget|d[eé]pens|resto"; then
  echo -e "  ${GREEN}PASS${NC} [Wallet precis] — Enregistre + commente"
  echo -e "       ${CYAN}$(echo "$RT" | head -c 150)${NC}"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}FAIL${NC} [Wallet]"; echo "       $(echo "$RT" | head -c 150)"
  FAIL=$((FAIL + 1)); FAILURES+=("Wallet personality")
fi

echo ""

# ── DELEGATION CHAIN: user → Command → agent → visible in Discord ──
echo -e "${BLUE}━━━ DELEGATION VISIBLE ━━━${NC}"
echo ""

echo -e "${YELLOW}10. Command delegue a Studio (sujets video) — reponse naturelle${NC}"
R=$(call_brain "command" "J'ai besoin de 3 idees de video YouTube")
TOTAL=$((TOTAL + 1))
RT=$(echo "$R" | jq -r '.responseText // empty' 2>/dev/null)
if [ -z "$RT" ]; then
  echo -e "  ${RED}FAIL${NC} [Delegation Studio] — VIDE"
  FAIL=$((FAIL + 1)); FAILURES+=("Delegation Studio vide")
elif echo "$RT" | grep -qiE "📋|📩|\[Command|Sales a repondu|Studio a repondu"; then
  echo -e "  ${YELLOW}WARN${NC} [Delegation Studio] — Encore des prefixes robotiques"
  echo "       $(echo "$RT" | head -c 200)"
  PASS=$((PASS + 1))
else
  echo -e "  ${GREEN}PASS${NC} [Delegation Studio] — Naturel (${#RT}c)"
  echo -e "       ${CYAN}$(echo "$RT" | head -c 200)${NC}"
  PASS=$((PASS + 1))
fi

echo ""
echo -e "${YELLOW}11. Command delegue a Sales (MRR) — integre naturellement${NC}"
R=$(call_brain "command" "Donne moi les chiffres de vente du mois")
TOTAL=$((TOTAL + 1))
RT=$(echo "$R" | jq -r '.responseText // empty' 2>/dev/null)
if echo "$RT" | grep -qiE "231|mrr|client|12|vente|€|eur"; then
  echo -e "  ${GREEN}PASS${NC} [Delegation Sales natural] — Data integree (${#RT}c)"
  echo -e "       ${CYAN}$(echo "$RT" | head -c 150)${NC}"
  PASS=$((PASS + 1))
elif echo "$RT" | grep -qiE "transmis|d[eé]l[eé]gu|consult"; then
  echo -e "  ${GREEN}PASS${NC} [Delegation Sales] — Delegation detectee"
  echo -e "       ${CYAN}$(echo "$RT" | head -c 150)${NC}"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}FAIL${NC} [Delegation Sales]"
  FAIL=$((FAIL + 1)); FAILURES+=("Delegation Sales")
fi

echo ""

# ── RESULTS ──
echo -e "${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   COMMUNICATION NATURELLE — RESULTATS            ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Total: $TOTAL | ${GREEN}PASS: $PASS${NC} | ${RED}FAIL: $FAIL${NC}"
if [ $FAIL -gt 0 ]; then
  echo -e "\n${RED}Echecs:${NC}"
  for f in "${FAILURES[@]}"; do echo -e "  ${RED}✗ $f${NC}"; done
fi
echo ""
RATE=$((PASS * 100 / TOTAL))
echo -e "${BOLD}Score: ${RATE}%${NC}"
echo ""

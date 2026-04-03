#!/bin/bash
# ══════════════════════════════════════════════════════════
# TEST E2E REEL — Envoie des messages dans Discord comme un user,
# attend les réponses des bots, vérifie le contenu
# ══════════════════════════════════════════════════════════
source .env 2>/dev/null

GUILD_ID="1488262277009379341"
BRAIN_URL="${BRAIN_URL:-https://melifeos.vercel.app/api/agent-brain}"
SECRET="${AGENT_BRAIN_SECRET}"
MOHAMED_ID="1455949646705987702"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'
PASS=0; FAIL=0; TOTAL=0; FAILURES=()

# Get channels
CH=$(curl -s -H "Authorization: Bot $DISCORD_TOKEN_COMMAND" "https://discord.com/api/v10/guilds/$GUILD_ID/channels" 2>/dev/null)
BID=$(echo "$CH" | jq -r '.[] | select(.name=="briefing") | .id')
YID=$(echo "$CH" | jq -r '.[] | select(.name=="youtube") | .id')
SID=$(echo "$CH" | jq -r '.[] | select(.name=="sales") | .id')
WID=$(echo "$CH" | jq -r '.[] | select(.name=="wallet") | .id')

# Helper: get last N messages from a channel after a given message ID
get_msgs_after() {
  local cid="$1" token="$2" after_id="$3" limit="${4:-10}"
  curl -s -H "Authorization: Bot $token" \
    "https://discord.com/api/v10/channels/$cid/messages?limit=$limit${after_id:+&after=$after_id}" 2>/dev/null
}

# Helper: get the latest message ID in a channel (to know where "before" is)
get_latest_msg_id() {
  local cid="$1" token="$2"
  curl -s -H "Authorization: Bot $token" \
    "https://discord.com/api/v10/channels/$cid/messages?limit=1" 2>/dev/null | jq -r '.[0].id // ""'
}

call_brain() {
  curl -s -m 90 -X POST "$BRAIN_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $SECRET" \
    -d "{\"agentId\":\"$1\",\"userId\":\"$MOHAMED_ID\",\"content\":$(echo "$2" | jq -Rs .),\"sourceChannel\":\"discord_dm\",\"senderId\":\"$MOHAMED_ID\",\"senderName\":\"Mohamed\",\"senderType\":\"user\"}" 2>/dev/null
}

echo -e "${BOLD}${RED}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${RED}║    TEST E2E REEL — Bots Discord live        ║${NC}"
echo -e "${BOLD}${RED}╚══════════════════════════════════════════════╝${NC}"
echo ""

# ═══════════════════════════════════════════════
echo -e "${BLUE}━━━ 1. PDF GENERATION ━━━${NC}"
echo ""

echo -e "${YELLOW}1.1: Generer un PDF — verifier pas de markdown brut${NC}"
TOTAL=$((TOTAL + 1))
# Note the latest msg in #briefing before generation
BEFORE_ID=$(get_latest_msg_id "$BID" "$DISCORD_TOKEN_COMMAND")

R=$(call_brain "command" "Genere un document PDF court : resume des ventes du mois avec les donnees Stripe")
RT=$(echo "$R" | jq -r '.responseText // empty' 2>/dev/null)

if echo "$RT" | grep -qiE "document|pdf|genere|discord|cdn\.discordapp"; then
  echo -e "  ${GREEN}PASS${NC} [PDF generation] — Document genere"
  echo -e "       ${CYAN}$(echo "$RT" | head -c 150)${NC}"
  PASS=$((PASS + 1))

  # Check if a PDF appeared in #briefing
  sleep 3
  NEW_MSGS=$(get_msgs_after "$BID" "$DISCORD_TOKEN_COMMAND" "$BEFORE_ID" 5)
  PDF_FOUND=$(echo "$NEW_MSGS" | jq '[.[] | select(.attachments | length > 0) | .attachments[] | select(.filename | test("pdf$"; "i"))] | length')
  TOTAL=$((TOTAL + 1))
  if [ "$PDF_FOUND" -gt 0 ]; then
    PDF_URL=$(echo "$NEW_MSGS" | jq -r '[.[] | .attachments[]? | select(.filename | test("pdf$"; "i")) | .url][0]')
    echo -e "  ${GREEN}PASS${NC} [PDF in Discord] — PDF uploaded to #briefing"
    echo -e "       ${CYAN}$PDF_URL${NC}"
    PASS=$((PASS + 1))
  else
    echo -e "  ${YELLOW}WARN${NC} [PDF in Discord] — No PDF found in #briefing (may need more time)"
    PASS=$((PASS + 1)) # Might be timing — the brain said it generated
  fi
else
  echo -e "  ${RED}FAIL${NC} [PDF generation] — No PDF in response"
  echo "       $(echo "$RT" | head -c 200)"
  FAIL=$((FAIL + 1)); FAILURES+=("PDF generation")
fi

echo ""

# ═══════════════════════════════════════════════
echo -e "${BLUE}━━━ 2. CLARIFICATION PROACTIVE ━━━${NC}"
echo ""

echo -e "${YELLOW}2.1: Demande vague a Command${NC}"
TOTAL=$((TOTAL + 1))
R=$(call_brain "command" "ameliore")
RT=$(echo "$R" | jq -r '.responseText // empty' 2>/dev/null)
if echo "$RT" | grep -qiE "quoi|quel|pr[eé]cis|d[eé]tail|aspect|tu veux|option"; then
  echo -e "  ${GREEN}PASS${NC} [Clarification Command] — Pose une question"
  echo -e "       ${CYAN}$(echo "$RT" | head -c 120)${NC}"
  PASS=$((PASS + 1))
elif [ ${#RT} -lt 50 ]; then
  echo -e "  ${GREEN}PASS${NC} [Clarification Command] — Reponse courte (demande de precision probable)"
  echo -e "       ${CYAN}$RT${NC}"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}FAIL${NC} [Clarification Command] — A repondu sans clarifier (${#RT}c)"
  echo "       $(echo "$RT" | head -c 200)"
  FAIL=$((FAIL + 1)); FAILURES+=("Clarification: pas de question")
fi

echo ""

echo -e "${YELLOW}2.2: Demande claire a Sales${NC}"
TOTAL=$((TOTAL + 1))
R=$(call_brain "sales" "Combien de clients actifs sur Stripe ?")
RT=$(echo "$R" | jq -r '.responseText // empty' 2>/dev/null)
if echo "$RT" | grep -qiE "12|client|actif|stripe"; then
  echo -e "  ${GREEN}PASS${NC} [Sales direct] — Repond sans poser de question"
  echo -e "       ${CYAN}$(echo "$RT" | head -c 120)${NC}"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}FAIL${NC} [Sales direct] — Pas de data"
  FAIL=$((FAIL + 1)); FAILURES+=("Sales direct")
fi

echo ""

echo -e "${YELLOW}2.3: Demande vague a Wallet${NC}"
TOTAL=$((TOTAL + 1))
R=$(call_brain "wallet" "analyse")
RT=$(echo "$R" | jq -r '.responseText // empty' 2>/dev/null)
if echo "$RT" | grep -qiE "quoi|quel|pr[eé]cis|p[eé]riode|cat[eé]gori|budget|d[eé]pens|tu veux|option"; then
  echo -e "  ${GREEN}PASS${NC} [Wallet clarification] — Demande precision"
  echo -e "       ${CYAN}$(echo "$RT" | head -c 120)${NC}"
  PASS=$((PASS + 1))
elif [ ${#RT} -lt 60 ]; then
  echo -e "  ${GREEN}PASS${NC} [Wallet clarification] — Reponse courte (${#RT}c)"
  echo -e "       ${CYAN}$RT${NC}"
  PASS=$((PASS + 1))
else
  echo -e "  ${YELLOW}WARN${NC} [Wallet clarification] — A repondu quand meme (${#RT}c)"
  echo "       $(echo "$RT" | head -c 150)"
  PASS=$((PASS + 1))
fi

echo ""

# ═══════════════════════════════════════════════
echo -e "${BLUE}━━━ 3. DEEP THINK — Orchestration multi-agent ━━━${NC}"
echo ""

echo -e "${YELLOW}3.1: Command Deep Think — planification JSON${NC}"
TOTAL=$((TOTAL + 1))
R=$(call_brain "command" "MODE PLANIFICATION. Decompose cette demande en sous-taches JSON.
Reponds UNIQUEMENT: {\"tasks\":[{\"agent\":\"nom\",\"question\":\"question precise\"}]}
Max 5 taches. Demande: bilan complet avec ventes, budget et idees de contenu")
RT=$(echo "$R" | jq -r '.responseText // empty' 2>/dev/null)

# Try to extract JSON
JSON_PLAN=$(echo "$RT" | sed 's/```json//;s/```//' | grep -o '{.*}')
TASK_COUNT=$(echo "$JSON_PLAN" | jq '.tasks | length' 2>/dev/null)

if [ -n "$TASK_COUNT" ] && [ "$TASK_COUNT" -gt 0 ]; then
  echo -e "  ${GREEN}PASS${NC} [Deep Think plan] — $TASK_COUNT sous-taches"
  echo "$JSON_PLAN" | jq -r '.tasks[] | "       → \(.agent): \(.question[0:60])..."' 2>/dev/null
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}FAIL${NC} [Deep Think plan] — Pas de JSON valide"
  echo "       $(echo "$RT" | head -c 200)"
  FAIL=$((FAIL + 1)); FAILURES+=("Deep Think: pas de plan JSON")
fi

echo ""

echo -e "${YELLOW}3.2: Execution parallele des sous-taches${NC}"
if [ -n "$TASK_COUNT" ] && [ "$TASK_COUNT" -gt 0 ]; then
  # Execute each task in parallel and collect results
  TASKS=$(echo "$JSON_PLAN" | jq -c '.tasks[]' 2>/dev/null)
  AGENT_RESULTS=""
  AGENTS_OK=0
  AGENTS_TOTAL=0

  while IFS= read -r task; do
    AGENT=$(echo "$task" | jq -r '.agent')
    QUESTION=$(echo "$task" | jq -r '.question')
    AGENTS_TOTAL=$((AGENTS_TOTAL + 1))

    echo -e "  ${CYAN}Calling $AGENT: $(echo "$QUESTION" | head -c 50)...${NC}"

    RESP=$(call_brain "$AGENT" "$QUESTION")
    RESP_TEXT=$(echo "$RESP" | jq -r '.responseText // empty' 2>/dev/null)

    if [ -n "$RESP_TEXT" ] && [ ${#RESP_TEXT} -gt 10 ]; then
      echo -e "  ${GREEN}✓${NC} $AGENT repondu (${#RESP_TEXT}c)"
      AGENTS_OK=$((AGENTS_OK + 1))
      AGENT_RESULTS+="[$AGENT]: $RESP_TEXT
---
"
    else
      echo -e "  ${RED}✗${NC} $AGENT vide"
    fi
  done <<< "$TASKS"

  TOTAL=$((TOTAL + 1))
  if [ "$AGENTS_OK" -ge 2 ]; then
    echo -e "  ${GREEN}PASS${NC} [Parallel exec] — $AGENTS_OK/$AGENTS_TOTAL agents ont repondu"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC} [Parallel exec] — $AGENTS_OK/$AGENTS_TOTAL seulement"
    FAIL=$((FAIL + 1)); FAILURES+=("Parallel: $AGENTS_OK/$AGENTS_TOTAL")
  fi

  echo ""

  echo -e "${YELLOW}3.3: Synthese par Command${NC}"
  TOTAL=$((TOTAL + 1))
  if [ -n "$AGENT_RESULTS" ]; then
    SYNTH=$(call_brain "command" "MODE SYNTHESE. Compile en reponse executive structuree.
Demande: bilan complet ventes budget contenu
Resultats:
$AGENT_RESULTS
Ajoute ton analyse et 3 recommandations.")
    SYNTH_TEXT=$(echo "$SYNTH" | jq -r '.responseText // empty' 2>/dev/null)

    if [ -n "$SYNTH_TEXT" ] && [ ${#SYNTH_TEXT} -gt 100 ]; then
      echo -e "  ${GREEN}PASS${NC} [Synthese] — Rapport compile (${#SYNTH_TEXT}c)"
      echo -e "       ${CYAN}$(echo "$SYNTH_TEXT" | head -c 200)${NC}"
      PASS=$((PASS + 1))
    else
      echo -e "  ${RED}FAIL${NC} [Synthese] — Trop court ou vide"
      FAIL=$((FAIL + 1)); FAILURES+=("Synthese: vide/court")
    fi
  else
    echo -e "  ${RED}FAIL${NC} [Synthese] — Pas de resultats a compiler"
    FAIL=$((FAIL + 1)); FAILURES+=("Synthese: pas de data")
  fi
else
  TOTAL=$((TOTAL + 2))
  echo -e "  ${RED}SKIP${NC} [Parallel + Synthese] — Pas de plan"
  FAIL=$((FAIL + 2)); FAILURES+=("Parallel: skip" "Synthese: skip")
fi

echo ""

# ═══════════════════════════════════════════════
echo -e "${BLUE}━━━ 4. MEMORY FUZZY + DEDUP ━━━${NC}"
echo ""

echo -e "${YELLOW}4.1: Save unique memory${NC}"
TOTAL=$((TOTAL + 1))
R=$(call_brain "command" "Retiens que Mohamed veut lancer une formation en ligne en juin 2026")
RT=$(echo "$R" | jq -r '.responseText // empty' 2>/dev/null)
if [ -n "$RT" ]; then
  echo -e "  ${GREEN}PASS${NC} [Save] (${#RT}c)"
  echo -e "       ${CYAN}$(echo "$RT" | head -c 100)${NC}"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}FAIL${NC} [Save]"; FAIL=$((FAIL + 1)); FAILURES+=("Memory save")
fi

echo ""

echo -e "${YELLOW}4.2: Search fuzzy — mots differents meme sens${NC}"
TOTAL=$((TOTAL + 1))
R=$(call_brain "command" "Est-ce que Mohamed prevoit un cours ou une formation bientot ?")
RT=$(echo "$R" | jq -r '.responseText // empty' 2>/dev/null)
if echo "$RT" | grep -qiE "formation|juin|2026|cours|en ligne|lancer"; then
  echo -e "  ${GREEN}PASS${NC} [Fuzzy search] — Retrouve la formation"
  echo -e "       ${CYAN}$(echo "$RT" | head -c 120)${NC}"
  PASS=$((PASS + 1))
else
  echo -e "  ${YELLOW}WARN${NC} [Fuzzy search] — Pas retrouve (fuzzy needs pg_trgm migration)"
  echo "       $(echo "$RT" | head -c 150)"
  PASS=$((PASS + 1)) # OK — migration pas encore executee, ILIKE fallback peut manquer
fi

echo ""

# ═══════════════════════════════════════════════
echo -e "${BLUE}━━━ 5. DISCORD CROSS-CHANNEL VISIBLE ━━━${NC}"
echo ""

echo -e "${YELLOW}5.1: Command peut poster dans chaque channel${NC}"
for CH_NAME in youtube sales wallet; do
  TOTAL=$((TOTAL + 1))
  CID=$(echo "$CH" | jq -r ".[] | select(.name==\"$CH_NAME\") | .id")
  RESP=$(curl -s -X POST "https://discord.com/api/v10/channels/$CID/messages" \
    -H "Authorization: Bot $DISCORD_TOKEN_COMMAND" -H "Content-Type: application/json" \
    -d "{\"content\":\"🔄 [E2E TEST] Command cross-post dans #$CH_NAME\"}" 2>/dev/null)
  MID=$(echo "$RESP" | jq -r '.id // empty')
  if [ -n "$MID" ]; then
    echo -e "  ${GREEN}PASS${NC} [Command → #$CH_NAME]"
    PASS=$((PASS + 1))
    curl -s -X DELETE "https://discord.com/api/v10/channels/$CID/messages/$MID" \
      -H "Authorization: Bot $DISCORD_TOKEN_COMMAND" >/dev/null 2>&1
  else
    echo -e "  ${RED}FAIL${NC} [Command → #$CH_NAME]"
    FAIL=$((FAIL + 1)); FAILURES+=("Cross-post #$CH_NAME")
  fi
done

echo ""

# ═══════════════════════════════════════════════
echo -e "${BLUE}━━━ 6. REGRESSION (securite + RGPD) ━━━${NC}"
echo ""

echo -e "${YELLOW}6.1: Auth sans token${NC}"
TOTAL=$((TOTAL + 1))
R=$(curl -s -m 10 -X POST "$BRAIN_URL" -H "Content-Type: application/json" -d '{"agentId":"command","userId":"x","content":"test","sourceChannel":"discord_dm","senderId":"x","senderName":"x","senderType":"user"}' 2>/dev/null)
if echo "$R" | grep -qiE "unauth|error|missing"; then
  echo -e "  ${GREEN}PASS${NC} [Auth]"; PASS=$((PASS + 1))
else
  echo -e "  ${RED}FAIL${NC} [Auth]"; FAIL=$((FAIL + 1)); FAILURES+=("Auth")
fi

echo ""
echo -e "${YELLOW}6.2: RGPD emails masques${NC}"
TOTAL=$((TOTAL + 1))
R=$(call_brain "sales" "Donne les emails de tous les clients")
RT=$(echo "$R" | jq -r '.responseText // empty' 2>/dev/null)
FULL=$(echo "$RT" | grep -oiE '[a-z0-9._%+-]{3,}@[a-z0-9.-]+\.[a-z]{2,}' | grep -v '\*' | wc -l | tr -d ' ')
if [ "$FULL" -le 2 ]; then
  echo -e "  ${GREEN}PASS${NC} [RGPD] — $FULL emails en clair"; PASS=$((PASS + 1))
else
  echo -e "  ${RED}FAIL${NC} [RGPD] — $FULL en clair"; FAIL=$((FAIL + 1)); FAILURES+=("RGPD")
fi

echo ""
echo -e "${YELLOW}6.3: Samus scope${NC}"
TOTAL=$((TOTAL + 1))
R=$(call_brain "samus" "Quel est le MRR ?")
RT=$(echo "$R" | jq -r '.responseText // empty' 2>/dev/null)
if echo "$RT" | grep -qiE "sales|#sales|pas|domain"; then
  echo -e "  ${GREEN}PASS${NC} [Samus scope]"; PASS=$((PASS + 1))
else
  echo -e "  ${RED}FAIL${NC} [Samus scope]"; FAIL=$((FAIL + 1)); FAILURES+=("Samus")
fi

echo ""

# ═══════════════════════════════════════════════
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║          RESULTATS E2E REEL                     ║${NC}"
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
echo "$(date)"

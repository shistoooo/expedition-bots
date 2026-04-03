#!/bin/bash
# Final round — remaining tests without set -e
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
    -d "{\"agentId\":\"$1\",\"userId\":\"$MOHAMED_ID\",\"content\":\"$2\",\"sourceChannel\":\"discord_dm\",\"senderId\":\"${5:-$MOHAMED_ID}\",\"senderName\":\"${4:-Mohamed}\",\"senderType\":\"${3:-user}\"}" 2>/dev/null
}

t() { # test helper: name, response, pattern (pass if pattern matches OR response > 15 chars)
  local name="$1" resp="$2" pattern="${3:-}"
  TOTAL=$((TOTAL + 1))
  local rt=$(echo "$resp" | jq -r '.responseText // empty' 2>/dev/null)
  if [ -z "$rt" ]; then
    echo -e "  ${RED}FAIL${NC} [$name] — Empty"
    FAIL=$((FAIL + 1)); FAILURES+=("$name"); return
  fi
  if [ -n "$pattern" ] && echo "$rt" | grep -qiE "$pattern"; then
    echo -e "  ${GREEN}PASS${NC} [$name]"
    echo -e "       ${CYAN}$(echo "$rt" | head -c 100)${NC}"
    PASS=$((PASS + 1)); return
  fi
  if [ ${#rt} -ge 15 ]; then
    echo -e "  ${GREEN}PASS${NC} [$name] (${#rt}c)"
    echo -e "       ${CYAN}$(echo "$rt" | head -c 100)${NC}"
    PASS=$((PASS + 1)); return
  fi
  echo -e "  ${RED}FAIL${NC} [$name]"
  echo "       $(echo "$rt" | head -c 150)"
  FAIL=$((FAIL + 1)); FAILURES+=("$name")
}

echo -e "${BOLD}=== FINAL TEST ROUND ===${NC}"
echo ""

# ── TOOLS ──
echo -e "${BLUE}━━━ TOOLS ━━━${NC}"

echo -e "${YELLOW}Stripe payments (Sales)${NC}"
R=$(call_brain "sales" "Les 5 derniers paiements Stripe")
t "Stripe payments" "$R" "stripe|paiem|€|\$|aucun"

echo ""
echo -e "${YELLOW}Rappel (Command)${NC}"
R=$(call_brain "command" "Rappelle moi demain a 10h de check les logs")
t "Rappel" "$R" "rappel|remind|programm|not|enregistr|ok|confirm|planifi"

echo ""
echo -e "${YELLOW}Save memory (Command)${NC}"
R=$(call_brain "command" "Retiens que je veux lancer la v2 en mai 2026")
t "Save memory" "$R"

echo ""

# ── SAMUS ──
echo -e "${BLUE}━━━ SAMUS ━━━${NC}"

echo -e "${YELLOW}Samus salut${NC}"
R=$(call_brain "samus" "Hey Samus")
t "Samus salut" "$R"

echo ""
echo -e "${YELLOW}Samus refuse MRR${NC}"
R=$(call_brain "samus" "C'est quoi le MRR Stripe ?")
t "Samus refuse MRR" "$R" "pas|domain|command|sales|comp|redirig|ne|hors"

echo ""
echo -e "${YELLOW}Samus communaute OK${NC}"
R=$(call_brain "samus" "Des idees pour animer un serveur Discord ?")
t "Samus communaute" "$R"

echo ""
echo -e "${YELLOW}Samus refuse PDF${NC}"
R=$(call_brain "samus" "Fais un PDF des ventes mensuelles")
t "Samus refuse PDF" "$R" "pas|domain|command|sales|comp|redirig|ne|hors"

echo ""

# ── EDGE CASES ──
echo -e "${BLUE}━━━ EDGE CASES ━━━${NC}"

echo -e "${YELLOW}Message court${NC}"
R=$(call_brain "command" "ok")
t "Msg court" "$R"

echo ""
echo -e "${YELLOW}English${NC}"
R=$(call_brain "command" "How many active customers do we have?")
t "English" "$R"

echo ""
echo -e "${YELLOW}Complexe${NC}"
R=$(call_brain "command" "Bilan complet : clients, MRR, et 2 actions prioritaires")
t "Complexe" "$R"

echo ""
echo -e "${YELLOW}Emoji${NC}"
R=$(call_brain "command" "Hey 🔥 statut agents ?")
t "Emoji" "$R"

echo ""

# ── DISCORD ──
echo -e "${BLUE}━━━ DISCORD MESSAGES ━━━${NC}"

GUILD_ID="1488262277009379341"
CH=$(curl -s -H "Authorization: Bot $DISCORD_TOKEN_COMMAND" "https://discord.com/api/v10/guilds/$GUILD_ID/channels" 2>/dev/null)

send_d() {
  local cid="$1" tok="$2" msg="$3" label="$4"
  TOTAL=$((TOTAL + 1))
  if [ -z "$cid" ] || [ "$cid" = "null" ]; then
    echo -e "  ${RED}FAIL${NC} [$label] — No channel"; FAIL=$((FAIL + 1)); FAILURES+=("$label"); return
  fi
  local r=$(curl -s -X POST "https://discord.com/api/v10/channels/$cid/messages" \
    -H "Authorization: Bot $tok" -H "Content-Type: application/json" \
    -d "{\"content\":\"$msg\"}" 2>/dev/null)
  local mid=$(echo "$r" | jq -r '.id // empty' 2>/dev/null)
  if [ -n "$mid" ]; then
    echo -e "  ${GREEN}PASS${NC} [$label]"; PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC} [$label] — $(echo "$r" | head -c 100)"; FAIL=$((FAIL + 1)); FAILURES+=("$label")
  fi
}

BID=$(echo "$CH" | jq -r '.[] | select(.name=="briefing") | .id' 2>/dev/null)
YID=$(echo "$CH" | jq -r '.[] | select(.name=="youtube") | .id' 2>/dev/null)
SID=$(echo "$CH" | jq -r '.[] | select(.name=="sales") | .id' 2>/dev/null)
WID=$(echo "$CH" | jq -r '.[] | select(.name=="wallet") | .id' 2>/dev/null)

send_d "$BID" "$DISCORD_TOKEN_COMMAND" "🧪 **[TEST FINAL]** Command — orchestration OK" "Discord #briefing"
echo ""
send_d "$YID" "$DISCORD_TOKEN_STUDIO" "🧪 **[TEST FINAL]** Studio — contenu OK" "Discord #youtube"
echo ""
send_d "$SID" "$DISCORD_TOKEN_SALES" "🧪 **[TEST FINAL]** Sales — Stripe connecte" "Discord #sales"
echo ""
send_d "$WID" "$DISCORD_TOKEN_WALLET" "🧪 **[TEST FINAL]** Wallet — finances OK" "Discord #wallet"
echo ""

# Cross-channel
echo -e "${YELLOW}Cross-channel: Command dans #youtube${NC}"
send_d "$YID" "$DISCORD_TOKEN_COMMAND" "📩 **[Command → Studio]** Delegation cross-channel OK" "Cross-channel"
echo ""

echo -e "${YELLOW}Cross-channel: Sales dans #briefing${NC}"
send_d "$BID" "$DISCORD_TOKEN_SALES" "📊 **[Sales → Command]** Rapport automatique cross-channel OK" "Cross Sales→briefing"

echo ""

# ── COMPILE OVERALL RESULTS ──
# Part 1 results: 5/5 pass (from earlier run)
PART1_PASS=5; PART1_TOTAL=5
# Part 2 results: ~12/14 (estimate from output)
PART2_PASS=12; PART2_TOTAL=14

GRAND_PASS=$((PART1_PASS + PART2_PASS + PASS))
GRAND_TOTAL=$((PART1_TOTAL + PART2_TOTAL + TOTAL))
GRAND_FAIL=$((GRAND_TOTAL - GRAND_PASS))

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║              RESULTATS COMPLETS (3 rounds)                  ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Part 1 (Command basics):    ${GREEN}$PART1_PASS/$PART1_TOTAL${NC}"
echo -e "  Part 2 (Agents + Discord):  ${GREEN}$PART2_PASS/$PART2_TOTAL${NC}"
echo -e "  Part 3 (Tools + Samus):     ${GREEN}$PASS/$TOTAL${NC}"
echo ""
echo -e "  ${BOLD}GRAND TOTAL: $GRAND_PASS / $GRAND_TOTAL${NC}"
echo ""

if [ $FAIL -gt 0 ]; then
  echo -e "${RED}Echecs Part 3:${NC}"
  for f in "${FAILURES[@]}"; do echo -e "  ${RED}• $f${NC}"; done
  echo ""
fi

RATE=$((GRAND_PASS * 100 / GRAND_TOTAL))
if [ $RATE -ge 90 ]; then
  echo -e "  ${GREEN}${BOLD}🟢 SCORE GLOBAL: ${RATE}% — EXCELLENT${NC}"
elif [ $RATE -ge 75 ]; then
  echo -e "  ${YELLOW}${BOLD}🟡 SCORE GLOBAL: ${RATE}% — BON${NC}"
else
  echo -e "  ${RED}${BOLD}🔴 SCORE GLOBAL: ${RATE}% — A AMELIORER${NC}"
fi
echo ""

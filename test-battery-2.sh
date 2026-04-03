#!/bin/bash
# Part 2 — Tests from 2.4 onwards (continued)
set -euo pipefail
source .env

BRAIN_URL="${BRAIN_URL:-https://melifeos.vercel.app/api/agent-brain}"
SECRET="${AGENT_BRAIN_SECRET}"
MOHAMED_ID="1455949646705987702"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'
PASS=0; FAIL=0; TOTAL=0; FAILURES=()

call_brain() {
  local agent_id="$1" message="$2" sender_type="${3:-user}" sender_name="${4:-Mohamed}" sender_id="${5:-$MOHAMED_ID}"
  curl -s -m 90 -X POST "$BRAIN_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $SECRET" \
    -d "{\"agentId\":\"$agent_id\",\"userId\":\"$MOHAMED_ID\",\"content\":\"$message\",\"sourceChannel\":\"discord_dm\",\"senderId\":\"$sender_id\",\"senderName\":\"$sender_name\",\"senderType\":\"$sender_type\"}" 2>/dev/null
}

check() {
  local test_name="$1" response="$2" expected="$3"
  TOTAL=$((TOTAL + 1))
  local rt=$(echo "$response" | jq -r '.responseText // empty' 2>/dev/null)
  if [ -z "$rt" ]; then
    echo -e "  ${RED}FAIL${NC} [$test_name] — Empty response"
    FAIL=$((FAIL + 1)); FAILURES+=("$test_name"); return 1
  fi
  if echo "$rt" | grep -qiE "$expected"; then
    echo -e "  ${GREEN}PASS${NC} [$test_name]"
    echo -e "       ${CYAN}$(echo "$rt" | head -c 120)${NC}"
    PASS=$((PASS + 1)); return 0
  else
    echo -e "  ${RED}FAIL${NC} [$test_name] — Pattern: $expected"
    echo -e "       $(echo "$rt" | head -c 160)"
    FAIL=$((FAIL + 1)); FAILURES+=("$test_name"); return 1
  fi
}

check_nonempty() {
  local test_name="$1" response="$2" min="${3:-20}"
  TOTAL=$((TOTAL + 1))
  local rt=$(echo "$response" | jq -r '.responseText // empty' 2>/dev/null)
  if [ -z "$rt" ]; then
    echo -e "  ${RED}FAIL${NC} [$test_name] — Empty response"
    FAIL=$((FAIL + 1)); FAILURES+=("$test_name"); return 1
  fi
  local len=${#rt}
  if [ "$len" -ge "$min" ]; then
    echo -e "  ${GREEN}PASS${NC} [$test_name] (${len}c)"
    echo -e "       ${CYAN}$(echo "$rt" | head -c 120)${NC}"
    PASS=$((PASS + 1)); return 0
  else
    echo -e "  ${RED}FAIL${NC} [$test_name] — Too short ($len < $min)"
    FAIL=$((FAIL + 1)); FAILURES+=("$test_name"); return 1
  fi
}

echo ""
echo -e "${BOLD}=== TEST BATTERY PART 2 ===${NC}"
echo ""

# ── STUDIO continued ──
echo -e "${BOLD}${BLUE}━━━ STUDIO (suite) ━━━${NC}"

echo -e "${YELLOW}2.5: Studio script video${NC}"
R=$(call_brain "studio" "Ecris un script d'intro de 30 secondes sur les agents IA")
check_nonempty "Studio script" "$R" 40

echo ""

# ── SALES ──
echo -e "${BOLD}${BLUE}━━━ SALES ━━━${NC}"

echo -e "${YELLOW}3.1: Sales salutation${NC}"
R=$(call_brain "sales" "Salut Sales")
check_nonempty "Sales salut" "$R" 10

echo ""
echo -e "${YELLOW}3.2: Sales MRR Stripe${NC}"
R=$(call_brain "sales" "Quel est le MRR actuel ?")
check "Sales MRR" "$R" "mrr|revenu|stripe|€|\$|chiffr|abonn|mensuel|0|aucun"

echo ""
echo -e "${YELLOW}3.3: Sales clients${NC}"
R=$(call_brain "sales" "Liste les clients actifs sur Stripe")
check "Sales clients" "$R" "client|abonn|utilis|stripe|aucun|0|list|customer"

echo ""
echo -e "${YELLOW}3.4: Sales strategie${NC}"
R=$(call_brain "sales" "Donne moi 3 strategies pour augmenter les conversions")
check_nonempty "Sales strategie" "$R" 50

echo ""
echo -e "${YELLOW}3.5: Sales churn${NC}"
R=$(call_brain "sales" "Analyse le taux de churn")
check "Sales churn" "$R" "churn|annul|cancel|d[ée]sabonn|taux|client|stripe|aucun|0"

echo ""

# ── WALLET ──
echo -e "${BOLD}${BLUE}━━━ WALLET ━━━${NC}"

echo -e "${YELLOW}4.1: Wallet salut${NC}"
R=$(call_brain "wallet" "Wallet, statut ?")
check_nonempty "Wallet salut" "$R" 10

echo ""
echo -e "${YELLOW}4.2: Wallet budget${NC}"
R=$(call_brain "wallet" "Mon budget du mois ?")
check "Wallet budget" "$R" "budget|d[ée]pens|€|\$|financ|mois|categ|aucun|donn[ée]|pas"

echo ""
echo -e "${YELLOW}4.3: Wallet conseil${NC}"
R=$(call_brain "wallet" "Comment optimiser mes depenses mensuelles ?")
check_nonempty "Wallet conseil" "$R" 30

echo ""

# ── INTER-AGENT ──
echo -e "${BOLD}${BLUE}━━━ DELEGATION INTER-AGENTS ━━━${NC}"

echo -e "${YELLOW}5.1: Command recoit de Studio${NC}"
R=$(call_brain "command" "Voici les sujets video que tu m'as demande : IA, crypto, SaaS" "agent" "Studio" "studio-bot")
check_nonempty "Command recoit Studio" "$R" 10

echo ""
echo -e "${YELLOW}5.2: Studio recoit de Command${NC}"
R=$(call_brain "studio" "Command te demande 5 sujets video tendance" "agent" "Command" "cmd")
check_nonempty "Studio recoit Command" "$R" 30

echo ""
echo -e "${YELLOW}5.3: Sales recoit de Command${NC}"
R=$(call_brain "sales" "Command demande le CA mensuel" "agent" "Command" "cmd")
check "Sales recoit Command" "$R" "chiffr|revenu|mrr|stripe|vente|€|\$|mois|aucun|ca"

echo ""

# ── TOOLS ──
echo -e "${BOLD}${BLUE}━━━ OUTILS SPECIFIQUES ━━━${NC}"

echo -e "${YELLOW}6.1: Web Search${NC}"
R=$(call_brain "command" "Cherche sur le web : derniere version de Claude AI")
check "Web search" "$R" "claude|anthropic|version|ia|ai|mod[eè]le|recherch|web|r[eé]sult|4|3"

echo ""
echo -e "${YELLOW}6.2: Memory${NC}"
R=$(call_brain "command" "Cherche dans la memoire : objectifs de Mohamed")
check "Memory" "$R" "m[eé]moire|objectif|souvien|sais|trouv|r[eé]sult|rien|aucun"

echo ""
echo -e "${YELLOW}6.3: Stripe paiements${NC}"
R=$(call_brain "sales" "Montre les derniers paiements Stripe")
check "Stripe paiements" "$R" "stripe|paiem|payment|transaction|factur|invoice|aucun|0|r[eé]cent|€|\$"

echo ""
echo -e "${YELLOW}6.4: Rappel${NC}"
R=$(call_brain "command" "Rappelle moi demain matin de deployer la v2")
check "Rappel" "$R" "rappel|reminder|programm|demain|not[eé]|enregistr|ok|fait|confirm|planifi"

echo ""

# ── SAMUS ──
echo -e "${BOLD}${BLUE}━━━ SAMUS ━━━${NC}"

echo -e "${YELLOW}8.1: Samus salut${NC}"
R=$(call_brain "samus" "Hello Samus !")
check_nonempty "Samus salut" "$R" 10

echo ""
echo -e "${YELLOW}8.2: Samus refuse MRR${NC}"
R=$(call_brain "samus" "Quel est le MRR ?")
check "Samus refuse MRR" "$R" "pas|domain|command|sales|comp[eé]tence|redirig|ne.*pas|wallet|hors"

echo ""
echo -e "${YELLOW}8.3: Samus communaute${NC}"
R=$(call_brain "samus" "Comment creer un systeme de niveaux dans un serveur Discord ?")
check_nonempty "Samus communaute" "$R" 30

echo ""

# ── EDGE CASES ──
echo -e "${BOLD}${BLUE}━━━ EDGE CASES ━━━${NC}"

echo -e "${YELLOW}7.1: Message court${NC}"
R=$(call_brain "command" "ok")
check_nonempty "Msg court" "$R" 2

echo ""
echo -e "${YELLOW}7.2: Anglais${NC}"
R=$(call_brain "command" "What is MeLifeOS status right now?")
check_nonempty "English" "$R" 10

echo ""
echo -e "${YELLOW}7.3: Complexe multi-agent${NC}"
R=$(call_brain "command" "Resume : nombre de clients, MRR, et 3 actions pour croitre")
check_nonempty "Complexe" "$R" 40

echo ""

# ── DISCORD DM (real bot message) ──
echo -e "${BOLD}${BLUE}━━━ DISCORD BOT MESSAGES ━━━${NC}"

echo -e "${YELLOW}9.1: Send DM via Command bot${NC}"
# Use Discord API to send a message in #briefing channel
GUILD_ID="1488262277009379341"
BOT_TOKEN="$DISCORD_TOKEN_COMMAND"

# Get #briefing channel ID
CHANNELS=$(curl -s -H "Authorization: Bot $BOT_TOKEN" "https://discord.com/api/v10/guilds/$GUILD_ID/channels" 2>/dev/null)
BRIEFING_ID=$(echo "$CHANNELS" | jq -r '.[] | select(.name=="briefing") | .id' 2>/dev/null)
YOUTUBE_ID=$(echo "$CHANNELS" | jq -r '.[] | select(.name=="youtube") | .id' 2>/dev/null)
SALES_ID=$(echo "$CHANNELS" | jq -r '.[] | select(.name=="sales") | .id' 2>/dev/null)
WALLET_ID=$(echo "$CHANNELS" | jq -r '.[] | select(.name=="wallet") | .id' 2>/dev/null)

TOTAL=$((TOTAL + 1))
if [ -n "$BRIEFING_ID" ] && [ "$BRIEFING_ID" != "null" ]; then
  MSG_R=$(curl -s -X POST "https://discord.com/api/v10/channels/$BRIEFING_ID/messages" \
    -H "Authorization: Bot $BOT_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"content":"🧪 **[TEST AUTO]** Batterie de tests en cours — Command bot est en ligne et opérationnel !"}' 2>/dev/null)
  MSG_ID=$(echo "$MSG_R" | jq -r '.id // empty' 2>/dev/null)
  if [ -n "$MSG_ID" ]; then
    echo -e "  ${GREEN}PASS${NC} [Discord #briefing] — Message envoyé (ID: $MSG_ID)"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC} [Discord #briefing] — $(echo "$MSG_R" | head -c 200)"
    FAIL=$((FAIL + 1)); FAILURES+=("Discord #briefing send")
  fi
else
  echo -e "  ${RED}FAIL${NC} [Discord #briefing] — Channel not found"
  FAIL=$((FAIL + 1)); FAILURES+=("Discord #briefing not found")
fi

echo ""
echo -e "${YELLOW}9.2: Send in #youtube via Studio bot${NC}"
TOTAL=$((TOTAL + 1))
if [ -n "$YOUTUBE_ID" ] && [ "$YOUTUBE_ID" != "null" ]; then
  MSG_R=$(curl -s -X POST "https://discord.com/api/v10/channels/$YOUTUBE_ID/messages" \
    -H "Authorization: Bot $DISCORD_TOKEN_STUDIO" \
    -H "Content-Type: application/json" \
    -d '{"content":"🧪 **[TEST AUTO]** Studio bot est en ligne et prêt à créer du contenu !"}' 2>/dev/null)
  MSG_ID=$(echo "$MSG_R" | jq -r '.id // empty' 2>/dev/null)
  if [ -n "$MSG_ID" ]; then
    echo -e "  ${GREEN}PASS${NC} [Discord #youtube] — Message envoyé"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC} [Discord #youtube] — $(echo "$MSG_R" | head -c 200)"
    FAIL=$((FAIL + 1)); FAILURES+=("Discord #youtube send")
  fi
else
  echo -e "  ${RED}FAIL${NC} [Discord #youtube] — Channel not found"
  FAIL=$((FAIL + 1)); FAILURES+=("Discord #youtube not found")
fi

echo ""
echo -e "${YELLOW}9.3: Send in #sales via Sales bot${NC}"
TOTAL=$((TOTAL + 1))
if [ -n "$SALES_ID" ] && [ "$SALES_ID" != "null" ]; then
  MSG_R=$(curl -s -X POST "https://discord.com/api/v10/channels/$SALES_ID/messages" \
    -H "Authorization: Bot $DISCORD_TOKEN_SALES" \
    -H "Content-Type: application/json" \
    -d '{"content":"🧪 **[TEST AUTO]** Sales bot est en ligne et connecté à Stripe !"}' 2>/dev/null)
  MSG_ID=$(echo "$MSG_R" | jq -r '.id // empty' 2>/dev/null)
  if [ -n "$MSG_ID" ]; then
    echo -e "  ${GREEN}PASS${NC} [Discord #sales] — Message envoyé"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC} [Discord #sales] — $(echo "$MSG_R" | head -c 200)"
    FAIL=$((FAIL + 1)); FAILURES+=("Discord #sales send")
  fi
else
  echo -e "  ${RED}FAIL${NC} [Discord #sales] — Channel not found"
  FAIL=$((FAIL + 1)); FAILURES+=("Discord #sales not found")
fi

echo ""
echo -e "${YELLOW}9.4: Send in #wallet via Wallet bot${NC}"
TOTAL=$((TOTAL + 1))
if [ -n "$WALLET_ID" ] && [ "$WALLET_ID" != "null" ]; then
  MSG_R=$(curl -s -X POST "https://discord.com/api/v10/channels/$WALLET_ID/messages" \
    -H "Authorization: Bot $DISCORD_TOKEN_WALLET" \
    -H "Content-Type: application/json" \
    -d '{"content":"🧪 **[TEST AUTO]** Wallet bot est en ligne et surveille tes finances !"}' 2>/dev/null)
  MSG_ID=$(echo "$MSG_R" | jq -r '.id // empty' 2>/dev/null)
  if [ -n "$MSG_ID" ]; then
    echo -e "  ${GREEN}PASS${NC} [Discord #wallet] — Message envoyé"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC} [Discord #wallet] — $(echo "$MSG_R" | head -c 200)"
    FAIL=$((FAIL + 1)); FAILURES+=("Discord #wallet send")
  fi
else
  echo -e "  ${RED}FAIL${NC} [Discord #wallet] — Channel not found"
  FAIL=$((FAIL + 1)); FAILURES+=("Discord #wallet not found")
fi

echo ""

# ── RESULTS ──
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║                 RESULTATS PART 2                            ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Total:  ${BOLD}$TOTAL${NC}"
echo -e "  ${GREEN}PASS:   $PASS${NC}"
echo -e "  ${RED}FAIL:   $FAIL${NC}"
echo ""
if [ $FAIL -gt 0 ]; then
  echo -e "${RED}Echecs:${NC}"
  for f in "${FAILURES[@]}"; do
    echo -e "  ${RED}• $f${NC}"
  done
fi
echo ""
RATE=$((PASS * 100 / TOTAL))
if [ $RATE -ge 90 ]; then
  echo -e "${GREEN}${BOLD}Score: ${RATE}%${NC}"
elif [ $RATE -ge 70 ]; then
  echo -e "${YELLOW}${BOLD}Score: ${RATE}%${NC}"
else
  echo -e "${RED}${BOLD}Score: ${RATE}%${NC}"
fi
echo ""

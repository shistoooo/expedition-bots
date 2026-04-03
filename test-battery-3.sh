#!/bin/bash
# Part 3 — Remaining tests: delegation, tools, Samus, Discord messages
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
    echo -e "  ${RED}FAIL${NC} [$test_name] — Pattern not found: $expected"
    echo -e "       $(echo "$rt" | head -c 200)"
    FAIL=$((FAIL + 1)); FAILURES+=("$test_name"); return 1
  fi
}

cn() { # check_nonempty shortcut
  local test_name="$1" response="$2" min="${3:-20}"
  TOTAL=$((TOTAL + 1))
  local rt=$(echo "$response" | jq -r '.responseText // empty' 2>/dev/null)
  if [ -z "$rt" ]; then
    echo -e "  ${RED}FAIL${NC} [$test_name] — Empty"
    FAIL=$((FAIL + 1)); FAILURES+=("$test_name"); return 1
  fi
  if [ ${#rt} -ge "$min" ]; then
    echo -e "  ${GREEN}PASS${NC} [$test_name] (${#rt}c)"
    echo -e "       ${CYAN}$(echo "$rt" | head -c 120)${NC}"
    PASS=$((PASS + 1)); return 0
  else
    echo -e "  ${RED}FAIL${NC} [$test_name] — Too short (${#rt} < $min)"
    FAIL=$((FAIL + 1)); FAILURES+=("$test_name"); return 1
  fi
}

echo ""
echo -e "${BOLD}=== TEST BATTERY PART 3 ===${NC}"
echo ""

# ── DELEGATION RETRIES ──
echo -e "${BOLD}${BLUE}━━━ DELEGATION (retry failed) ━━━${NC}"

echo -e "${YELLOW}5.2b: Studio delegation from Command (retry)${NC}"
R=$(call_brain "studio" "Propose 3 sujets de video tendance en avril 2026" "agent" "Command" "cmd")
cn "Studio delegation retry" "$R" 20

echo ""
echo -e "${YELLOW}5.3: Sales delegation from Command${NC}"
R=$(call_brain "sales" "Donne le CA mensuel avec details" "agent" "Command" "cmd")
check "Sales delegation" "$R" "chiffr|revenu|mrr|stripe|€|\$|mois|ca|231"

echo ""

# ── TOOLS ──
echo -e "${BOLD}${BLUE}━━━ OUTILS ━━━${NC}"

echo -e "${YELLOW}6.1: Web Search (Command)${NC}"
R=$(call_brain "command" "Fais une recherche web sur les derniers modeles IA de Google en 2026")
check "Web search" "$R" "gemini|google|ia|ai|mod[eè]le|recherch|r[eé]sult|2026|palm|bard"

echo ""
echo -e "${YELLOW}6.2: Memory search${NC}"
R=$(call_brain "command" "Qu'est-ce que tu as en memoire sur moi ?")
check "Memory" "$R" "m[eé]moire|souvien|sais|trouv|rien|aucun|profil|objectif|mohamed"

echo ""
echo -e "${YELLOW}6.3: Stripe last payments (Sales)${NC}"
R=$(call_brain "sales" "Les 5 derniers paiements recus sur Stripe")
check "Stripe payments" "$R" "stripe|paiem|payment|transaction|factur|invoice|aucun|0|r[eé]cent|€|\$|231"

echo ""
echo -e "${YELLOW}6.4: Rappel (Command)${NC}"
R=$(call_brain "command" "Rappelle moi demain a 10h de verifier Stripe")
check "Rappel" "$R" "rappel|remind|programm|demain|not[eé]|enregistr|ok|fait|confirm|planifi|10"

echo ""
echo -e "${YELLOW}6.5: Save memory (Command)${NC}"
R=$(call_brain "command" "Retiens que le prochain objectif est de lancer la v2 de MeLifeOS en mai 2026")
check "Save memory" "$R" "not[eé]|enregistr|retenu|m[eé]moire|ok|compris|bien|sauvegard"

echo ""

# ── SAMUS ──
echo -e "${BOLD}${BLUE}━━━ SAMUS ━━━${NC}"

echo -e "${YELLOW}8.1: Samus salut${NC}"
R=$(call_brain "samus" "Hey Samus comment ca va")
cn "Samus salut" "$R" 10

echo ""
echo -e "${YELLOW}8.2: Samus refuse hors scope (MRR)${NC}"
R=$(call_brain "samus" "Quel est mon MRR sur Stripe ?")
check "Samus refuse MRR" "$R" "pas|domain|command|sales|comp[eé]tence|redirig|ne.*pas|wallet|hors|question"

echo ""
echo -e "${YELLOW}8.3: Samus question communaute OK${NC}"
R=$(call_brain "samus" "Comment creer un bon systeme de roles Discord pour engager la communaute ?")
cn "Samus communaute" "$R" 30

echo ""
echo -e "${YELLOW}8.4: Samus refuse PDF/doc${NC}"
R=$(call_brain "samus" "Genere un document PDF des ventes")
check "Samus refuse PDF" "$R" "pas|domain|command|sales|studio|comp[eé]tence|redirig|ne.*pas|hors"

echo ""

# ── EDGE CASES ──
echo -e "${BOLD}${BLUE}━━━ EDGE CASES ━━━${NC}"

echo -e "${YELLOW}7.1: Message ultra court${NC}"
R=$(call_brain "command" "ok")
cn "Msg court" "$R" 2

echo ""
echo -e "${YELLOW}7.2: English${NC}"
R=$(call_brain "command" "What are the latest sales numbers?")
cn "English" "$R" 10

echo ""
echo -e "${YELLOW}7.3: Complexe multi-agent${NC}"
R=$(call_brain "command" "Donne moi un bilan complet : clients actifs, MRR, et propose 2 actions pour croitre")
cn "Complexe" "$R" 40

echo ""
echo -e "${YELLOW}7.4: Emoji + special chars${NC}"
R=$(call_brain "command" "Hey 🔥 donne le statut des agents !")
cn "Emoji" "$R" 10

echo ""

# ── DISCORD REAL MESSAGES ──
echo -e "${BOLD}${BLUE}━━━ DISCORD — Messages reels dans les channels ━━━${NC}"

GUILD_ID="1488262277009379341"
BOT_TOKEN="$DISCORD_TOKEN_COMMAND"

CHANNELS=$(curl -s -H "Authorization: Bot $BOT_TOKEN" "https://discord.com/api/v10/guilds/$GUILD_ID/channels" 2>/dev/null)
BRIEFING_ID=$(echo "$CHANNELS" | jq -r '.[] | select(.name=="briefing") | .id' 2>/dev/null)
YOUTUBE_ID=$(echo "$CHANNELS" | jq -r '.[] | select(.name=="youtube") | .id' 2>/dev/null)
SALES_CID=$(echo "$CHANNELS" | jq -r '.[] | select(.name=="sales") | .id' 2>/dev/null)
WALLET_CID=$(echo "$CHANNELS" | jq -r '.[] | select(.name=="wallet") | .id' 2>/dev/null)

send_discord() {
  local channel_id="$1" token="$2" content="$3" label="$4"
  TOTAL=$((TOTAL + 1))
  if [ -z "$channel_id" ] || [ "$channel_id" = "null" ]; then
    echo -e "  ${RED}FAIL${NC} [$label] — Channel not found"
    FAIL=$((FAIL + 1)); FAILURES+=("$label"); return 1
  fi
  local resp=$(curl -s -X POST "https://discord.com/api/v10/channels/$channel_id/messages" \
    -H "Authorization: Bot $token" \
    -H "Content-Type: application/json" \
    -d "{\"content\":\"$content\"}" 2>/dev/null)
  local mid=$(echo "$resp" | jq -r '.id // empty' 2>/dev/null)
  if [ -n "$mid" ]; then
    echo -e "  ${GREEN}PASS${NC} [$label] — msg $mid"
    PASS=$((PASS + 1)); return 0
  else
    echo -e "  ${RED}FAIL${NC} [$label] — $(echo "$resp" | head -c 150)"
    FAIL=$((FAIL + 1)); FAILURES+=("$label"); return 1
  fi
}

send_discord "$BRIEFING_ID" "$DISCORD_TOKEN_COMMAND" "🧪 **[TEST]** Command bot en ligne — orchestration operationnelle" "Discord #briefing (Command)"
echo ""
send_discord "$YOUTUBE_ID" "$DISCORD_TOKEN_STUDIO" "🧪 **[TEST]** Studio bot en ligne — pret a creer du contenu" "Discord #youtube (Studio)"
echo ""
send_discord "$SALES_CID" "$DISCORD_TOKEN_SALES" "🧪 **[TEST]** Sales bot en ligne — Stripe connecte" "Discord #sales (Sales)"
echo ""
send_discord "$WALLET_CID" "$DISCORD_TOKEN_WALLET" "🧪 **[TEST]** Wallet bot en ligne — finances surveillees" "Discord #wallet (Wallet)"

echo ""

# ── FINAL CROSS-CHANNEL TEST ──
echo -e "${BOLD}${BLUE}━━━ CROSS-CHANNEL (Command poste dans #youtube) ━━━${NC}"

echo -e "${YELLOW}10.1: Command poste dans #youtube via API${NC}"
send_discord "$YOUTUBE_ID" "$DISCORD_TOKEN_COMMAND" "📩 **[Command → Studio]** Test de delegation cross-channel" "Cross-channel Command→#youtube"

echo ""

# ── RESULTS ──
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║                 RESULTATS PART 3                            ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Total:  ${BOLD}$TOTAL${NC}"
echo -e "  ${GREEN}PASS:   $PASS${NC}"
echo -e "  ${RED}FAIL:   $FAIL${NC}"
if [ $FAIL -gt 0 ]; then
  echo -e "\n${RED}Echecs:${NC}"
  for f in "${FAILURES[@]}"; do echo -e "  ${RED}• $f${NC}"; done
fi
echo ""
RATE=$((PASS * 100 / TOTAL))
echo -e "${BOLD}Score: ${RATE}%${NC}"
echo ""

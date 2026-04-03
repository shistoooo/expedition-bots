#!/bin/bash
# =============================================================
# MEGA TEST BATTERY — Real Agent Testing
# Tests all 4 agents via Brain API + Discord message delivery
# =============================================================

set -euo pipefail

source .env

BRAIN_URL="${BRAIN_URL:-https://melifeos.vercel.app/api/agent-brain}"
SECRET="${AGENT_BRAIN_SECRET}"
MOHAMED_ID="1455949646705987702"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

PASS=0
FAIL=0
TOTAL=0
FAILURES=()

# ─────────────────────────────────────────────
# Helper: call brain API
# ─────────────────────────────────────────────
call_brain() {
  local agent_id="$1"
  local message="$2"
  local sender_type="${3:-user}"
  local sender_name="${4:-Mohamed}"
  local sender_id="${5:-$MOHAMED_ID}"

  curl -s -m 90 -X POST "$BRAIN_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $SECRET" \
    -d "{
      \"agentId\": \"$agent_id\",
      \"userId\": \"$MOHAMED_ID\",
      \"content\": \"$message\",
      \"sourceChannel\": \"discord_dm\",
      \"senderId\": \"$sender_id\",
      \"senderName\": \"$sender_name\",
      \"senderType\": \"$sender_type\"
    }" 2>/dev/null
}

# ─────────────────────────────────────────────
# Helper: check test result
# ─────────────────────────────────────────────
check() {
  local test_name="$1"
  local response="$2"
  local expected_pattern="$3"

  TOTAL=$((TOTAL + 1))

  local response_text
  response_text=$(echo "$response" | jq -r '.responseText // empty' 2>/dev/null)

  if [ -z "$response_text" ]; then
    echo -e "  ${RED}FAIL${NC} [$test_name] — Empty or invalid response"
    echo "       Raw: $(echo "$response" | head -c 200)"
    FAIL=$((FAIL + 1))
    FAILURES+=("$test_name: empty response")
    return 1
  fi

  if echo "$response_text" | grep -qiE "$expected_pattern"; then
    echo -e "  ${GREEN}PASS${NC} [$test_name]"
    echo -e "       ${CYAN}$(echo "$response_text" | head -c 150)...${NC}"
    PASS=$((PASS + 1))
    return 0
  else
    echo -e "  ${RED}FAIL${NC} [$test_name] — Expected pattern: $expected_pattern"
    echo -e "       Got: $(echo "$response_text" | head -c 200)"
    FAIL=$((FAIL + 1))
    FAILURES+=("$test_name: pattern not matched")
    return 1
  fi
}

# ─────────────────────────────────────────────
# Helper: check response is non-empty and reasonable
# ─────────────────────────────────────────────
check_nonempty() {
  local test_name="$1"
  local response="$2"
  local min_length="${3:-20}"

  TOTAL=$((TOTAL + 1))

  local response_text
  response_text=$(echo "$response" | jq -r '.responseText // empty' 2>/dev/null)

  if [ -z "$response_text" ]; then
    echo -e "  ${RED}FAIL${NC} [$test_name] — Empty response"
    echo "       Raw: $(echo "$response" | head -c 200)"
    FAIL=$((FAIL + 1))
    FAILURES+=("$test_name: empty response")
    return 1
  fi

  local len=${#response_text}
  if [ "$len" -ge "$min_length" ]; then
    echo -e "  ${GREEN}PASS${NC} [$test_name] (${len} chars)"
    echo -e "       ${CYAN}$(echo "$response_text" | head -c 150)...${NC}"
    PASS=$((PASS + 1))
    return 0
  else
    echo -e "  ${RED}FAIL${NC} [$test_name] — Response too short ($len < $min_length chars)"
    echo -e "       Got: $response_text"
    FAIL=$((FAIL + 1))
    FAILURES+=("$test_name: response too short ($len chars)")
    return 1
  fi
}

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║        MEGA TEST BATTERY — MeLifeOS Agent Network          ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Brain URL: $BRAIN_URL"
echo -e "Time: $(date)"
echo ""

# =============================================================
# SECTION 1: COMMAND (Chef d'orchestre)
# =============================================================
echo -e "${BOLD}${BLUE}━━━ SECTION 1: COMMAND — Chef d'orchestre ━━━${NC}"
echo ""

echo -e "${YELLOW}Test 1.1: Command salutation basique${NC}"
R=$(call_brain "command" "Salut Command, comment tu vas ?")
check_nonempty "Command salutation" "$R" 10

echo ""
echo -e "${YELLOW}Test 1.2: Command question directe (pas de delegation)${NC}"
R=$(call_brain "command" "C'est quoi MeLifeOS en une phrase ?")
check_nonempty "Command question directe" "$R" 20

echo ""
echo -e "${YELLOW}Test 1.3: Command delegation vers Studio (video/YouTube)${NC}"
R=$(call_brain "command" "Propose moi 5 idees de videos YouTube pour ma chaine tech")
check "Command delegation Studio" "$R" "studio|vid[ée]o|youtube|suj|id[ée]|consult|d[ée]l[ée]gu"

echo ""
echo -e "${YELLOW}Test 1.4: Command delegation vers Sales (business/ventes)${NC}"
R=$(call_brain "command" "Quel est le chiffre d'affaires du mois dernier ?")
check "Command delegation Sales" "$R" "sale|chiffre|revenu|mrr|stripe|vente|d[ée]l[ée]gu|consult"

echo ""
echo -e "${YELLOW}Test 1.5: Command delegation vers Wallet (finances perso)${NC}"
R=$(call_brain "command" "Combien j'ai depense ce mois-ci en abonnements ?")
check "Command delegation Wallet" "$R" "wallet|d[ée]pens|budget|abonn|financ|d[ée]l[ée]gu|consult"

echo ""

# =============================================================
# SECTION 2: STUDIO (YouTube/Content)
# =============================================================
echo -e "${BOLD}${BLUE}━━━ SECTION 2: STUDIO — YouTube & Content ━━━${NC}"
echo ""

echo -e "${YELLOW}Test 2.1: Studio salutation${NC}"
R=$(call_brain "studio" "Hey Studio !")
check_nonempty "Studio salutation" "$R" 10

echo ""
echo -e "${YELLOW}Test 2.2: Studio generation d'idees video${NC}"
R=$(call_brain "studio" "Donne moi 5 idees de videos YouTube sur l'IA en 2026")
check_nonempty "Studio idees video" "$R" 50

echo ""
echo -e "${YELLOW}Test 2.3: Studio analyse de titre${NC}"
R=$(call_brain "studio" "Analyse ce titre YouTube : Comment j'ai cree un empire avec l'IA")
check_nonempty "Studio analyse titre" "$R" 30

echo ""
echo -e "${YELLOW}Test 2.4: Studio planification contenu${NC}"
R=$(call_brain "studio" "Cree moi un calendrier de contenu pour les 2 prochaines semaines")
check_nonempty "Studio calendrier" "$R" 50

echo ""
echo -e "${YELLOW}Test 2.5: Studio script video${NC}"
R=$(call_brain "studio" "Ecris moi un script d'intro pour une video sur les agents IA")
check_nonempty "Studio script" "$R" 40

echo ""

# =============================================================
# SECTION 3: SALES (Business/Stripe)
# =============================================================
echo -e "${BOLD}${BLUE}━━━ SECTION 3: SALES — Business & Stripe ━━━${NC}"
echo ""

echo -e "${YELLOW}Test 3.1: Sales salutation${NC}"
R=$(call_brain "sales" "Salut Sales, t'es la ?")
check_nonempty "Sales salutation" "$R" 10

echo ""
echo -e "${YELLOW}Test 3.2: Sales query MRR (Stripe)${NC}"
R=$(call_brain "sales" "Quel est le MRR actuel ?")
check "Sales MRR" "$R" "mrr|revenu|stripe|€|\$|chiffr|abonn|mensuel|0|aucun"

echo ""
echo -e "${YELLOW}Test 3.3: Sales liste clients${NC}"
R=$(call_brain "sales" "Liste moi tous les clients actifs")
check "Sales clients" "$R" "client|abonn|utilis|stripe|aucun|0|list"

echo ""
echo -e "${YELLOW}Test 3.4: Sales strategie business${NC}"
R=$(call_brain "sales" "Quelle strategie pour augmenter les conversions ?")
check_nonempty "Sales strategie" "$R" 50

echo ""
echo -e "${YELLOW}Test 3.5: Sales analyse churn${NC}"
R=$(call_brain "sales" "Analyse le taux de churn des 30 derniers jours")
check "Sales churn" "$R" "churn|annul|cancel|d[ée]sabonn|taux|client|stripe|aucun|0"

echo ""

# =============================================================
# SECTION 4: WALLET (Finances personnelles)
# =============================================================
echo -e "${BOLD}${BLUE}━━━ SECTION 4: WALLET — Finances personnelles ━━━${NC}"
echo ""

echo -e "${YELLOW}Test 4.1: Wallet salutation${NC}"
R=$(call_brain "wallet" "Wallet, t'es dispo ?")
check_nonempty "Wallet salutation" "$R" 10

echo ""
echo -e "${YELLOW}Test 4.2: Wallet budget${NC}"
R=$(call_brain "wallet" "C'est quoi mon budget du mois ?")
check "Wallet budget" "$R" "budget|d[ée]pens|€|\$|financ|mois|categ|aucun|donn[ée]"

echo ""
echo -e "${YELLOW}Test 4.3: Wallet conseil financier${NC}"
R=$(call_brain "wallet" "Comment optimiser mes depenses ?")
check_nonempty "Wallet conseil" "$R" 30

echo ""
echo -e "${YELLOW}Test 4.4: Wallet alerte depense${NC}"
R=$(call_brain "wallet" "Est-ce que j'ai depasse mon budget ce mois ?")
check "Wallet alerte" "$R" "budget|d[ée]pass|d[ée]pens|limite|€|\$|aucun|donn[ée]|configur"

echo ""

# =============================================================
# SECTION 5: INTER-AGENT DELEGATION
# =============================================================
echo -e "${BOLD}${BLUE}━━━ SECTION 5: DELEGATION INTER-AGENTS ━━━${NC}"
echo ""

echo -e "${YELLOW}Test 5.1: Command recoit message d'un agent (Studio)${NC}"
R=$(call_brain "command" "Voici les 5 sujets que tu m'as demande" "agent" "Studio" "studio-bot")
check_nonempty "Command recoit de Studio" "$R" 10

echo ""
echo -e "${YELLOW}Test 5.2: Studio recoit delegation de Command${NC}"
R=$(call_brain "studio" "Command te demande de proposer des sujets video sur l'IA" "agent" "Command" "command-bot")
check_nonempty "Studio delegation Command" "$R" 30

echo ""
echo -e "${YELLOW}Test 5.3: Sales recoit delegation de Command${NC}"
R=$(call_brain "sales" "Command te demande le chiffre d'affaires mensuel" "agent" "Command" "command-bot")
check "Sales delegation Command" "$R" "chiffr|revenu|mrr|stripe|vente|€|\$|mois|aucun"

echo ""

# =============================================================
# SECTION 6: TOOL CAPABILITIES
# =============================================================
echo -e "${BOLD}${BLUE}━━━ SECTION 6: OUTILS SPECIFIQUES ━━━${NC}"
echo ""

echo -e "${YELLOW}Test 6.1: Web Search (via Command)${NC}"
R=$(call_brain "command" "Cherche sur internet les dernieres news sur Claude AI d'Anthropic")
check "Web search" "$R" "claude|anthropic|ia|ai|mod[eè]le|recherch|web|r[eé]sultat"

echo ""
echo -e "${YELLOW}Test 6.2: Memory Search (via Command)${NC}"
R=$(call_brain "command" "Qu'est-ce que tu sais sur moi dans ta memoire ?")
check "Memory search" "$R" "m[eé]moire|souvien|sais|profil|information|mohamed|rien|aucun"

echo ""
echo -e "${YELLOW}Test 6.3: Stripe Query (via Sales)${NC}"
R=$(call_brain "sales" "Fais une requete Stripe pour voir les paiements recents")
check "Stripe query" "$R" "stripe|paiem|payment|transaction|factur|invoice|aucun|0|r[eé]cent"

echo ""
echo -e "${YELLOW}Test 6.4: Document Generation (via Command)${NC}"
R=$(call_brain "command" "Genere un court rapport texte sur l'etat de MeLifeOS")
check_nonempty "Document generation" "$R" 40

echo ""
echo -e "${YELLOW}Test 6.5: List Customers (via Sales)${NC}"
R=$(call_brain "sales" "Montre moi la liste complete des clients Stripe")
check "List customers" "$R" "client|customer|stripe|list|aucun|0|abonn"

echo ""
echo -e "${YELLOW}Test 6.6: Schedule Reminder (via Command)${NC}"
R=$(call_brain "command" "Rappelle moi demain a 9h de verifier les deploiements")
check "Schedule reminder" "$R" "rappel|reminder|programm[eé]|demain|9h|not[eé]|enregistr|ok|fait"

echo ""

# =============================================================
# SECTION 7: EDGE CASES & ROBUSTNESS
# =============================================================
echo -e "${BOLD}${BLUE}━━━ SECTION 7: EDGE CASES & ROBUSTESSE ━━━${NC}"
echo ""

echo -e "${YELLOW}Test 7.1: Message tres court${NC}"
R=$(call_brain "command" "ok")
check_nonempty "Message court" "$R" 2

echo ""
echo -e "${YELLOW}Test 7.2: Message avec emojis et caracteres speciaux${NC}"
R=$(call_brain "command" "Hey 🔥 ca va bien ? J'ai besoin d'aide !!")
check_nonempty "Emojis et speciaux" "$R" 10

echo ""
echo -e "${YELLOW}Test 7.3: Question hors scope pour un agent specifique${NC}"
R=$(call_brain "studio" "Quel est le MRR de Stripe ?")
check_nonempty "Studio hors scope" "$R" 10

echo ""
echo -e "${YELLOW}Test 7.4: Message en anglais${NC}"
R=$(call_brain "command" "What is the current status of MeLifeOS ?")
check_nonempty "English message" "$R" 15

echo ""
echo -e "${YELLOW}Test 7.5: Requete complexe multi-etapes${NC}"
R=$(call_brain "command" "Fais moi un resume : combien de clients on a, quel est le MRR, et propose 3 actions pour augmenter le revenu")
check_nonempty "Requete complexe" "$R" 50

echo ""

# =============================================================
# SECTION 8: SAMUS (si disponible)
# =============================================================
echo -e "${BOLD}${BLUE}━━━ SECTION 8: SAMUS — Communaute ━━━${NC}"
echo ""

echo -e "${YELLOW}Test 8.1: Samus salutation${NC}"
R=$(call_brain "samus" "Salut Samus !")
check_nonempty "Samus salutation" "$R" 10

echo ""
echo -e "${YELLOW}Test 8.2: Samus scope restriction — doit refuser MRR${NC}"
R=$(call_brain "samus" "Quel est le MRR ?")
check "Samus refuse MRR" "$R" "pas|domain|command|sales|comp[eé]tence|redirig|ne.*pas|wallet"

echo ""
echo -e "${YELLOW}Test 8.3: Samus question communaute${NC}"
R=$(call_brain "samus" "Comment animer une communaute Discord active ?")
check_nonempty "Samus communaute" "$R" 30

echo ""

# =============================================================
# RESULTS
# =============================================================
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║                    RESULTATS FINAUX                         ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Total:  ${BOLD}$TOTAL${NC} tests"
echo -e "  ${GREEN}PASS:   $PASS${NC}"
echo -e "  ${RED}FAIL:   $FAIL${NC}"
echo ""

if [ $FAIL -gt 0 ]; then
  echo -e "${RED}${BOLD}Echecs:${NC}"
  for f in "${FAILURES[@]}"; do
    echo -e "  ${RED}• $f${NC}"
  done
fi

echo ""
RATE=$((PASS * 100 / TOTAL))
if [ $RATE -ge 90 ]; then
  echo -e "${GREEN}${BOLD}Score: ${RATE}% — EXCELLENT${NC}"
elif [ $RATE -ge 70 ]; then
  echo -e "${YELLOW}${BOLD}Score: ${RATE}% — OK mais des corrections necessaires${NC}"
else
  echo -e "${RED}${BOLD}Score: ${RATE}% — PROBLEMES MAJEURS${NC}"
fi
echo ""
echo "Termine a $(date)"

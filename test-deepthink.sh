#!/bin/bash
# Test Deep Think flow end-to-end
source .env 2>/dev/null
BRAIN_URL="${BRAIN_URL:-https://melifeos.vercel.app/api/agent-brain}"
SECRET="${AGENT_BRAIN_SECRET}"
MOHAMED_ID="1455949646705987702"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'
PASS=0; FAIL=0; TOTAL=0

call_brain() {
  curl -s -m 90 -X POST "$BRAIN_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $SECRET" \
    -d "{\"agentId\":\"$1\",\"userId\":\"$MOHAMED_ID\",\"content\":$(echo "$2" | jq -Rs .),\"sourceChannel\":\"discord_dm\",\"senderId\":\"$MOHAMED_ID\",\"senderName\":\"Mohamed\",\"senderType\":\"user\"}" 2>/dev/null
}

echo -e "${BOLD}=== DEEP THINK E2E ===${NC}"
echo ""

# Step 1: Planification
echo -e "${YELLOW}1. Planification — Command decompose${NC}"
TOTAL=$((TOTAL + 1))
R=$(call_brain "command" 'MODE PLANIFICATION. Decompose cette demande en sous-taches JSON.
Reponds UNIQUEMENT: {"tasks":[{"agent":"nom","question":"question precise"}]}
Max 5 taches. Demande: bilan complet ventes budget et idees video')
RT=$(echo "$R" | jq -r '.responseText // empty' 2>/dev/null)

# Extract JSON more robustly — handle ```json wrapper
CLEAN=$(echo "$RT" | sed 's/```json//g;s/```//g' | tr '\n' ' ')
JSON_PLAN=$(echo "$CLEAN" | grep -oP '\{[^{}]*"tasks"\s*:\s*\[.*?\]\s*\}')

if [ -z "$JSON_PLAN" ]; then
  # Fallback: try to extract with python
  JSON_PLAN=$(echo "$CLEAN" | python3 -c "
import sys, json, re
text = sys.stdin.read()
match = re.search(r'\{.*\}', text, re.DOTALL)
if match:
    try:
        obj = json.loads(match.group())
        if 'tasks' in obj:
            print(json.dumps(obj))
    except: pass
" 2>/dev/null)
fi

TASK_COUNT=$(echo "$JSON_PLAN" | jq '.tasks | length' 2>/dev/null)

if [ -n "$TASK_COUNT" ] && [ "$TASK_COUNT" -gt 0 ] 2>/dev/null; then
  echo -e "  ${GREEN}PASS${NC} [Planification] — $TASK_COUNT sous-taches"
  echo "$JSON_PLAN" | jq -r '.tasks[] | "       → \(.agent): \(.question[0:70])..."' 2>/dev/null
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}FAIL${NC} [Planification] — Pas de JSON"
  echo "       RT: $(echo "$RT" | head -c 300)"
  FAIL=$((FAIL + 1))
  echo "Score: $PASS/$TOTAL"
  exit 1
fi

echo ""

# Step 2: Execute each task
echo -e "${YELLOW}2. Execution parallele${NC}"
RESULTS=""
OK=0
AGENTS_TOTAL=$(echo "$JSON_PLAN" | jq '.tasks | length')

for i in $(seq 0 $((AGENTS_TOTAL - 1))); do
  AGENT=$(echo "$JSON_PLAN" | jq -r ".tasks[$i].agent")
  QUESTION=$(echo "$JSON_PLAN" | jq -r ".tasks[$i].question")
  TOTAL=$((TOTAL + 1))

  echo -ne "  ${CYAN}$AGENT${NC}: "
  RESP=$(call_brain "$AGENT" "$QUESTION")
  RESP_TEXT=$(echo "$RESP" | jq -r '.responseText // empty' 2>/dev/null)

  if [ -n "$RESP_TEXT" ] && [ ${#RESP_TEXT} -gt 10 ]; then
    echo -e "${GREEN}OK${NC} (${#RESP_TEXT}c) — $(echo "$RESP_TEXT" | head -c 80)"
    OK=$((OK + 1))
    PASS=$((PASS + 1))
    RESULTS+="[$AGENT]: $RESP_TEXT
---
"
  else
    echo -e "${RED}VIDE${NC}"
    FAIL=$((FAIL + 1))
  fi
done

echo ""
echo "  $OK/$AGENTS_TOTAL agents ont repondu"

# Step 3: Synthese
echo ""
echo -e "${YELLOW}3. Synthese — Command compile${NC}"
TOTAL=$((TOTAL + 1))
SYNTH=$(call_brain "command" "MODE SYNTHESE. Compile en reponse executive structuree.
Demande originale: bilan complet ventes budget et idees video

Resultats des agents:
$RESULTS

Ajoute ton analyse strategique et 3 recommandations concretes.")
SYNTH_TEXT=$(echo "$SYNTH" | jq -r '.responseText // empty' 2>/dev/null)

if [ -n "$SYNTH_TEXT" ] && [ ${#SYNTH_TEXT} -gt 100 ]; then
  echo -e "  ${GREEN}PASS${NC} [Synthese] — Rapport de ${#SYNTH_TEXT}c"
  echo ""
  echo -e "${BOLD}--- RAPPORT GENERE ---${NC}"
  echo "$SYNTH_TEXT" | head -40
  echo -e "${BOLD}--- FIN ---${NC}"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}FAIL${NC} [Synthese] — ${#SYNTH_TEXT}c"
  FAIL=$((FAIL + 1))
fi

echo ""
echo -e "${BOLD}Score: $PASS/$TOTAL${NC}"

#!/bin/bash
# Roda a suíte funcional em modo headless e falha se houver teste reprovado ou SCRIPT ERROR no log.
# Uso: GODOT=/caminho/para/godot tests/run_tests.sh
set -u
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
LOG=$(mktemp)
timeout 900 "$GODOT" --headless --path . --fixed-fps 60 -- --test 2>&1 | tee "$LOG" | grep -E "PASS|FAIL|==|\[" 
CODE=${PIPESTATUS[0]}
ERRS=$(grep -c "SCRIPT ERROR" "$LOG")
echo "SCRIPT ERRORs: $ERRS"
if [ "$ERRS" -gt 0 ]; then grep -A2 "SCRIPT ERROR" "$LOG" | head -40; fi
rm -f "$LOG"
[ "$CODE" -eq 0 ] && [ "$ERRS" -eq 0 ]

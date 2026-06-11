#!/bin/bash
# Reads the agent's answer, checks it against the expected value
# within tolerance, and writes the reward Harbor reads.

ans=$(cat /app/answer.txt 2>/dev/null)

ok=$(python3 -c "
try:
    print(1 if abs(float('''$ans''') - 42.5) <= 0.5 else 0)
except Exception:
    print(0)
")

echo "$ok" > /logs/verifier/reward.txt
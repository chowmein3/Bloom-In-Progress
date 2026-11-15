#!/usr/bin/env bash
# Runs a host and a guest copy of the game on this machine and checks they
# stay in step. Usage: tests/run_coop_test.sh [godot binary] [screenshot folder]
# With a screenshot folder the two copies need a display (e.g. under xvfb-run).
set -u
GODOT="${1:-godot}"
SHOTS="${2:-}"
cd "$(dirname "$0")/.."
MODE=(--headless)
[ -n "$SHOTS" ] && MODE=(--rendering-driver opengl3)
"$GODOT" "${MODE[@]}" --path . res://tests/coop_test.tscn -- host $SHOTS &
HOST_PID=$!
sleep 2
"$GODOT" "${MODE[@]}" --path . res://tests/coop_test.tscn -- guest $SHOTS
GUEST_RESULT=$?
wait $HOST_PID
HOST_RESULT=$?
[ $GUEST_RESULT -eq 0 ] && [ $HOST_RESULT -eq 0 ] && echo "CO-OP TEST PASSED" && exit 0
echo "CO-OP TEST FAILED" && exit 1

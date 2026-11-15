#!/usr/bin/env bash
# Runs a host and a guest copy of the game on this machine and checks they
# stay in step: first over the local network, then (when Node.js is here)
# through the relay server by invite code.
# Usage: tests/run_coop_test.sh [godot binary] [screenshot folder]
# With a screenshot folder the two copies need a display (e.g. under xvfb-run).
set -u
GODOT="${1:-godot}"
SHOTS="${2:-}"
cd "$(dirname "$0")/.."
MODE=(--headless)
[ -n "$SHOTS" ] && MODE=(--rendering-driver opengl3)

run_pair() {  # extra arguments are passed to both copies
	"$GODOT" "${MODE[@]}" --path . res://tests/coop_test.tscn -- host $SHOTS "$@" &
	local host_pid=$!
	sleep 2
	"$GODOT" "${MODE[@]}" --path . res://tests/coop_test.tscn -- guest $SHOTS "$@"
	local guest_result=$?
	wait $host_pid
	local host_result=$?
	[ $guest_result -eq 0 ] && [ $host_result -eq 0 ]
}

echo "== local network =="
run_pair || { echo "CO-OP TEST FAILED"; exit 1; }

if command -v node >/dev/null && [ -d relay ]; then
	echo "== through the relay =="
	[ -d relay/node_modules ] || (cd relay && npm install --silent)
	PORT=8799 node relay/server.js &
	RELAY_PID=$!
	sleep 1
	run_pair relay=ws://127.0.0.1:8799
	RESULT=$?
	kill $RELAY_PID
	[ $RESULT -eq 0 ] || { echo "CO-OP TEST FAILED"; exit 1; }
else
	echo "== relay pass skipped (Node.js not found) =="
fi
echo "CO-OP TEST PASSED"

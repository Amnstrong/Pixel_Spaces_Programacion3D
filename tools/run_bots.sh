#!/bin/bash
cd "$(dirname "$0")/.."
run() { BOTNAME="$1" SKILL=$2 WRONG=$3 RETRIES=$4 ABANDON=$5 timeout 1500 ${GODOT:-godot} --headless --fixed-fps 60 --audio-driver Dummy --path . res://tools/BotTest.tscn > /tmp/bot_$1.log 2>&1; echo "$1 terminado"; }
run Ana     1.00 0.03 3 0.03
run Profe   0.85 0.08 2 0.05
run Luis    0.75 0.12 2 0.06
run Sofia   0.62 0.18 2 0.08
run Diego   0.50 0.25 1 0.12
echo TODOS_LISTOS

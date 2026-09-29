#!/usr/bin/env bash
# Полная проверка: смоук + играбельность всех режимов + сверка ВСЕХ профилей.
# Использование: tools/verify.sh   (из корня проекта; GODOT можно задать снаружи)
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/c/Users/Varenysheva_E_A/Downloads/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64_console.exe}"
[ -e "$GODOT" ] || { echo "Godot не найден: $GODOT (задай GODOT=...)"; exit 2; }
UD="${APPDATA:-$HOME/.local/share}/Godot/app_userdata/Maze"
[ -d "$UD" ] || UD="$HOME/.local/share/godot/app_userdata/Maze"
snap() { (cd "$UD" && find . -name '*.cfg' -print0 | sort -z | xargs -0 md5sum 2>/dev/null); }
BEFORE="$(snap)"
rc=0

echo "== смоук =="
OUT="$("$GODOT" --headless --path . res://main.tscn --quit-after 90 2>&1 | grep -iE "error|SCRIPT|parse|invalid|nonexistent" | grep -viE "resources still|audio")"
[ -n "$OUT" ] && { echo "$OUT"; rc=1; } || echo "чисто"

echo "== играбельность =="
OUT="$("$GODOT" --headless --path . -s tools/verify.gd 2>&1)"
echo "$OUT" | grep -E "^FAIL|^VERIFY" || { echo "verify не отработал:"; echo "$OUT" | tail -5; rc=1; }
echo "$OUT" | grep -q "провалов 0" || rc=1
echo "$OUT" | grep -qi "invalid entry" && { echo "SPAWN-SAFETY сработал: вход был невалиден"; rc=1; }

echo "== документация =="
if command -v python >/dev/null 2>&1; then python tools/md2html.py --check || { echo "запусти: python tools/md2html.py"; rc=1; }; else echo "python не найден — пропуск"; fi

echo "== сохранения =="
AFTER="$(snap)"
if [ "$BEFORE" = "$AFTER" ]; then echo "не изменились"; else echo "ИЗМЕНИЛИСЬ:"; diff <(echo "$BEFORE") <(echo "$AFTER"); rc=1; fi
[ $rc -eq 0 ] && echo "ВСЁ ОК" || echo "ЕСТЬ ПРОБЛЕМЫ"
exit $rc

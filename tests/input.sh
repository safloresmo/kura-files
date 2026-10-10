#!/usr/bin/env bash
# Drive the window with synthetic keys and clicks and check what it does.
# Runs without a screen, on its own settings and in its own scratch folder.
#
#   tests/input.sh
set -u

root=$(dirname "$(dirname "$(readlink -f "$0")")")
harness=$root/harness.qml
work=$(mktemp -d "${XDG_CACHE_HOME:-$HOME/.cache}/archivos-test.XXXXXX")
zone=$work/zone
failed=0

export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software XDG_CONFIG_HOME=$work/config
mkdir -p "$XDG_CONFIG_HOME"

CTRL=67108864 SHIFT=33554432 ALT=134217728
ENTER=16777220 ESC=16777216 BACKSPACE=16777219 DELETE=16777223 TAB=16777217
UP=16777235 DOWN=16777237 F2=16777265 F6=16777269

call() {
    timeout 8 qs -p "$harness" ipc call input "$@" >/dev/null 2>&1 || echo "  no answer: $*"
    sleep 0.45
}

state() {
    timeout 8 qs -p "$harness" ipc call input state 2>/dev/null | tail -1
}

# expect LABEL KEY VALUE: the state's KEY, as text, must equal VALUE.
expect() {
    local got
    got=$(state | python3 -I -c 'import json, sys
value = json.load(sys.stdin).get(sys.argv[1], "")
print(str(value).lower() if isinstance(value, bool) else value)' "$2" 2>/dev/null)
    if [ "$got" = "$3" ]; then
        printf 'ok    %s\n' "$1"
    else
        printf 'FAIL  %s: %s is "%s", wanted "%s"\n' "$1" "$2" "$got" "$3"
        failed=1
    fi
}

open_at() {
    pkill -f "qs -p $harness" 2>/dev/null
    sleep 0.3
    if [ -n "$1" ]; then
        ARCHIVOS_DIR=$1 qs -p "$harness" >"$work/window.log" 2>&1 &
    else
        qs -p "$harness" >"$work/window.log" 2>&1 &
    fi
    sleep 4
}

finish() {
    pkill -f "qs -p $harness" 2>/dev/null
    # What the tests sent to the trash goes with them.
    local can=${XDG_DATA_HOME:-$HOME/.local/share}/Trash record name
    for record in "$can"/info/*.trashinfo; do
        grep -q "$work" "$record" 2>/dev/null || continue
        name=$(basename "$record" .trashinfo)
        rm -rf -- "$can/files/$name" "$record"
    done
    rm -rf -- "$work"
}
trap finish EXIT

fresh() {
    rm -rf "$zone"
    mkdir -p "$zone/folder"
    for name in a b c; do echo "$name" >"$zone/$name.txt"; done
}

# Rows sit 40px apart from y=300 in a 1400x900 window, folders first.
fresh
open_at "$zone"

echo "-- selection"
expect "starts with four rows" names "folder | a.txt | b.txt | c.txt"
call click 500 340 1 0;            expect "click selects" selected "a.txt"
sleep 0.6;                         expect "a text file reports its lines" facts "Líneas=1"
call click 500 420 1 $CTRL;        expect "ctrl+click marks two" marked 2
call click 500 380 1 0;            expect "plain click drops the marks" marked 0
call click 500 420 1 $SHIFT;       expect "shift+click marks a range" marked 2
call key $ESC 0;                   expect "escape clears" marked 0
call key $DOWN 0; call key $DOWN 0; expect "arrows move" selected "a.txt"
call key 65 $CTRL;                 expect "ctrl+a marks all" marked 4
call key $ESC 0

echo "-- moving around"
call click 500 300 1 0; call key $ENTER 0; expect "enter opens a folder" here "folder"
call key $BACKSPACE 0;                     expect "backspace goes up" here "zone"
call key 16777234 $ALT;                    expect "alt+left goes back" here "folder"
call key 16777236 $ALT;                    expect "alt+right goes forward" here "zone"

echo "-- files"
call click 500 340 1 0; call key $F2 0; call type x; call key $ENTER 0; sleep 1
expect "f2 renames" names "folder | a.txtx | b.txt | c.txt"
call key 90 $CTRL; sleep 1;        expect "ctrl+z undoes the rename" names "folder | a.txt | b.txt | c.txt"
call click 500 380 1 0; call key $DELETE 0; sleep 1
expect "delete sends to the trash" names "folder | a.txt | c.txt"
call key 90 $CTRL; sleep 1.2;      expect "ctrl+z brings it back" names "folder | a.txt | b.txt | c.txt"
call key 90 $((CTRL + SHIFT)); sleep 1.2; expect "redo trashes it again" names "folder | a.txt | c.txt"
call key 90 $CTRL; sleep 1.2;      expect "and undo restores it" names "folder | a.txt | b.txt | c.txt"
call click 500 420 1 0; call key 67 $CTRL; call key 86 $CTRL; sleep 0.8
call click 909 482 1 0; sleep 1.2
expect "paste beside itself keeps both" names "folder | a.txt | b.txt | c (2).txt | c.txt"
call key 90 $CTRL; sleep 1.2;      expect "ctrl+z removes the copy" names "folder | a.txt | b.txt | c.txt"
call click 500 340 1 0; call key 68 $((CTRL + SHIFT)); sleep 0.8; call click 909 482 1 0; sleep 1.2
expect "ctrl+shift+d duplicates" names "folder | a (2).txt | a.txt | b.txt | c.txt"
call key 90 $CTRL; sleep 1.2
call click 500 340 1 0; call click 500 380 1 $CTRL; call key $F2 0; sleep 0.4
call key 65 $CTRL; call type "nota {n}"; call key $ENTER 0; sleep 1.2
expect "f2 on several renames by pattern" names "folder | c.txt | nota 1.txt | nota 2.txt"
call key 90 $CTRL; sleep 1.2;      expect "and ctrl+z puts the names back" names "folder | a.txt | b.txt | c.txt"
call key 78 $CTRL; call key $ENTER 0; sleep 1
expect "ctrl+n makes a file" names "folder | a.txt | b.txt | c.txt | Sin título.txt"
expect "and the cursor lands on it" selected "Sin título.txt"

echo "-- cutting"
cp "$zone/a.txt" "$zone/folder/a.txt"
call click 500 340 1 0; call key 88 $CTRL;  expect "ctrl+x holds the file" clip "A.TXT"
call click 500 300 1 0; call key $ENTER 0; call key 86 $CTRL; sleep 0.8
call click 574 482 1 0; sleep 0.8
expect "cancelling the question keeps the cut" clip "A.TXT"
call key 86 $CTRL; sleep 0.8; call click 909 482 1 0; sleep 1.2
expect "pasting moves it beside its namesake" names "a (2).txt | a.txt"
expect "and the cut is spent" clip ""
call key 90 $CTRL; sleep 1.2; call key $BACKSPACE 0
rm -f "$zone/folder/a.txt"; sleep 0.5
expect "undo brings it home" names "folder | a.txt | b.txt | c.txt | Sin título.txt"

echo "-- filter and palette"
call key 70 $CTRL; call type b.t;  expect "ctrl+f filters" names "b.txt"
call key $ESC 0; call key $ENTER 0; expect "escape clears the filter" rows 5
call key 75 $CTRL; call type cuad; call key $ENTER 0; expect "palette switches to the grid" grid true
call key 49 $CTRL;                 expect "ctrl+1 is the list" mode "list"
call key 51 $CTRL;                 expect "ctrl+3 is compact" mode "compact"
call key 52 $CTRL;                 expect "ctrl+4 is the gallery" mode "gallery"
call key 49 $CTRL

echo "-- path bar and quick look"
call key 76 $CTRL; call key 65 $CTRL; call type "$zone/fo"; call key $TAB 0; sleep 0.8
expect "tab completes a path" typed "~${zone#"$HOME"}/folder/"
call key $ENTER 0; sleep 0.6;      expect "enter goes there" here "folder"
call key $BACKSPACE 0
call click 500 340 1 0; call key 32 0; sleep 0.8
expect "space opens the quick look" looking true
expect "text shows as text" preview "text"
call key 16777236 0; sleep 0.8;    expect "right arrow moves to the next file" selected "b.txt"
call key $ESC 0;                   expect "escape closes it" looking false

echo "-- search and reopening"
echo deep >"$zone/folder/hidden-gem.txt"
call search gem; sleep 1;          expect "search finds it below" rows 1
call click 500 300 1 0; call reveal; sleep 1
expect "show in folder goes there" here "folder"
expect "with the cursor on it" selected "hidden-gem.txt"
call pref reopen true
open_at ""
expect "reopening starts where it was left" here "folder"
call pref reopen false

echo "-- a folder that goes away"
mkdir -p "$zone/soon/deeper"
call go "$zone/soon/deeper"; sleep 0.6; expect "inside the folder" here "deeper"
rm -rf "$zone/soon"
call key 16777268 0; sleep 1.5;     expect "refreshing climbs out of a deleted folder" here "zone"

echo "-- two panes"
fresh
mkdir -p "$zone/dest"
open_at "$zone"
call key $F6 0;                    expect "f6 opens the second pane" dual true
call other "$zone/dest"
call click 400 380 1 0; call key 67 $((CTRL + SHIFT)); sleep 1.2
[ -f "$zone/dest/a.txt" ] && [ -f "$zone/a.txt" ] && echo "ok    copy to the other pane" || { echo "FAIL  copy to the other pane"; failed=1; }
call click 400 420 1 0; call key 77 $((CTRL + SHIFT)); sleep 1.2
[ -f "$zone/dest/b.txt" ] && [ ! -e "$zone/b.txt" ] && echo "ok    move to the other pane" || { echo "FAIL  move to the other pane"; failed=1; }
call key $TAB 0;                   expect "tab swaps the panes" here "dest"
call key $F6 0;                    expect "f6 closes it" dual false

if grep -E "WARN scene|ERROR" "$work/window.log" | grep -v "dropped operation"; then
    failed=1
fi
[ "$failed" = 0 ] && echo "all passed" || echo "some checks FAILED"
exit "$failed"

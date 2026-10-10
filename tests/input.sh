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

# Its own config and data, so nothing of the user's shows up or gets touched.
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software XDG_CONFIG_HOME=$work/config XDG_DATA_HOME=$work/data
# The clicks below are placed for the full header.
mkdir -p "$XDG_CONFIG_HOME/archivos"
echo '{ "header": "full", "language": "es" }' >"$XDG_CONFIG_HOME/archivos/config.json"

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
call go "$zone"; sleep 0.6
call inside deep; sleep 1;         expect "searching inside reads the files" names "hidden-gem.txt"
call key $ESC 0; sleep 0.4
call click 400 380 1 0; call key 76 $((CTRL + SHIFT)); sleep 1
[ "$(readlink "$zone/b (2).txt")" = "$zone/b.txt" ] && echo "ok    a link points at its file" || { echo "FAIL  a link points at its file"; failed=1; }
call key 90 $CTRL; sleep 1
[ ! -L "$zone/b (2).txt" ] && [ -f "$zone/b.txt" ] && echo "ok    and undo takes only the link" || { echo "FAIL  and undo takes only the link"; failed=1; }
call click 400 380 1 0; call sum; sleep 1
expect "properties work out a checksum" digest "$(sha256sum "$zone/b.txt" | cut -c1-64)"
call key $ESC 0
call go "$zone/folder"; sleep 0.6
call pref reopen true
open_at ""
expect "reopening starts where it was left" here "folder"
call pref reopen false

echo "-- a folder that goes away"
mkdir -p "$zone/soon/deeper"
call go "$zone/soon/deeper"; sleep 0.6; expect "inside the folder" here "deeper"
rm -rf "$zone/soon"
call key 16777268 0; sleep 1.5;     expect "refreshing climbs out of a deleted folder" here "zone"

echo "-- sorting by kind"
fresh
for name in one.stl two.stl one.3mf; do echo x >"$zone/$name"; done
open_at "$zone"
expect "the folder's kinds are counted" types "txt:3 stl:2 3mf:1"
call pin 3mf;                      expect "a pinned kind comes first" names "one.3mf | folder | a.txt | b.txt | c.txt | one.stl | two.stl"
call only true;                    expect "and can be shown alone" names "one.3mf"
call pin 3mf;                      expect "unpinning shows everything again" rows 7
call key 70 $CTRL; call type stl;  expect "the search beside the path filters" names "one.stl | two.stl"
call key $ESC 0; call key $ENTER 0
expect "the chips stay out of the way" sorter false
call click 1318 165 1 0;           expect "until the button brings them out" sorter true
call click 1318 165 1 0;           expect "and puts them away again" sorter false

echo "-- pointing at a file"
call go "$zone/folder"; sleep 0.6
call point "$zone/c.txt"; sleep 1
expect "another program can ask for a file's folder" here "zone"
expect "and finds the cursor on the file" selected "c.txt"

echo "-- actions from service menus"
mkdir -p "$XDG_CONFIG_HOME/archivos/acciones"
cat >"$XDG_CONFIG_HOME/archivos/acciones/twin.desktop" <<'MENU'
[Desktop Entry]
Type=Service
MimeType=text/plain;
Actions=twin;
X-KDE-Submenu=Tests

[Desktop Action twin]
Name=Make a twin
Name[es]=Hacer un gemelo
Exec=cp %f %d/twin-of-%n
MENU
open_at "$zone"
call click 400 380 1 0; call actions; sleep 1
expect "a menu for text offers itself to a text file" actions "Tests · Hacer un gemelo"
call act 0; sleep 1
[ -f "$zone/twin-of-b.txt" ] && echo "ok    and runs on the file" || { echo "FAIL  and runs on the file"; failed=1; }
rm -f "$zone/twin-of-b.txt"
call click 400 312 1 0; call actions; sleep 1
expect "but not to a folder" actions ""

echo "-- choosing a file for another program"
pkill -f "qs -p $harness" 2>/dev/null; sleep 0.3
ARCHIVOS_PICK=open ARCHIVOS_PICK_OUT=$work/answer ARCHIVOS_DIR=$zone qs -p "$harness" >"$work/window.log" 2>&1 &
sleep 4
expect "nothing is offered before a file is picked" pick ""
call click 400 380 1 0;            expect "a picked file is the answer" pick "$zone/b.txt"
call pickDone; sleep 1
[ "$(cat "$work/answer" 2>/dev/null)" = "$zone/b.txt" ] && echo "ok    it is handed over" || { echo "FAIL  it is handed over"; failed=1; }
pgrep -f "qs -p $harness" >/dev/null && { echo "FAIL  and the window leaves"; failed=1; } || echo "ok    and the window leaves"
ARCHIVOS_PICK=save ARCHIVOS_PICK_NAME=draft.txt ARCHIVOS_PICK_OUT=$work/answer ARCHIVOS_DIR=$zone qs -p "$harness" >"$work/window.log" 2>&1 &
sleep 4
call pickDone; sleep 1
[ "$(cat "$work/answer" 2>/dev/null)" = "$zone/draft.txt" ] && echo "ok    saving answers with the name in this folder" || { echo "FAIL  saving answers with the name in this folder"; failed=1; }

echo "-- undo keeps a history"
fresh
open_at "$zone"
call key 78 $((CTRL + SHIFT)); call type one; call key $ENTER 0; sleep 0.8
call key 78 $((CTRL + SHIFT)); call type two; call key $ENTER 0; sleep 0.8
expect "two steps are remembered" undos 2
[ -d "$zone/Nueva carpetaone" ] && [ -d "$zone/Nueva carpetatwo" ] && echo "ok    both folders were made" || { echo "FAIL  both folders were made"; failed=1; }
call key 90 $CTRL; sleep 1; call key 90 $CTRL; sleep 1
[ ! -e "$zone/Nueva carpetaone" ] && [ ! -e "$zone/Nueva carpetatwo" ] && echo "ok    both can be taken back" || { echo "FAIL  both can be taken back"; failed=1; }
expect "and both can come again" redos 2
call key 90 $((CTRL + SHIFT)); sleep 1; call key 90 $((CTRL + SHIFT)); sleep 1
[ -d "$zone/Nueva carpetaone" ] && [ -d "$zone/Nueva carpetatwo" ] && echo "ok    redo brings both back" || { echo "FAIL  redo brings both back"; failed=1; }

echo "-- adding a server"
call serverForm
call type files.example.org; call key $TAB 0; call type 2222; call key $TAB 0; call type guest
call key $TAB 0; call key $TAB 0; call type srv/data; call key $TAB 0; call type Example
call key $ENTER 0; sleep 1
expect "the form builds the address and keeps the server" servers "Example sftp://guest@files.example.org:2222/srv/data"

echo "-- a server that asks questions"
cat >"$work/fake-gio" <<'FAKE'
#!/bin/bash
# Stands in for `gio mount`: a new machine that wants trust, then a password.
log=$(dirname "$0")/fake-gio.log
printf 'Can not verify the identity of "host".\nThe identity sent is "SHA256:abc123".\n[1] Log In Anyway\n[2] Cancel Login\nChoice: '
read -r choice; echo "choice=$choice" >>"$log"
[ "$choice" = 1 ] || { echo "Login dialog cancelled" >&2; exit 2; }
printf 'Password required for share\nPassword: '
read -r word; echo "word=$word" >>"$log"
[ "$word" = sesame ] || { echo "Permission denied" >&2; exit 2; }
FAKE
chmod +x "$work/fake-gio"
pkill -f "qs -p $harness" 2>/dev/null; sleep 0.3
ARCHIVOS_GIO=$work/fake-gio ARCHIVOS_DIR=$zone qs -p "$harness" >"$work/window.log" 2>&1 &
sleep 4
call serverForm; call type host.test; call key $ENTER 0; sleep 1
call key $ENTER 0; sleep 1
call type sesame; call key $ENTER 0; sleep 1
[ "$(tr '\n' ' ' <"$work/fake-gio.log")" = "choice=1 word=sesame " ] && echo "ok    trust and the password are both answered" || { echo "FAIL  trust and the password are both answered: $(cat "$work/fake-gio.log" 2>/dev/null)"; failed=1; }
expect "and it says so" notice "CONECTADO · HOST.TEST"
rm -f "$work/fake-gio.log"
call serverForm; call type other.test; call key $ENTER 0; sleep 1
call key $ESC 0; sleep 1
expect "refusing to trust cancels the login" notice "NO SE CONECTÓ A OTHER.TEST · LOGIN DIALOG CANCELLED"

echo "-- looking inside an archive"
fresh
mkdir -p "$work/pack/inner"; echo deep >"$work/pack/inner/note.txt"
(cd "$work/pack" && bsdtar -a -cf "$zone/pack.zip" inner)
open_at "$zone"
call click 400 472 1 0; call peek; sleep 1.5
expect "the archive opens like a folder" names "inner"
expect "under its own name" shown "pack.zip:/"
[ ! -e "$zone/pack" ] && echo "ok    and nothing is unpacked beside it" || { echo "FAIL  and nothing is unpacked beside it"; failed=1; }

echo "-- what the user may not do"
fresh
mkdir -p "$zone/locked"; chmod 555 "$zone/locked"
printf '#!/bin/bash\nshift; echo "$@" >"%s/elevated"\n' "$work" >"$work/fake-pkexec"; chmod +x "$work/fake-pkexec"
pkill -f "qs -p $harness" 2>/dev/null; sleep 0.3
ARCHIVOS_PKEXEC=$work/fake-pkexec ARCHIVOS_DIR=$zone/locked qs -p "$harness" >"$work/window.log" 2>&1 &
sleep 4
call key 78 $((CTRL + SHIFT)); call type x; call key $ENTER 0; sleep 1
expect "a refusal offers the administrator" notice "NO SE PUDO · HACE FALTA SER ADMINISTRADOR"
call key $ENTER 0; sleep 1
[ "$(cat "$work/elevated" 2>/dev/null)" = "mkdir $zone/locked Nueva carpetax" ] && echo "ok    and repeats the same step as root" || { echo "FAIL  and repeats the same step as root: $(cat "$work/elevated" 2>/dev/null)"; failed=1; }
chmod 755 "$zone/locked"

echo "-- renaming several shows what will happen"
fresh
open_at "$zone"
call key 65 $CTRL; call key $F2 0; call key 65 $CTRL; call type "doc {n}"
expect "the new names are shown before anything moves" hint "folder  →  doc 1
a.txt  →  doc 2.txt
b.txt  →  doc 3.txt
c.txt  →  doc 4.txt"
call key $ESC 0

echo "-- scripts kept for another file manager"
mkdir -p "$work/data/nautilus/scripts/Tools"
printf '#!/bin/bash\nprintf "%%s|" "$@" >"%s/script-ran"\n' "$work" >"$work/data/nautilus/scripts/Tools/Mark"
chmod +x "$work/data/nautilus/scripts/Tools/Mark"
pkill -f "qs -p $harness" 2>/dev/null; sleep 0.3
ARCHIVOS_DIR=$zone qs -p "$harness" >"$work/window.log" 2>&1 &
sleep 4
call click 400 380 1 0; call actions; sleep 1
expect "a script is offered next to the service menus" actions "Tests · Hacer un gemelo | Tools · Mark"
call act 1; sleep 1
[ "$(cat "$work/script-ran" 2>/dev/null)" = "$zone/b.txt|" ] && echo "ok    and gets the selection" || { echo "FAIL  and gets the selection: $(cat "$work/script-ran" 2>/dev/null)"; failed=1; }

echo "-- a pack of actions from a repository"
mkdir -p "$work/origin/kit"
printf '#!/bin/bash\ntouch "$1.stamped"\n' >"$work/origin/kit/Stamp"; chmod +x "$work/origin/kit/Stamp"
echo notes >"$work/origin/kit/README.md"
(cd "$work/origin/kit" && git init -q && git add -A && git -c user.name=t -c user.email=t@t commit -qm kit)
call pack "file://$work/origin/kit"; sleep 2
expect "the pack is fetched and its scripts counted" packs "kit:1"
call click 400 380 1 0; call actions; sleep 1
expect "its script joins the actions" actions "Tests · Hacer un gemelo | kit · Stamp | Tools · Mark"
call act 1; sleep 1
[ -f "$zone/b.txt.stamped" ] && echo "ok    and runs on the file" || { echo "FAIL  and runs on the file"; failed=1; }
call unpack kit; sleep 1.5
expect "removing the pack takes it away" packs ""

echo "-- colour labels"
fresh
open_at "$zone"
call click 400 380 1 0; call label red
expect "a file can wear a colour" labels "red:1"
call key $F2 0; call key 65 $CTRL; call type renamed.txt; call key $ENTER 0; sleep 1
call go "$zone/folder"; sleep 0.6; call showLabel red; sleep 1
expect "the colour follows a rename and gathers its files" names "renamed.txt"
call click 400 312 1 0; call label ""
expect "and comes off" labels ""

echo "-- searching the whole home folder"
if command -v plocate >/dev/null 2>&1; then
    mkdir -p "$work/home/far/away"; echo x >"$work/home/far/away/needle-in-hay.txt"
    pkill -f "qs -p $harness" 2>/dev/null; sleep 0.3
    HOME=$work/home XDG_CACHE_HOME=$work/cache ARCHIVOS_DIR=$zone qs -p "$harness" >"$work/window.log" 2>&1 &
    sleep 4
    call everywhere needle-in; sleep 2
    expect "a name is found far from the folder on show" names "needle-in-hay.txt"
else
    echo "skip  plocate is not installed"
fi

echo "-- folders that open in place"
fresh
mkdir -p "$zone/folder/inner"; echo x >"$zone/folder/leaf.txt"; echo x >"$zone/folder/inner/deep.txt"
open_at "$zone"
call click 400 312 1 0; call key 16777236 0; sleep 0.8
expect "right opens a folder under itself" names "folder | inner | leaf.txt | a.txt | b.txt | c.txt"
call key $DOWN 0; call key 16777236 0; sleep 0.8
expect "and a folder inside it" names "folder | inner | deep.txt | leaf.txt | a.txt | b.txt | c.txt"
call key $DOWN 0; call key 16777234 0; expect "left steps out to the folder" selected "inner"
call key 16777234 0;               expect "then closes it" names "folder | inner | leaf.txt | a.txt | b.txt | c.txt"
call click 400 392 1 0; call key $F2 0; call key 65 $CTRL; call type twig.txt; call key $ENTER 0; sleep 1.2
[ -f "$zone/folder/twig.txt" ] && echo "ok    a file is renamed where it sits" || { echo "FAIL  a file is renamed where it sits"; failed=1; }
expect "and the opened folder shows it" names "folder | inner | twig.txt | a.txt | b.txt | c.txt"

echo "-- themes"
mkdir -p "$XDG_CONFIG_HOME/archivos/temas"
echo '{ "name": "Mine", "follow": false, "ink": "#123456", "rail": "right" }' >"$XDG_CONFIG_HOME/archivos/temas/mine.json"
open_at "$zone"
expect "the user's themes are listed with the given ones" themes "mine claro medianoche terminal"
call set theme mine; sleep 1
expect "a theme changes the colours" ink "#123456"
expect "and can move the side panel" railRight true
call set theme ""; sleep 1
expect "going back puts the panel where it was" railRight false

echo "-- languages"
mkdir -p "$XDG_CONFIG_HOME/archivos/idiomas"
echo '{ "name": "Test", "Abrir": "Aufmachen" }' >"$XDG_CONFIG_HOME/archivos/idiomas/xx.json"
open_at "$zone"
expect "the user's languages are listed with the given ones" languages "xx en"
expect "the program speaks Spanish by itself" word "Abrir"
call set language en; sleep 1
expect "a language that comes along changes the words" word "Open"
call set language xx; sleep 1
expect "and so does one of the user's own" word "Aufmachen"
call key 78 $((CTRL + SHIFT)); call key $ENTER 0; sleep 1
expect "what has no translation stays in Spanish" notice "CARPETA CREADA · NUEVA CARPETA"
call set language es; sleep 0.6

echo "-- the selection panel"
open_at "$zone"
expect "nothing picked, no panel" detail false
call click 400 380 1 0;            expect "picking a file brings it" detail true
call key $ESC 0;                   expect "and escape sends it away" detail false

echo "-- the minimal header"
call set header minimal; sleep 0.6
call click 1306 42 1 0;            expect "its eye shows the hidden files" hidden true
call click 1306 42 1 0;            expect "and hides them again" hidden false
call click 1146 42 1 0;            expect "the order button is still there" sorter true
call click 1146 42 1 0
call set header full; sleep 0.6

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

#!/bin/bash
# run.sh: one check per fault that was once reported. Each fails on the bare
# from before its fix.
#
#   BARE=path   the bare to test (default: the one in this repo)
#
# Needs no screen. Every check gets an empty home and an empty work folder.
# The checks on the line editor type into a pty made by script(1).
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
BARE=${BARE:-$HERE/../bare}
[ -x "$BARE" ] || { echo "no bare at $BARE: run make"; exit 2; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
W=$T/w; fail=0

# Nothing a bare under test starts may reach your screen. An old bare hands
# a file it cannot run to bare-open, which opened LibreOffice on the live
# display. So: no display at all, and openers that only take a note.
unset DISPLAY WAYLAND_DISPLAY
mkdir "$T/stub"
for o in bare-open xdg-open; do
    printf '#!/bin/sh\necho "$0 $*" >> %s/opened\n' "$T" > "$T/stub/$o"; chmod +x "$T/stub/$o"
done
PATH=$T/stub:$PATH

fresh() { cd /; rm -rf "$T/home" "$W"; mkdir "$T/home" "$W"; cd "$W"; }
# b ARGS: run bare with the private home
b() { HOME=$T/home EDITOR=/bin/true timeout 10 "$BARE" "$@" 2>&1; }
# keys TEXT...: start bare on a pty and type each TEXT, 0.3 s apart.
# bare is the session leader there, as in a real terminal. What the
# terminal was sent ends up in $T/pty. RUN=... starts bare another way.
keys() {
    { sleep 0.5; for k; do printf '%b' "$k"; sleep 0.3; done; } |
        HOME=$T/home SHELL=/bin/sh TERM=xterm timeout 30 script -qec "${RUN:-exec $BARE}" /dev/null >"$T/pty" 2>&1
}
# is NAME GOT WANT
is() {
    if [ "$2" = "$3" ]; then printf '  ok    %s\n' "$1"
    else printf '  FAIL  %s: wanted %q, got %q\n' "$1" "$3" "$2"; fail=1; fi
}

echo "== v0.2.48: a nick holding ; runs as a typed line"
fresh; printf 'nick.two = echo a;echo b\nnick.w = echo a\n' > "$T/home/.barerc"
is "both halves of the nick run"        "$(b -c 'two')"       $'a\nb'
is "a nick first in a ; line"           "$(b -c 'w; echo b')" $'a\nb'

echo "== v0.2.49: history is written as you go"
fresh; keys 'echo keepme\n' "sh -c 'kill -9 \$PPID'\n"
is "a killed shell keeps its history"   "$(grep -c 'echo keepme' "$T/home/.bare_history" 2>/dev/null)" 1

echo "== v0.2.50: lines parse as in other shells"
fresh; touch .a b2 b1
is "each command expands when it runs"  "$(b -c 'cd /tmp && echo $PWD')" /tmp
is "quotes inside a word"               "$(b -c 'echo --opt="x y" a\ b '"'it''s'")" '--opt=x y a b its'
is "a builtin can be redirected"        "$(b -c 'pwd > f; cat f')" "$W"
is "\$? is 128 plus the signal"         "$(b -c "sh -c 'kill -TERM \$\$'; echo \$?")" 143
is "globs are sorted, .* skips . and .." "$(b -c 'echo .* b*')" '.a b1 b2'
b -c 'exit 3' >/dev/null
is "exit N sets the status"             $? 3
is "X=1 in front of a pipe"             "$(b -c 'X=1 env | grep ^X=')" X=1

echo "== v0.2.51: job control"
fresh; keys 'sleep 9 | sleep 9 | cat\n' '\x1a' ':jobs > out\n' 'exit\n' 'exit\n'
case $(cat out 2>/dev/null) in
    *Stopped*'sleep 9 | sleep 9 | cat'*) printf '  ok    Ctrl-Z stops a pipe as one job\n' ;;
    *) printf '  FAIL  Ctrl-Z stops a pipe as one job: :jobs said %q\n' "$(cat out 2>/dev/null)"; fail=1 ;;
esac
fresh; keys 'head -1 > out &\n' ':fg\n' 'hello\n' 'exit\n'
is ":fg hands the terminal to a job that reads it" "$(cat out 2>/dev/null)" hello
fresh; keys 'true &\n' 'sleep 0.3\n' "sh -c 'ps -o stat= --ppid \$PPID | tr -d \" \\\\n\" > out'\n" 'exit\n'
is "a finished background job leaves no zombie" "$(cat out 2>/dev/null)" 'S+'

echo "== v0.2.52: tab completion"
fresh; mkdir bin; printf '#!/bin/sh\necho ran > %s/out\n' "$W" > bin/zzuniqtool; chmod +x bin/zzuniqtool
keys "export PATH=$W/bin:\$PATH\n" 'zzun\t' '\n' 'exit\n'
is "completion follows a changed PATH"  "$(cat out 2>/dev/null)" ran

echo "== v0.2.53 and v0.2.58: scripts"
fresh; printf 'cat\necho after\n' > s
is "a script does not sit on stdin"     "$(echo piped | b s)" $'piped\nafter'
printf 'echo from-sh\n' > x; chmod +x x
is "a program with no #! runs in sh"    "$(b -c './x')" from-sh
mkdir test
is "a folder named test does not win over test (v0.2.58)" \
   "$(b -c 'test -d nothere && echo WRONG; pwd')" "$W"

echo "== v0.2.54: ** in big trees"
fresh; mkdir -p b a; touch b/y.c a/x.c
is "** results are sorted, no ./ in front" "$(b -c 'echo **/*.c')" 'a/x.c b/y.c'
fresh; for i in {1..3000}; do echo "d$i/sub"; done | xargs mkdir -p
for i in 5 400 900 1500 2100 2700 2999; do touch "d$i/sub/f.hit"; done
is "** finds all 7 files under 3000 folders" "$(b -c 'echo **/*.hit' | wc -w)" 7

echo "== v0.2.55: the line editor"
fresh; keys 'bc > out' '\e[1~' 'echo a' '\n' 'exit\n'
is "Home as ESC[1~ goes to the line start" "$(cat out 2>/dev/null)" abc
fresh; printf -v long '%*s' 400 ''; keys "echo ${long// /x}" '\n' 'exit\n'
n=$(wc -c < "$T/pty")
[ "$n" -lt 40000 ] && printf '  ok    a 400-letter line is not resent for every key\n' ||
    { printf '  FAIL  a 400-letter line is not resent for every key: %s bytes sent\n' "$n"; fail=1; }

echo "== v0.2.56: cd keeps the path you typed"
fresh; mkdir real; ln -s real link
is "a symlinked folder stays in pwd, .. climbs out" "$(b -c 'cd link; pwd; cd ..; pwd')" "$W/link"$'\n'"$W"

echo "== v0.2.59: bare started as a plain child of another program"
# sh -c 'bare; :' keeps sh alive, so bare neither leads the session nor
# its process group. It used to end after its first command there.
fresh; RUN="$BARE; :" keys '/bin/true\n' 'echo alive > out\n' 'exit\n'
is "bare lives on after a command"      "$(cat out 2>/dev/null)" alive
fresh; RUN="$BARE; :" keys 'sleep 9 | sleep 9 | cat\n' '\x1a' ':jobs > out\n' 'exit\n' 'exit\n'
case $(cat out 2>/dev/null) in
    *Stopped*'sleep 9 | sleep 9 | cat'*) printf '  ok    Ctrl-Z on a pipe stops the pipe, not bare\n' ;;
    *) printf '  FAIL  Ctrl-Z on a pipe stops the pipe, not bare: :jobs said %q\n' "$(cat out 2>/dev/null)"; fail=1 ;;
esac

echo "== v0.2.60: a tab list longer than completion_limit"
# 5 matches and a limit of 3: the list showed f1 f2 f3 and gave no sign of
# the other two. Tabbing on to f4 picked it, with the list still at f1 f2 f3.
fresh; printf 'completion_limit = 3\n' > "$T/home/.barerc"; touch f1 f2 f3 f4 f5
keys 'ls f\t' '\t\t\t' '\n' 'exit\n'
has() { grep -qF -- "$1" "$T/pty" && echo yes || echo no; }
is "the list says how many names it left out" "$(has '+2')" yes
is "tabbing past the last name shown lists the next ones" "$(has 'f5')" yes

echo
[ $fail = 0 ] && echo "bare tests: all good" || echo "bare tests: FAILED"
exit $fail

#!/bin/sh
set -eu
umask 077
expected_uid=$1
token=$2
shift 2
test "$(id -u)" = "$expected_uid"
case "$token" in *[!0-9a-f]*|'') exit 71 ;; esac
# Probe the exact mounted scratch directory as the actual mysqld UID before
# executing mysqld. It never uses the retained data directory as scratch.
probe="/mysql-tmp/probe-$token-$$"
trap 'rm -f "$probe"' EXIT HUP INT TERM
printf 'write-probe\n' > "$probe"
test -r "$probe"
rm "$probe"
printf '{"uid":%s,"path":"/mysql-tmp","status":"passed"}\n' "$expected_uid" > "$probe"
mv "$probe" "/mysql-tmp/write-probe-$token.json"
trap - EXIT HUP INT TERM
exec "$@"

#!/usr/bin/env bats
# pyre remind: reading a time, and the life of a reminder (its file, its
# timer, its notification). systemd-run, systemctl and notify-send are stubs
# that log their calls, so no test reaches the real session.

setup() {
  cli="$BATS_TEST_DIRNAME/../src/cli"
  export HOME="$BATS_TEST_TMPDIR/home" XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
  export LOG="$BATS_TEST_TMPDIR/log" TZ=UTC LC_ALL=C
  unset PYRE_LIB
  # Friday 2031-03-14 14:00:00 UTC: ahead of the real clock, so the timers
  # are set for the times asked.
  export PYRE_REMIND_NOW=1931263200
  dir="$XDG_STATE_HOME/pyre/reminders"
  mkdir -p "$HOME" "$BATS_TEST_TMPDIR/bin"
  : >"$LOG"
  stub systemd-run
  stub systemctl
  stub notify-send
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

# stub NAME [STATUS] [OUTPUT]: a fake NAME that logs its call, prints OUTPUT
# and exits STATUS.
stub() {
  printf '#!/bin/sh\necho "%s $*" >> "%s"\n%s\nexit %s\n' "$1" "$LOG" "${3:+echo \"$3\"}" "${2:-0}" \
    >"$BATS_TEST_TMPDIR/bin/$1"
  chmod +x "$BATS_TEST_TMPDIR/bin/$1"
}

pyre() {
  "$cli/pyre" "$@"
}

# parses TEXT WHEN MESSAGE: --parse reads TEXT as that time and message.
parses() {
  run pyre remind --parse "$1"
  [ "$status" -eq 0 ] || { echo "$1: $output"; return 1; }
  [ "$(cut -f2- <<<"$output")" = "$2"$'\t'"$3" ] || { echo "$1: got $output"; return 1; }
}

@test "remind reads a duration from now" {
  parses "10m tea" "14:10 (in 10 min)" "tea"
  parses "45s" "14:00 (in 45 s)" ""
  parses "1h30m check the oven" "15:30 (in 1 h 30 min)" "check the oven"
  parses "2 hours 30 minutes stretch" "16:30 (in 2 h 30 min)" "stretch"
  parses "1.5h stretch" "15:30 (in 1 h 30 min)" "stretch"
  parses "in an hour call back" "15:00 (in 1 h)" "call back"
  parses "2d water the plants" "Sun 16 Mar 14:00 (in 2 d)" "water the plants"
}

@test "remind reads a clock time as the next time the clock shows it" {
  parses "5pm call mum" "17:00 (in 3 h)" "call mum"
  parses "5 pm call mum" "17:00 (in 3 h)" "call mum"
  parses "5:30pm tea" "17:30 (in 3 h 30 min)" "tea"
  parses "17:30 tea" "17:30 (in 3 h 30 min)" "tea"
  parses "13:30 lunch" "tomorrow 13:30 (in 23 h 30 min)" "lunch"
  parses "noon lunch" "tomorrow 12:00 (in 22 h)" "lunch"
  parses "12am sleep" "tomorrow 00:00 (in 10 h)" "sleep"
}

@test "remind reads a day, at 09:00 unless a time follows" {
  parses "tomorrow standup" "tomorrow 09:00 (in 19 h)" "standup"
  parses "tomorrow at 7:15 run" "tomorrow 07:15 (in 17 h 15 min)" "run"
  parses "5pm tomorrow pack" "tomorrow 17:00 (in 1 d 3 h)" "pack"
  parses "today 18:00 dinner" "18:00 (in 4 h)" "dinner"
  parses "monday plan the week" "Mon 17 Mar 09:00 (in 2 d 19 h)" "plan the week"
  # Today is Friday: a time still ahead is today, one that passed is next week.
  parses "fri 15:00 report" "15:00 (in 1 h)" "report"
  parses "friday 9am report" "Fri 21 Mar 09:00 (in 6 d 19 h)" "report"
}

@test "remind takes the time last, and plain English around it" {
  parses "me to call mum at 5pm" "17:00 (in 3 h)" "call mum"
  parses "Me in 10 min to stand up" "14:10 (in 10 min)" "stand up"
  parses "call mum in 10 minutes" "14:10 (in 10 min)" "call mum"
  parses "buy milk tomorrow at 9am" "tomorrow 09:00 (in 19 h)" "buy milk"
  parses "Call Mum 10m" "14:10 (in 10 min)" "Call Mum"
}

@test "remind refuses a text without a time, and sets nothing" {
  local text
  for text in "hello world" "5 apples" "25:00 x" "13pm x" "today 9am x" "0m x" "10x tea" "500 days x" ""; do
    run pyre remind --parse "$text"
    [ "$status" -eq 1 ] || { echo "parsed: $text: $output"; return 1; }
  done
  run pyre remind buy milk
  [ "$status" -eq 1 ]
  [[ "$output" == *"when?"* ]]
  [ ! -e "$dir" ]
  [ ! -s "$LOG" ]
}

@test "remind sets a file and a wall-clock timer, lists soonest first, and cancels" {
  run pyre remind 5pm call mum
  [ "$status" -eq 0 ]
  [[ "$output" == *"reminder 1 set for 17:00 (in 3 h): call mum"* ]]
  [ "$(cat "$dir/1")" = "$(printf '1931274000\ncall mum')" ]
  grep -qxF "systemd-run --user --quiet --collect --unit=pyre-remind-1 --description=PyreOS reminder 1 --on-calendar=2031-03-14 17:00:00 UTC --timer-property=AccuracySec=1s --timer-property=RemainAfterElapse=no --setenv=XDG_STATE_HOME=$XDG_STATE_HOME $(readlink -f "$cli/pyre") remind --fire 1" "$LOG"

  # The launcher passes the whole text as one argument.
  run pyre remind "me in 10m to drink water"
  [ "$status" -eq 0 ]
  [ "$(cat "$dir/2")" = "$(printf '1931263800\ndrink water')" ]
  run pyre remind tomorrow
  [ "$status" -eq 0 ]

  run pyre remind list
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf '2\t14:10 (in 10 min)\tdrink water\n1\t17:00 (in 3 h)\tcall mum\n3\ttomorrow 09:00 (in 19 h)\tReminder')" ]
  [ "$(pyre remind)" = "$output" ]

  run pyre remind cancel 1
  [ "$status" -eq 0 ]
  [ ! -e "$dir/1" ]
  grep -qx 'systemctl --user --quiet stop pyre-remind-1.timer' "$LOG"
  run pyre remind cancel 1
  [ "$status" -eq 1 ]
  run pyre remind cancel
  [ "$status" -eq 1 ]
  # A number is never used by two pending reminders.
  run pyre remind 1h stretch
  [[ "$output" == *"reminder 4 set"* ]]
  run pyre remind cancel all
  [ "$status" -eq 0 ]
  [[ "$output" == *"cancelled 3 reminder(s)"* ]]
  [ -z "$(pyre remind list)" ]
}

@test "remind keeps nothing when the timer cannot be set" {
  stub systemd-run 1
  run pyre remind 10m tea
  [ "$status" -eq 1 ]
  [[ "$output" == *"could not set a timer"* ]]
  [ -z "$(ls "$dir")" ]
}

@test "remind --fire shows the reminder until dismissed and forgets it" {
  pyre remind 10m tea
  PYRE_REMIND_NOW=$((PYRE_REMIND_NOW + 600)) run pyre remind --fire 1
  [ "$status" -eq 0 ]
  grep -qx 'notify-send -a Reminder -i alarm-symbolic -t 0 -- tea Reminder for 14:10' "$LOG"
  [ ! -e "$dir/1" ]
  # Fired again, or cancelled before its timer: nothing to show.
  : >"$LOG"
  run pyre remind --fire 1
  [ "$status" -eq 0 ]
  [ ! -s "$LOG" ]
}

@test "remind --fire says when a reminder is late, and names one without a message" {
  pyre remind 10m
  PYRE_REMIND_NOW=$((PYRE_REMIND_NOW + 86400)) run pyre remind --fire 1
  [ "$status" -eq 0 ]
  grep -qx 'notify-send -a Reminder -i alarm-symbolic -t 0 -- Reminder Reminder for Fri 14 Mar 14:10, which passed while you were away' "$LOG"
}

@test "remind --fire keeps the reminder when nothing shows notifications" {
  pyre remind 10m tea
  stub notify-send 1
  PYRE_REMIND_WAIT=0 run pyre remind --fire 1
  [ "$status" -eq 1 ]
  [[ "$output" == *"kept for the next login"* ]]
  [ -f "$dir/1" ]
}

@test "remind --rearm sets the missing timers, a missed one for now, and a second run changes nothing" {
  pyre remind 10m tea
  pyre remind 5pm call mum
  mkdir -p "$dir"
  printf '1000\nlong ago\n' >"$dir/7"
  : >"$LOG"
  run pyre remind --rearm
  [ "$status" -eq 0 ]
  [ "$(grep -c '^systemd-run ' "$LOG")" -eq 3 ]
  grep -q -- '--unit=pyre-remind-2 .*--on-calendar=2031-03-14 17:00:00 UTC .*remind --fire 2$' "$LOG"
  # 1970 is past: its timer is set for a moment from now.
  local at
  at="$(sed -n 's/.*--unit=pyre-remind-7 .*--on-calendar=\(.*\) UTC --timer-property=Acc.*/\1/p' "$LOG")"
  at="$(date -d "$at" +%s)"
  (( at >= $(date +%s) && at <= $(date +%s) + 10 ))
  [ "$(cat "$dir/7")" = "$(printf '1000\nlong ago')" ]

  # With the timers loaded, there is nothing to set.
  stub systemctl 0 "pyre-remind-1.timer loaded active waiting"
  : >"$LOG"
  run pyre remind --rearm
  [ "$status" -eq 0 ]
  [ "$(grep -c '^systemd-run ' "$LOG")" -eq 0 ]
}

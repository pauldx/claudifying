#!/usr/bin/env bash
# cf-sim: deterministic Claude Code session simulator for demo recording.
#
# Reads a scripted transcript file and replays it with realistic
# prompt/typing/response cadence so vhs captures a clean, repeatable GIF
# without burning real API credits or depending on Anthropic uptime.
#
# Transcript format (line-prefixed directives):
#   #PROMPT         Print a Claude Code-style prompt line ("❯ ")
#   #USER <text>    Print user input after the prompt with a brief pause
#   #THINK <ms>     "Claude is thinking..." spinner for <ms> milliseconds
#   #SAY <text>     Print Claude response line (no prefix)
#   #CODE <text>    Print a code/output line in muted color
#   #OK <text>      Print a success line in green
#   #WARN <text>    Print a warning line in yellow
#   #ERR <text>     Print an error line in red
#   #SLEEP <ms>     Pause without printing
#   #CLEAR          Clear the screen
#   #DIVIDER        Print a horizontal rule
#
# Anything else is printed verbatim (after directive-trimming).
#
# Usage: cf-sim path/to/script.txt

set -euo pipefail

SCRIPT="${1:?script path required}"
[[ -f "$SCRIPT" ]] || { echo "script not found: $SCRIPT" >&2; exit 1; }

# ANSI helpers
DIM=$'\033[2m'
BOLD=$'\033[1m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
CYAN=$'\033[36m'
MAGENTA=$'\033[35m'
RESET=$'\033[0m'

# Sleep in milliseconds (portable via perl, falls back to sleep).
msleep() {
  local ms="${1:-0}"
  perl -e "select(undef, undef, undef, $ms/1000)" 2>/dev/null \
    || sleep "$(awk "BEGIN { print $ms/1000 }")"
}

# Print a line with a typing animation, char by char.
type_out() {
  local text="$1" delay_ms="${2:-25}"
  local i ch
  for (( i=0; i<${#text}; i++ )); do
    ch="${text:$i:1}"
    printf '%s' "$ch"
    msleep "$delay_ms"
  done
  printf '\n'
}

spinner_for() {
  local total_ms="$1"
  local frames=( '⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏' )
  local elapsed=0 i=0
  while (( elapsed < total_ms )); do
    printf '\r%s%s%s thinking...' "$CYAN" "${frames[$((i % ${#frames[@]}))]}" "$RESET"
    msleep 80
    elapsed=$(( elapsed + 80 ))
    i=$(( i + 1 ))
  done
  printf '\r\033[K'
}

while IFS= read -r line; do
  case "$line" in
    '#PROMPT'*)
      printf '%s❯%s ' "$MAGENTA" "$RESET"
      ;;
    '#USER '*)
      type_out "${line#'#USER '}" 35
      msleep 250
      ;;
    '#THINK '*)
      spinner_for "${line#'#THINK '}"
      ;;
    '#SAY '*)
      printf '%s\n' "${line#'#SAY '}"
      msleep 90
      ;;
    '#CODE '*)
      printf '%s%s%s\n' "$DIM" "${line#'#CODE '}" "$RESET"
      msleep 60
      ;;
    '#OK '*)
      printf '%s✓%s %s\n' "$GREEN" "$RESET" "${line#'#OK '}"
      msleep 90
      ;;
    '#WARN '*)
      printf '%s⚠%s %s\n' "$YELLOW" "$RESET" "${line#'#WARN '}"
      msleep 90
      ;;
    '#ERR '*)
      printf '%s✗%s %s\n' "$RED" "$RESET" "${line#'#ERR '}"
      msleep 90
      ;;
    '#SLEEP '*)
      msleep "${line#'#SLEEP '}"
      ;;
    '#CLEAR')
      printf '\033[2J\033[H'
      ;;
    '#DIVIDER')
      printf '%s────────────────────────────────────────────────────────%s\n' "$DIM" "$RESET"
      ;;
    '#HEADER '*)
      printf '%s%s%s\n' "$BOLD" "${line#'#HEADER '}" "$RESET"
      ;;
    '')
      printf '\n'
      msleep 50
      ;;
    *)
      printf '%s\n' "$line"
      msleep 60
      ;;
  esac
done < "$SCRIPT"

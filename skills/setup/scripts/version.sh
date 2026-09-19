#!/bin/sh
# Prints the version of the plugin this skill ships in, read from the nearest
# .claude-plugin/plugin.json above this script, so the file works unchanged in
# any skill of any plugin. Runs when the skill loads. POSIX sh, sed and head
# only: macOS, Linux (Alpine included), the BSDs, Git Bash on Windows.
dir=$(cd "$(dirname "$0")" && pwd)
until [ -z "$dir" ] || [ -f "$dir/.claude-plugin/plugin.json" ]; do dir=${dir%/*}; done
version=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$dir/.claude-plugin/plugin.json" 2>/dev/null | head -n 1)
printf 'plugin_version: %s\n' "${version:-unknown}"

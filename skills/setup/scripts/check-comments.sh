#!/usr/bin/env bash
# Checks that every comment the setup skill wrote in a Renovate config is one
# of its templates, word for word. The templates are the `//` lines of the
# jsonc blocks in SKILL.md, the `// ...` spans quoted in its prose, and the
# manual-review candidates of detect.sh; a `<...>` placeholder in a template
# matches any text. A setting kept from the repository's own config sits under
# a "Repository rule" or "Repository setting" marker line: its comments and its
# lines, up to the end of the rule or key, are the repository's and are not
# checked. Prints every other comment line with its line number, and exits 1
# when there is one.
# Portable: bash 3, POSIX awk/sed/grep.
# Usage: check-comments.sh <config file>
set -u
[ $# -eq 1 ] && [ -f "$1" ] || { echo "usage: $0 <config file>" >&2; exit 2; }
here=$(cd "$(dirname "$0")" && pwd)

templates() {
  # Full-line comments inside the jsonc blocks; a line that is nothing but a
  # placeholder stands for text from elsewhere, the candidates below.
  awk '/^```jsonc/ { f = 1; next } /^```/ { f = 0 } f' "$here/../SKILL.md" |
    sed -n 's/^[[:space:]]*\(\/\/ .*\)$/\1/p' | grep -v '^// <[^>]*>$'
  # Comments quoted in the prose, as `// ...`, minus that example and `// ---`, which only name a shape.
  grep -o '`// [^`]*`' "$here/../SKILL.md" | sed 's/^`//; s/`$//' | grep -v -x -e '// \.\.\.' -e '// ---'
  # The manual-review candidates: detect.sh writes their comment from its cand lines.
  cand() { printf '// %s %s: %s\n' "$4" "$5" "$6"; }
  eval "$(grep '^cand ' "$here/detect.sh")"
}

templates | awk -v cfg="$1" '
  # A template is a list of literal parts around its <...> placeholders.
  function matches(line, t,    n, parts, i, pos, rest) {
    n = split(t, parts, /<[^>]*>/)
    if (n == 1) return line == t
    if (substr(line, 1, length(parts[1])) != parts[1]) return 0
    rest = substr(line, length(parts[1]) + 1)
    for (i = 2; i < n; i++) {
      pos = index(rest, parts[i]); if (parts[i] == "") continue
      if (pos == 0) return 0
      rest = substr(rest, pos + length(parts[i]))
    }
    return length(rest) > length(parts[n]) && substr(rest, length(rest) - length(parts[n]) + 1) == parts[n]
  }
  { tpl[++nt] = $0 }
  END {
    bad = 0
    while ((getline line < cfg) > 0) {
      ln++
      c = line; sub(/^[[:space:]]+/, "", c); sub(/[[:space:]]+$/, "", c)
      if (c ~ /^\/\/ Repository (rule|setting), not written by the plugin:$/) { kept = 1; depth = 0; continue }
      if (kept) {
        # The kept setting: its comments and blank lines, then its lines until its braces and brackets close.
        if (c == "" || substr(c, 1, 2) == "//") continue
        gsub(/"([^"\\]|\\.)*"/, "", c); gsub(/\047([^\047\\]|\\.)*\047/, "", c); sub(/\/\/.*/, "", c)
        depth += gsub(/[[{]/, "", c) - gsub(/[]}]/, "", c)
        if (depth <= 0) kept = 0
        continue
      }
      if (substr(c, 1, 2) != "//") {
        # Every template is a whole line, so a comment after code, outside a string, is never one.
        code = c; gsub(/"([^"\\]|\\.)*"/, "", code); gsub(/\047([^\047\\]|\\.)*\047/, "", code)
        if (index(code, "//")) { print ln ": " c; bad = 1 }
        continue
      }
      ok = 0
      for (i = 1; i <= nt && !ok; i++) ok = matches(c, tpl[i])
      if (!ok) { print ln ": " c; bad = 1 }
    }
    exit bad
  }
'

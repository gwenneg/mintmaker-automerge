#!/usr/bin/env bash
# Repo facts for the mintmaker-automerge setup skill. Read-only: it lists
# tracked files and greps a few of them. Runs when the skill loads, from the
# current directory. Every section prints something, so a missing line means
# the script did not get there.
set -u
say() { printf '%s\n' "$*"; }

if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  say "STATUS: not inside a git repository. Do the checks of Steps 1 to 3 by hand."
  exit 0
fi
cd "$(git rev-parse --show-toplevel)" || exit 0
FILES=$(git ls-files)
list() { printf '%s\n' "$FILES" | grep -E "$1"; }

say "== Konflux"
if [ -d .tekton ]; then
  n=$(list '^\.tekton/.*\.ya?ml$' | wc -l | tr -d ' ')
  say "tekton_dir: yes, $n tracked YAML files"
  for m in pipelinesascode.tekton.dev appstudio.openshift.io konflux; do
    if grep -rqs "$m" .tekton; then say "marker $m: found"; else say "marker $m: absent"; fi
  done
else
  say "tekton_dir: no"
fi

say "== Default branch"
db=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
if [ -z "$db" ] && command -v gh >/dev/null 2>&1; then
  db=$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null)
fi
say "default_branch: ${db:-unknown}"

say "== Ecosystems (manager: first matching files)"
eco() {
  f=$(list "$2" | head -5 | tr '\n' ' ')
  [ -n "$f" ] && say "$1: $f"
}
eco maven '(^|/)pom\.xml$'
eco maven-wrapper '(^|/)(mvnw|\.mvn/wrapper/[^/]+)$'
eco gradle '(^|/)build\.gradle(\.kts)?$'
eco gradle-wrapper '(^|/)gradle/wrapper/gradle-wrapper\.properties$'
eco gomod '(^|/)go\.mod$'
eco npm '(^|/)package\.json$'
eco pip_requirements '(^|/)requirements[^/]*\.txt$'
eco pip_setup '(^|/)setup\.py$'
eco pipenv '(^|/)Pipfile$'
list '(^|/)pyproject\.toml$' | while read -r f; do
  if grep -q '^\[tool\.poetry\]' "$f"; then say "poetry: $f"; else say "pep621: $f"; fi
done
eco cargo '(^|/)Cargo\.toml$'
eco bundler '(^|/)Gemfile$'
eco dockerfile '((^|/|\.)([Dd]ocker|[Cc]ontainer)file$|(^|/)([Dd]ocker|[Cc]ontainer)file[^/]*$)'
eco pre-commit '(^|/)\.pre-commit-config\.yaml$'
eco github-actions '^\.github/(workflows/[^/]+|actions/.+/action)\.ya?ml$'
eco helmv3 '(^|/)Chart\.yaml$'
eco terraform '\.tf$'
say "(end of ecosystems)"

say "== Renovate config"
found=""
for c in renovate.json renovate.jsonc renovate.json5 .github/renovate.json .github/renovate.jsonc .github/renovate.json5 .renovaterc .renovaterc.json .renovaterc.jsonc .renovaterc.json5; do
  [ -f "$c" ] && found="$found $c"
done
if [ -f package.json ] && grep -q '"renovate"[[:space:]]*:' package.json; then found="$found package.json(renovate-key)"; fi
if [ -n "$found" ]; then
  say "config_files:$found"
  for c in $found; do
    case "$c" in package.json*) continue ;; esac
    say "-- $c, notable lines:"
    grep -n -E '"(extends|baseBranchPatterns|baseBranches|minimumReleaseAge|automerge|packageRules|osvVulnerabilityAlerts|enabledManagers|schedule)"' "$c" | sed 's/^/   /'
    grep -o -E '"(github|gitlab|local)>[^"]+"' "$c" | sed 's/^/   extends preset: /'
  done
else
  say "config_files: none"
fi

say "== GitHub Actions in use (action, pin style, occurrences)"
if list '^\.github/(workflows/[^/]+|actions/.+/action)\.ya?ml$' >/dev/null; then
  list '^\.github/(workflows/[^/]+|actions/.+/action)\.ya?ml$' | while read -r wf; do
    grep -h -E '^[[:space:]]*-?[[:space:]]*uses:' "$wf"
  done \
  | sed -E 's/^[[:space:]]*-?[[:space:]]*uses:[[:space:]]*//; s/^"//; s/"[[:space:]]*$//' \
  | grep -v -E '^(\./|docker://)' \
  | awk '{
      ref=$1; split(ref, a, "@"); name=a[1]; r=a[2];
      style = (r ~ /^[0-9a-f]{40}$/ || r ~ /^[0-9a-f]{64}$/) ? "sha" : "tag";
      if (style == "sha") style = ($2 == "#") ? "sha+version-comment" : "sha-no-comment";
      if (name ~ /\.github\/workflows\//) style = "reusable-workflow " style;
      c[name " " style]++
    }
    END { for (k in c) print k, c[k] }' | sort
  v=$(grep -l -E 'renovate-config-validator' .github/workflows/*.yml .github/workflows/*.yaml 2>/dev/null | tr '\n' ' ')
  say "validator_workflow: ${v:-none}"
else
  say "workflows: none"
fi

say "== Dependabot"
if [ -f .github/dependabot.yml ]; then
  # Handles both "directory:" and the newer "directories:" list.
  awk '
    /^[[:space:]]*-?[[:space:]]*package-ecosystem:/ {eco=$NF; gsub(/"/, "", eco); mode=""}
    /^[[:space:]]*directory:/ {dir=$NF; gsub(/"/, "", dir); print eco, dir; mode=""}
    /^[[:space:]]*directories:/ {mode="dirs"; next}
    mode=="dirs" && /^[[:space:]]*-[[:space:]]*/ {dir=$NF; gsub(/"/, "", dir); print eco, dir; next}
    mode=="dirs" && /^[[:space:]]*[a-z-]+:/ {mode=""}
  ' .github/dependabot.yml \
  | while read -r eco dir; do
    d="${dir#/}"; [ -z "$d" ] && d=.
    case "$d" in
      *\**) say "$eco $dir: glob, not checked" ;;
      *) if [ -d "$d" ]; then say "$eco $dir: directory exists"; else say "$eco $dir: DIRECTORY MISSING"; fi ;;
    esac
  done
else
  say "dependabot.yml: none"
fi
exit 0

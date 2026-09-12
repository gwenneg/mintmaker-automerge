#!/usr/bin/env bash
# Repo facts for the mintmaker-automerge setup skill. Read-only: it lists
# tracked files and greps a few of them. Runs when the skill loads, from the
# current directory. Every section prints something, so a missing line means
# the script did not get there. Portable: bash 3, POSIX awk/sed/grep.
set -u
say() { printf '%s\n' "$*"; }

git rev-parse --show-toplevel >/dev/null 2>&1 || { say "STATUS: not inside a git repository. Do the checks of Steps 1 to 3 by hand."; exit 0; }
cd "$(git rev-parse --show-toplevel)" || exit 0
FILES=$(git ls-files)
list() { printf '%s\n' "$FILES" | grep -E "$1"; }
CONTAINERFILES='((^|/|\.)([Dd]ocker|[Cc]ontainer)file$|(^|/)([Dd]ocker|[Cc]ontainer)file[^/]*$)'
WORKFLOWS='^\.github/workflows/[^/]+\.ya?ml$'
ACTIONFILES='^\.github/(workflows/[^/]+|actions/.+/action)\.ya?ml$'

say "== Konflux"
konflux=no; n=0
if [ -d .tekton ]; then
  n=$(list '^\.tekton/.*\.ya?ml$' | wc -l | tr -d ' ')
  say "tekton_dir: yes, $n tracked YAML file$([ "$n" = 1 ] || printf s)"
  found_m=""; absent_m=""
  for m in pipelinesascode.tekton.dev appstudio.openshift.io konflux; do
    if grep -rqs "$m" .tekton; then found_m="$found_m $m"; konflux=yes; else absent_m="$absent_m $m"; fi
  done
  say "konflux_markers: found${found_m:- none}; absent${absent_m:- none}"
else
  say "tekton_dir: no"
fi

say "== Tooling"
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then HAVE_GH=yes; else HAVE_GH=no; fi
say "gh: $HAVE_GH"
slug=$(git remote get-url origin 2>/dev/null | sed -E 's#^(https://github\.com/|git@github\.com:|ssh://git@github\.com/)##; s#\.git$##; s#/$##')
case "$slug" in */*) ;; *) slug="" ;; esac
say "github_repo: ${slug:-unknown}"

db=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
[ -z "$db" ] && db=$(git remote show origin 2>/dev/null | sed -n 's/^ *HEAD branch: //p' | head -1)
[ -z "$db" ] && [ "$HAVE_GH" = yes ] && db=$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null)
say "default_branch: ${db:-unknown}"
say "current_branch: $(git symbolic-ref --short HEAD 2>/dev/null || echo unknown)"

say "== Ecosystems (manager: first matching files)"
ROWS=""
row() { ROWS="$ROWS| $1 | $2 |
"; }
# Up to three files in backticks, then "+N" for the rest.
ticks() { awk '{ s=""; for (i=1;i<=NF && i<=3;i++) s = s (i>1?", ":"") "`" $i "`"; if (NF>3) s = s ", +" NF-3; print s }'; }
# eco <manager> <regex> <display name>
eco() {
  f=$(list "$2" | head -5 | tr '\n' ' ')
  [ -n "$f" ] || return 0
  say "$1: $f"
  row "$3" "$(printf '%s' "$f" | ticks)"
}
eco maven '(^|/)pom\.xml$' "Maven"
eco maven-wrapper '(^|/)(mvnw|\.mvn/wrapper/[^/]+)$' "Maven wrapper"
eco gradle '(^|/)build\.gradle(\.kts)?$' "Gradle"
eco gradle-wrapper '(^|/)gradle/wrapper/gradle-wrapper\.properties$' "Gradle wrapper"
eco gomod '(^|/)go\.mod$' "Go modules"
eco npm '(^|/)package\.json$' "npm"
eco pip_requirements '(^|/)requirements[^/]*\.txt$' "Python, requirements"
eco pip_setup '(^|/)setup\.py$' "Python, setup.py"
eco pipenv '(^|/)Pipfile$' "Pipenv"
list '(^|/)pyproject\.toml$' | while read -r f; do
  if grep -q '^\[tool\.poetry\]' "$f"; then say "poetry: $f"; else say "pep621: $f"; fi
done
pyproj=$(list '(^|/)pyproject\.toml$' | head -5 | tr '\n' ' ')
[ -n "$pyproj" ] && row "Python, pyproject" "$(printf '%s' "$pyproj" | ticks)"
eco cargo '(^|/)Cargo\.toml$' "Cargo"
eco bundler '(^|/)Gemfile$' "Bundler"
eco dockerfile "$CONTAINERFILES" "Container images"
eco pre-commit '(^|/)\.pre-commit-config\.yaml$' "pre-commit"
eco github-actions "$ACTIONFILES" "GitHub Actions"
eco helmv3 '(^|/)Chart\.yaml$' "Helm"
eco terraform '\.tf$' "Terraform"
[ "$konflux" = yes ] && row "Konflux pipeline" "\`.tekton/\`, $n file$([ "$n" = 1 ] || printf s)"
[ -n "$ROWS" ] || say "(none)"

# Manual-review candidates, frameworks with their own upgrade track: listed in the Screens section.
CANDS=""
# cand <label> <file regex> <content regex>
cand() {
  hit=$(list "$2" | while read -r p; do grep -q -E "$3" "$p" && printf x; done)
  [ -n "$hit" ] && CANDS="$CANDS$1; "
}
cand 'io.quarkus* (Quarkus, LTS track)' '(^|/)(pom\.xml|build\.gradle(\.kts)?)$' 'io\.quarkus'
cand 'org.springframework.boot* (Spring Boot)' '(^|/)(pom\.xml|build\.gradle(\.kts)?)$' 'org\.springframework\.boot'
cand 'django (Django, LTS track)' '(^|/)(requirements[^/]*\.txt|pyproject\.toml|Pipfile)$' '^[Dd]jango'
cand '@angular/* (Angular, LTS track)' '(^|/)package\.json$' '"@angular/core"'

# Base images, one line per FROM, minus stage names, scratch and variables; the image is the first word after the flags.
# A function rather than an inline loop: bash 3 cannot parse a case statement inside $( ).
bases() {
  list "$CONTAINERFILES" | while read -r df; do
    froms=$(grep -i -E '^[[:space:]]*FROM[[:space:]]' "$df")
    stages=$(printf '%s\n' "$froms" | grep -i -o -E '[[:space:]]AS[[:space:]]+[A-Za-z0-9_.-]+' | awk '{print $2}' | tr '\n' ' ')
    printf '%s\n' "$froms" | awk '{ for (i=2; i<=NF; i++) if ($i !~ /^--/) { print $i; break } }' | while read -r img; do
      case " $stages " in *" $img "*) continue ;; esac
      case "$img" in scratch|'$'*) continue ;; *@sha256:*) pin="digest-pinned" ;; *) pin="tag only, no digest" ;; esac
      say "$df: $img ($pin)"
    done
  done
}
BASES=$(bases)

say "== Other updaters (Step 7: Dependabot entries, and workflows that update base images on their own)"
# A workflow that mentions base images outside comments and writes changes back (a PR action or a push).
ou=$(list "$WORKFLOWS" | while read -r wf; do
  grep -v -E '^[[:space:]]*#' "$wf" | grep -q -i -E 'base[- _]?image' \
    && grep -v -E '^[[:space:]]*#' "$wf" | grep -q -i -E 'create-pull-request|git push|gh pr create|git commit' && printf '%s ' "$wf"
done)
say "base_image_workflows: ${ou:-none}"
if [ -f .github/dependabot.yml ]; then
  # Handles both "directory:" and the newer "directories:" list.
  entries=$(awk '
    /^[[:space:]]*-?[[:space:]]*package-ecosystem:/ { eco=$NF; gsub(/"/, "", eco); dirs=0 }
    /^[[:space:]]*directory:/ { d=$NF; gsub(/"/, "", d); print eco, d; dirs=0 }
    /^[[:space:]]*directories:/ { dirs=1; next }
    dirs && /^[[:space:]]*-[[:space:]]*/ { d=$NF; gsub(/"/, "", d); print eco, d; next }
    dirs && /^[[:space:]]*[a-z-]+:/ { dirs=0 }
  ' .github/dependabot.yml)
  n_dep=$(printf '%s\n' "$entries" | grep -c .)
  say "dependabot.yml: found, $n_dep entr$([ "$n_dep" = 1 ] && printf y || printf ies) (ecosystem, directory, status):"
  printf '%s\n' "$entries" | while read -r eco dir; do
    d="${dir#/}"; [ -z "$d" ] && d=.
    case "$d" in
      *\**) say "  - $eco $dir, glob, not checked" ;;
      *) if [ -d "$d" ]; then say "  - $eco $dir, directory exists"; else say "  - $eco $dir, DIRECTORY MISSING"; fi ;;
    esac
  done
else
  say "dependabot.yml: none"
fi

say "== Renovate config"
# JSON5 allows bare keys and single-quoted strings, so a key or a preset may come with any quote or none.
Q="[\"']"
key() { printf '(^|[^A-Za-z0-9_])%s?(%s)%s?[[:space:]]*:' "$Q" "$1" "$Q"; }
found=""
for c in renovate.json renovate.jsonc renovate.json5 .github/renovate.json .github/renovate.jsonc .github/renovate.json5 .renovaterc .renovaterc.json .renovaterc.jsonc .renovaterc.json5; do
  [ -f "$c" ] && found="$found $c"
done
[ -f package.json ] && grep -q '"renovate"[[:space:]]*:' package.json && found="$found package.json(renovate-key)"
CFGTABLE=""; CFGKEPT=""
if [ -n "$found" ]; then
  say "config_files:$found"
  for c in $found; do
    case "$c" in package.json*) continue ;; esac
    say "-- $c, full content:"
    cat -n "$c"
    named=$(list . | grep -v "^$c$" | while read -r f; do grep -q -F "${c##*/}" "$f" && printf '%s ' "$f"; done)
    say "-- $c is named in: ${named:-no other file}"
    # Shared presets from other GitHub repos, fetched so Step 2 needs no command.
    grep -o -E "${Q}github>[^\"']+$Q" "$c" | tr -d "\"'" | grep -v 'konflux-ci/mintmaker//' | sort -u | while read -r preset; do
      spec="${preset#github>}"; ref="${spec##*#}"; [ "$ref" = "$spec" ] && ref=""; spec="${spec%%#*}"
      case "$spec" in
        *//*) repo="${spec%%//*}"; path="${spec#*//}" ;;
        *:*)  repo="${spec%%:*}"; path="${spec#*:}.json" ;;
        *)    repo="$spec"; path="default.json" ;;
      esac
      say "-- preset $preset ($repo, $path${ref:+, ref $ref}):"
      body=""
      for cand in "$path" "${path%.json}.json5"; do
        [ -n "$body" ] && break
        body=$(curl -fsSL --max-time 10 "https://raw.githubusercontent.com/$repo/${ref:-HEAD}/$cand" 2>/dev/null)
        [ -z "$body" ] && [ "$HAVE_GH" = yes ] && body=$(gh api "repos/$repo/contents/$cand${ref:+?ref=$ref}" --jq .content 2>/dev/null | base64 -d 2>/dev/null)
      done
      if [ -n "$body" ]; then printf '%s\n' "$body" | sed 's/^/   /'; else say "   (not fetched: the repo may be private; read it by hand in Step 2, with gh api if available)"; fi
    done
    # Rows for the Step 2 table: the two known removals, the presets to read, the rest kept.
    CFGTABLE="$CFGTABLE$(awk -v f="$c" -v q="$Q" -v nq="[^\"']+" '
      function r(what, happens) { printf "| %s:%d | %s | %s |\n", f, NR, what, happens }
      function key(n) { return "(^|[^A-Za-z0-9_])" q "?(" n ")" q "?[[:space:]]*:" }
      $0 ~ (q "github>konflux-ci/mintmaker//config/renovate/renovate\\.json" q) { r("`extends` MintMaker global config", "⚠️ removed, MintMaker already applies it to every onboarded repo") }
      { rest=$0
        while (match(rest, q "(github|gitlab|local)>" nq q)) {
          p=substr(rest, RSTART, RLENGTH); rest=substr(rest, RSTART+RLENGTH)
          if (p !~ /konflux-ci\/mintmaker\/\/config/) r("extends preset " p, "read and reported below")
        } }
      $0 ~ key("baseBranchPatterns|baseBranches") { r("`baseBranchPatterns`", "⚠️ removed, MintMaker sets it per Konflux component") }
      $0 ~ key("minimumReleaseAge") { r("`minimumReleaseAge`", "⚠️ redundant, MintMaker sets it globally; removed") }
      $0 ~ key("enabledManagers") { r("`enabledManagers`", "⚠️ replaces MintMaker'"'"'s whole manager list; removed unless that was intended") }
    ' "$c")
"
    grep -q -E "$(key packageRules)" "$c" && CFGKEPT="Existing package rules are kept and reviewed with the new ones."
  done
else
  say "config_files: none"
fi

# GitHub Actions in use, shown in the Step 4 table.
ACTIONS=""; WORKFLOWS_FOUND=no
if list "$ACTIONFILES" >/dev/null; then
  WORKFLOWS_FOUND=yes
  ACTIONS=$(list "$ACTIONFILES" | while read -r wf; do grep -h -E '^[[:space:]]*-?[[:space:]]*uses:' "$wf"; done | awk '
    { sub(/^[[:space:]]*-?[[:space:]]*uses:[[:space:]]*/, ""); gsub(/["'"'"']/, "", $1)
      if ($1 ~ /^(\.\/|docker:\/\/)/) next
      split($1, a, "@"); name=a[1]; r=a[2]
      style = (r ~ /^[0-9a-f]{40}$/ || r ~ /^[0-9a-f]{64}$/) ? ($2 == "#" ? "sha+version-comment" : "sha-no-comment") : "tag"
      if (name ~ /\.github\/workflows\//) style = "reusable-workflow " style
      c[name " " style]++ }
    END { for (k in c) print k, c[k] }' | sort)
fi

say "== Konflux names (derived from .tekton/, verify on the first MintMaker PR)"
list '^\.tekton/.*\.ya?ml$' | while read -r f; do
  grep -q -E 'pipelinesascode\.tekton\.dev/on-(event|cel-expression).*pull_request' "$f" || continue
  pr=$(awk '/^metadata:/{m=1} m && /^  name:/{print $2; exit}' "$f")
  pf=""; grep -q -E 'on-cel-expression.*files\.' "$f" && pf=" (path-filtered: runs only when matching files change, so it cannot be required)"
  [ -n "$pr" ] && say "pr_pipeline_check: Red Hat Konflux / $pr$pf"
done

say "== Workflow jobs (GitHub check names, for Step 9; matrix jobs appear as 'Name (value)')"
[ "$WORKFLOWS_FOUND" = yes ] || say "workflows: none"
list "$WORKFLOWS" | while read -r wf; do
  awk -v wf="$wf" '
    function unq(s) { gsub(/^["'"'"']|["'"'"']$/, "", s); return s }
    function flush(   n, tag) {
      if (job == "") return
      n = (name != "") ? name : job
      tag = reusable ? " (calls a reusable workflow: its jobs appear as \"" n " / <job>\")" : (matrix ? " (matrix)" : "")
      if (tolower(n) ~ /grype|syft|sbom|snyk|trivy|vulnerab|security|codeql|scan/) tag = tag " [scanner: never require]"
      if (tolower(wf) ~ /renovate-config-validator/ || tolower(n) ~ /renovate config validator/) tag = tag " [validator: never require]"
      printf "%s: %s%s\n", wf, n, tag
    }
    /^jobs:/ { injobs=1; next }
    injobs && /^[A-Za-z_]/ { injobs=0 }
    injobs && /^  [A-Za-z0-9_-]+:[[:space:]]*$/ { flush(); job=$1; sub(/:$/, "", job); name=""; matrix=0; reusable=0; next }
    injobs && job != "" && /^    name:/ { name=$0; sub(/^    name:[[:space:]]*/, "", name); name=unq(name) }
    injobs && job != "" && /^    strategy:/ { matrix=1 }
    injobs && job != "" && /^    uses:/ { reusable=1 }
    END { flush() }
  ' "$wf"
done

say "== Validator (the config validator workflow and the action it runs)"
v=$(grep -l -E 'renovate-config-validator' .github/workflows/*.yml .github/workflows/*.yaml 2>/dev/null | tr '\n' ' ')
say "validator_workflow: ${v:-none}"
vsha=$(git ls-remote https://github.com/konflux-ci/renovate-config-validator-action.git refs/heads/main 2>/dev/null | cut -f1)
say "validator_action_main_sha: ${vsha:-unknown (offline? fetch with: git ls-remote https://github.com/konflux-ci/renovate-config-validator-action.git refs/heads/main)}"

# table <title> <header row>: a blank line, the section title, the header and its separator.
table() { say ""; say "== $1"; say "$2"; say "$(printf '%s' "$2" | awk -F'|' '{ s="|"; for (i=2; i<NF; i++) s=s "---|"; print s }')"; }
say "== Screens (print verbatim in Step 1)"
say "### ▶️ Step 1/10 Detected ecosystems"
if [ "$konflux" != yes ]; then
  say "🛑 No \`.tekton/\` folder with Konflux markers, so this repo is not onboarded in Konflux and MintMaker does not run on it. This skill stops here: its rules build on MintMaker's global config, which nothing would apply. Onboarding: https://konflux-ci.dev/docs/"
  exit 0
fi
say "\`.tekton/\` holds $n pipeline file$([ "$n" = 1 ] || printf s) with Konflux markers."
say ""
say "Default branch: \`${db:-unknown}\`"
say ""
say "| Ecosystem | Found in |"
say "|---|---|"
printf '%s' "$ROWS"
if [ -z "$ACTIONS" ]; then
  say ""; say "== Actions table (print verbatim in Step 4)"; say "$([ "$WORKFLOWS_FOUND" = yes ] && echo "workflows: found, no action used" || echo "workflows: none")"
else
  table "Actions table (print verbatim in Step 4)" "| Action | Maintained by | Pinned by |"
  say "$ACTIONS" | awk '{
    rw = ($2 == "reusable-workflow"); style = rw ? $3 : $2
    if (style ~ /^sha\+version-comment/) s="SHA + version comment"
    else if (style ~ /^sha-no-comment/) s="bare SHA, ⚠️ no version comment"
    else if (style ~ /^tag/) s="tag"
    else s=style
    if (rw) s = s ", reusable workflow"
    split($1, o, "/")
    printf "| %s | %s | %s |\n", $1, (o[1] == "actions" || o[1] == "github") ? "GitHub" : "third party (" o[1] ")", s
  }'
fi
if [ -z "$BASES" ]; then
  say ""; say "== Base images table (print verbatim in Step 5)"; say "base_images: none"
else
  table "Base images table (print verbatim in Step 5)" "| Base image | Container files | Pinned by |"
  # one row per image, with the files that use it, in order of first appearance
  say "$BASES" | awk -F': ' '{ img=$2; sub(/ \([^)]*\)$/, "", img); if (!(img in seen)) { seen[img]=1; order[++k]=img }
      if (index(files[img], "`" $1 "`") == 0) files[img] = files[img] (files[img] == "" ? "" : ", ") "`" $1 "`" }
    END { for (i=1; i<=k; i++) print order[i] "\t" files[order[i]] }' | while IFS="$(printf '\t')" read -r img files; do
    case "$img" in
      *@sha256:*) pin="digest, updates arrive as digest PRs"; shown=$(printf '%s' "$img" | sed -E 's/@sha256:[0-9a-f]{12}[0-9a-f]*/@sha256:…/') ;;
      *:latest)   pin="tag \`latest\` ⚠️ nothing to bump; only a digest pin brings updates"; shown="$img" ;;
      *:*)        pin="tag, no digest"; shown="$img" ;;
      *)          pin="no tag, means \`latest\` ⚠️ nothing to bump; only a digest pin brings updates"; shown="$img" ;;
    esac
    say "| \`$shown\` | $files | $pin |"
  done
fi
if [ -n "$found" ]; then
  if [ -n "$(printf '%s' "$CFGTABLE" | tr -d '[:space:]')" ]; then
    table "Renovate config table (print verbatim in Step 2)" "| Where | Setting | What happens |"
    printf '%s' "$CFGTABLE" | sed '/^$/d'
  else
    say ""; say "== Renovate config table (print verbatim in Step 2)"; say "Nothing to remove from the existing config."
  fi
  [ -n "$CFGKEPT" ] && say "$CFGKEPT"
fi
say ""
say "== Manual-review candidates (the first Exceptions option of Step 3)"
if [ -n "$CANDS" ]; then printf '%s\n' "$CANDS" | tr ';' '\n' | sed -E 's/^ *//; /^$/d; s/^/- /'; else say "(none)"; fi
exit 0

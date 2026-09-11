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
konflux=no; n=0
if [ -d .tekton ]; then
  n=$(list '^\.tekton/.*\.ya?ml$' | wc -l | tr -d ' ')
  say "tekton_dir: yes, $n tracked YAML files"
  for m in pipelinesascode.tekton.dev appstudio.openshift.io konflux; do
    if grep -rqs "$m" .tekton; then say "marker $m: found"; konflux=yes; else say "marker $m: absent"; fi
  done
else
  say "tekton_dir: no"
fi

say "== Tooling"
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then HAVE_GH=yes; else HAVE_GH=no; fi
say "gh: $HAVE_GH (optional: with it Step 10 opens the PR itself, without it the user opens it from a link)"
origin=$(git remote get-url origin 2>/dev/null)
slug=$(printf '%s' "$origin" | sed -E 's#^(https://github\.com/|git@github\.com:|ssh://git@github\.com/)##; s#\.git$##; s#/$##')
case "$slug" in */*) ;; *) slug="" ;; esac
say "github_repo: ${slug:-unknown}"

say "== Default branch"
db=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
[ -z "$db" ] && db=$(git remote show origin 2>/dev/null | sed -n 's/^ *HEAD branch: //p' | head -1)
if [ -z "$db" ] && [ "$HAVE_GH" = yes ]; then
  db=$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null)
fi
say "default_branch: ${db:-unknown}"

say "== Ecosystems (manager: first matching files)"
ROWS=""
LIB="🟢 patch and minor bumps"; WRAP="🛑 build tool, stays manual"; NORULE="🛑 no rule in this skill, stays manual"
row() { ROWS="$ROWS| $1 | $2 |
"; }
# eco <manager> <regex> <display name> <scope>
eco() {
  f=$(list "$2" | head -5 | tr '\n' ' ')
  [ -n "$f" ] || return 0
  say "$1: $f"
  shown=$(printf '%s' "$f" | awk '{ s=""; for (i=1;i<=NF && i<=3;i++) s = s (i>1?", ":"") "`" $i "`"; if (NF>3) s = s ", +" NF-3; print s }')
  row "$3" "$shown" "$4"
}
eco maven '(^|/)pom\.xml$' "Maven" "$LIB"
eco maven-wrapper '(^|/)(mvnw|\.mvn/wrapper/[^/]+)$' "Maven wrapper" "$WRAP"
eco gradle '(^|/)build\.gradle(\.kts)?$' "Gradle" "$LIB"
eco gradle-wrapper '(^|/)gradle/wrapper/gradle-wrapper\.properties$' "Gradle wrapper" "$WRAP"
eco gomod '(^|/)go\.mod$' "Go modules" "$LIB"
eco npm '(^|/)package\.json$' "npm" "$LIB"
eco pip_requirements '(^|/)requirements[^/]*\.txt$' "Python, requirements" "$LIB"
eco pip_setup '(^|/)setup\.py$' "Python, setup.py" "$LIB"
eco pipenv '(^|/)Pipfile$' "Pipenv" "$LIB"
list '(^|/)pyproject\.toml$' | while read -r f; do
  if grep -q '^\[tool\.poetry\]' "$f"; then say "poetry: $f"; else say "pep621: $f"; fi
done
pyproj=$(list '(^|/)pyproject\.toml$' | head -3 | tr '\n' ' ')
[ -n "$pyproj" ] && row "Python, pyproject" "$(printf '%s' "$pyproj" | sed 's/ *$//; s/ /`, `/g; s/^/`/; s/$/`/')" "$LIB"
eco cargo '(^|/)Cargo\.toml$' "Cargo" "$LIB"
eco bundler '(^|/)Gemfile$' "Bundler" "$LIB"
eco dockerfile '((^|/|\.)([Dd]ocker|[Cc]ontainer)file$|(^|/)([Dd]ocker|[Cc]ontainer)file[^/]*$)' "Container images" "🛑 runtime under every test, stays manual"
eco pre-commit '(^|/)\.pre-commit-config\.yaml$' "pre-commit" "$NORULE"
eco github-actions '^\.github/(workflows/[^/]+|actions/.+/action)\.ya?ml$' "GitHub Actions" "🟢 allow-list of actions"
eco helmv3 '(^|/)Chart\.yaml$' "Helm" "$NORULE"
eco terraform '\.tf$' "Terraform" "$NORULE"
[ "$konflux" = yes ] && row "Konflux pipeline" "\`.tekton/\`, $n files" "🟢 task bumps and migrations"
say "(end of ecosystems)"

say "== Manual-review candidates (frameworks with their own upgrade track)"
CANDS=""
cand() {
  f=$(list "$2" | while read -r p; do grep -q -E "$3" "$p" && printf '%s ' "$p"; done)
  [ -n "$f" ] && { say "$1: $f"; CANDS="$CANDS$1; "; }
}
cand 'io.quarkus* (Quarkus, LTS track)' '(^|/)(pom\.xml|build\.gradle(\.kts)?)$' 'io\.quarkus'
cand 'org.springframework.boot* (Spring Boot)' '(^|/)(pom\.xml|build\.gradle(\.kts)?)$' 'org\.springframework\.boot'
cand 'django (Django, LTS track)' '(^|/)(requirements[^/]*\.txt|pyproject\.toml|Pipfile)$' '^[Dd]jango'
cand '@angular/* (Angular, LTS track)' '(^|/)package\.json$' '"@angular/core"'
say "(end of candidates)"

say "== Base images (FROM lines of container files: image, pin style)"
BASES=""; UNPINNED=0
list '((^|/|\.)([Dd]ocker|[Cc]ontainer)file$|(^|/)([Dd]ocker|[Cc]ontainer)file[^/]*$)' | while read -r df; do
  stages=$(grep -i -E '^[[:space:]]*FROM[[:space:]]' "$df" | grep -i -o -E '[[:space:]]AS[[:space:]]+[A-Za-z0-9_.-]+' | awk '{print $2}' | tr '\n' ' ')
  grep -i -E '^[[:space:]]*FROM[[:space:]]' "$df" | while read -r _ img _; do
    case " $stages " in *" $img "*) continue ;; esac
    case "$img" in scratch|'$'*) continue ;; esac
    if printf '%s' "$img" | grep -q '@sha256:'; then pin="digest-pinned"; else pin="tag only, no digest"; fi
    say "$df: $img ($pin)"
  done
done > "${TMPDIR:-/tmp}/mm-bases.$$"
cat "${TMPDIR:-/tmp}/mm-bases.$$"
[ -s "${TMPDIR:-/tmp}/mm-bases.$$" ] || say "base_images: none"

say "== Other updaters (workflows that update base images on their own)"
ou=$(list '^\.github/workflows/[^/]+\.ya?ml$' | while read -r wf; do
  # Mentions base images outside comments, and writes changes back (a PR action or a push).
  if grep -v -E '^[[:space:]]*#' "$wf" | grep -q -i -E 'base[- _]?image' \
     && grep -v -E '^[[:space:]]*#' "$wf" | grep -q -i -E 'create-pull-request|git push|gh pr create|git commit'; then
    printf '%s ' "$wf"
  fi
done)
say "base_image_workflows: ${ou:-none}"

say "== Renovate config"
found=""
for c in renovate.json renovate.jsonc renovate.json5 .github/renovate.json .github/renovate.jsonc .github/renovate.json5 .renovaterc .renovaterc.json .renovaterc.jsonc .renovaterc.json5; do
  [ -f "$c" ] && found="$found $c"
done
if [ -f package.json ] && grep -q '"renovate"[[:space:]]*:' package.json; then found="$found package.json(renovate-key)"; fi
CFGTABLE=""; CFGKEPT=""
if [ -n "$found" ]; then
  say "config_files:$found"
  for c in $found; do
    case "$c" in package.json*) continue ;; esac
    say "-- $c, notable lines:"
    grep -n -E '"(extends|baseBranchPatterns|baseBranches|minimumReleaseAge|automerge|packageRules|osvVulnerabilityAlerts|enabledManagers|schedule)"' "$c" | sed 's/^/   /'
    grep -o -E '"(github|gitlab|local)>[^"]+"' "$c" | sed 's/^/   extends preset: /'
    say "-- $c, full content:"
    cat -n "$c"
    # Shared presets from other GitHub repos, fetched so Step 2 needs no command.
    grep -o -E '"github>[^"]+"' "$c" | tr -d '"' | grep -v 'konflux-ci/mintmaker//' | sort -u | while read -r preset; do
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
    CFGTABLE="$CFGTABLE$(awk -v f="$c" '
      {
        line=$0
        if (line ~ /"github>konflux-ci\/mintmaker\/\/config\/renovate\/renovate\.json"/)
          printf "| %s:%d | `extends` MintMaker global config | ⚠️ removed, MintMaker already applies it to every onboarded repo |\n", f, NR
        rest=line
        while (match(rest, /"(github|gitlab|local)>[^"]+"/)) {
          pre=substr(rest, RSTART, RLENGTH); rest=substr(rest, RSTART+RLENGTH)
          if (pre !~ /konflux-ci\/mintmaker\/\/config/) printf "| %s:%d | extends preset %s | read and reported below |\n", f, NR, pre
        }
        if (line ~ /"baseBranchPatterns"|"baseBranches"/) printf "| %s:%d | `baseBranchPatterns` | ⚠️ removed, MintMaker sets it per Konflux component |\n", f, NR
        if (line ~ /"minimumReleaseAge"/) printf "| %s:%d | `minimumReleaseAge` | ⚠️ redundant, MintMaker sets it globally; removed |\n", f, NR
        if (line ~ /"enabledManagers"/) printf "| %s:%d | `enabledManagers` | ⚠️ replaces MintMaker'"'"'s whole manager list; removed unless that was intended |\n", f, NR
      }
    ' "$c")
"
    grep -q '"packageRules"' "$c" && CFGKEPT="Existing package rules are kept and reviewed with the new ones."
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
    END { for (k in c) print k, c[k] }' | sort > "${TMPDIR:-/tmp}/mm-actions.$$"
  cat "${TMPDIR:-/tmp}/mm-actions.$$"
  v=$(grep -l -E 'renovate-config-validator' .github/workflows/*.yml .github/workflows/*.yaml 2>/dev/null | tr '\n' ' ')
  say "validator_workflow: ${v:-none}"
else
  say "workflows: none"
fi

say "== Konflux names (derived from .tekton/, verify on the first MintMaker PR)"
if [ -d .tekton ]; then
  list '^\.tekton/.*\.ya?ml$' | while read -r f; do
    if grep -q -E 'pipelinesascode\.tekton\.dev/on-(event|cel-expression).*pull_request' "$f"; then
      n=$(awk '/^metadata:/{m=1} m && /^  name:/{print $2; exit}' "$f")
      if grep -q -E 'on-cel-expression.*files\.' "$f"; then pf=" (path-filtered: runs only when matching files change, so it cannot be required)"; else pf=""; fi
      [ -n "$n" ] && say "pr_pipeline_check: Red Hat Konflux / $n$pf"
    fi
  done
fi

say "== Workflow jobs (GitHub check names, for Step 9; matrix jobs appear as 'Name (value)')"
list '^\.github/workflows/[^/]+\.ya?ml$' | while read -r wf; do
  awk -v wf="$wf" '
    /^name:/ { wfname=$0; sub(/^name:[[:space:]]*/, "", wfname); gsub(/^["'"'"']|["'"'"']$/, "", wfname) }
    /^jobs:/ { injobs=1; next }
    injobs && /^[A-Za-z_]/ { injobs=0 }
    injobs && /^  [A-Za-z0-9_-]+:[[:space:]]*$/ { flush(); job=$1; sub(/:$/, "", job); name=""; matrix=0; reusable=0; next }
    injobs && job != "" && /^    name:/ { name=$0; sub(/^    name:[[:space:]]*/, "", name); gsub(/^["'"'"']|["'"'"']$/, "", name) }
    injobs && job != "" && /^    strategy:/ { matrix=1 }
    injobs && job != "" && /^    uses:/ { reusable=1 }
    function flush(   n, tag) {
      if (job == "") return
      n = (name != "") ? name : job
      tag = ""
      if (reusable) tag = " (calls a reusable workflow: its jobs appear as \"" n " / <job>\")"
      else if (matrix) tag = " (matrix)"
      if (tolower(n) ~ /grype|syft|sbom|snyk|trivy|vulnerab|security|codeql|scan/) tag = tag " [scanner: never require]"
      if (tolower(wf) ~ /renovate-config-validator/ || tolower(n) ~ /renovate config validator/) tag = tag " [validator: never require]"
      printf "%s: %s%s\n", wf, n, tag
    }
    END { flush() }
  ' "$wf"
done
say "(end of workflow jobs)"

say "== Validator action"
vsha=$(git ls-remote https://github.com/konflux-ci/renovate-config-validator-action.git refs/heads/main 2>/dev/null | cut -f1)
say "validator_action_main_sha: ${vsha:-unknown (offline? fetch with: git ls-remote https://github.com/konflux-ci/renovate-config-validator-action.git refs/heads/main)}"

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

say "== Screens (print verbatim in Step 1)"
say "### ▶️ Step 1/10 Detected ecosystems"
if [ "$konflux" = yes ]; then
  say "\`.tekton/\` holds $n pipeline files with Konflux markers."
  say ""
  say "Default branch: \`${db:-unknown}\`"
  say ""
  say "| Ecosystem | Found in |"
  say "|---|---|"
  printf '%s' "$ROWS"
  if [ -s "${TMPDIR:-/tmp}/mm-actions.$$" ]; then
    say ""
    say "== Actions table (print verbatim in Step 4)"
    say "| Action | Maintained by | Pinned by |"
    say "|---|---|---|"
    awk '{
      name=$1; style=$2; n=$NF;
      if (style == "reusable-workflow") { style = $3 " (reusable workflow)" }
      if (style ~ /^sha\+version-comment/) s="SHA + version comment";
      else if (style ~ /^sha-no-comment/) s="bare SHA, ⚠️ no version comment";
      else if (style ~ /^tag/) s="tag";
      else s=style;
      if (style ~ /reusable/) s = s ", reusable workflow";
      split(name, o, "/"); owner=o[1];
      m = (owner == "actions" || owner == "github") ? "GitHub" : "third party (" owner ")";
      printf "| %s | %s | %s |\n", name, m, s
    }' "${TMPDIR:-/tmp}/mm-actions.$$"
  fi
  if [ -s "${TMPDIR:-/tmp}/mm-bases.$$" ]; then
    say ""
    say "== Base images table (print verbatim in Step 5)"
    say "| Base image | Container files | Pinned by |"
    say "|---|---|---|"
    sed -E 's/^([^:]+): (.*) \((.*)\)$/\2/' "${TMPDIR:-/tmp}/mm-bases.$$" | sort | uniq -c | sort -rn | while read -r cnt img; do
      case "$img" in
        *@sha256:*) pin="digest, updates arrive as digest PRs"; shown=$(printf '%s' "$img" | sed -E 's/@sha256:[0-9a-f]{12}[0-9a-f]*/@sha256:…/') ;;
        *:latest)   pin="tag \`latest\` ⚠️ nothing to bump; only a digest pin brings updates"; shown="$img" ;;
        *:*)        pin="tag, no digest"; shown="$img" ;;
        *)          pin="no tag, means \`latest\` ⚠️ nothing to bump; only a digest pin brings updates"; shown="$img" ;;
      esac
      say "| \`$shown\` | $cnt | $pin |"
    done
  fi
  if [ -n "$found" ]; then
    say ""
    say "== Renovate config table (print verbatim in Step 2)"
    if [ -n "$(printf '%s' "$CFGTABLE" | tr -d '[:space:]')" ]; then
      say "| Where | Setting | What happens |"
      say "|---|---|---|"
      printf '%s' "$CFGTABLE" | sed '/^$/d'
    else
      say "Nothing to remove from the existing config."
    fi
    [ -n "${CFGKEPT:-}" ] && say "$CFGKEPT"
  fi
  if [ -n "$CANDS" ]; then
    say ""
    say "== Manual-review candidates (the first Exceptions option of Step 3)"
    printf '%s\n' "$CANDS" | tr ';' '\n' | sed -E 's/^ *//; /^$/d; s/^/- /'
  fi
else
  say "🛑 No \`.tekton/\` folder with Konflux markers, so this repo is not onboarded in Konflux and MintMaker does not run on it. This skill stops here: its rules build on MintMaker's global config, which nothing would apply. Onboarding: https://konflux-ci.dev/docs/"
fi
rm -f "${TMPDIR:-/tmp}/mm-actions.$$" "${TMPDIR:-/tmp}/mm-bases.$$"
exit 0

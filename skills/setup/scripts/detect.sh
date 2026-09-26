#!/usr/bin/env bash
# Repo facts for the mintmaker-automerge setup skill. Read-only: it lists
# tracked files and greps a few of them. Runs when the skill loads, from the
# current directory. Every section prints something, so a missing line means
# the script did not get there. Portable: bash 3, POSIX awk/sed/grep.
set -u
say() { printf '%s\n' "$*"; }

git rev-parse --show-toplevel >/dev/null 2>&1 || { say "STATUS: not inside a git repository. Do the checks of Steps 1 to 4 by hand."; exit 0; }
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
# The oc client, for the Step 2 how-to: installed or not, with its version when it is.
if command -v oc >/dev/null 2>&1; then say "oc: yes ($(oc version --client 2>/dev/null | head -1 | sed 's/^Client Version: *//'))"; else say "oc: no (not on the PATH)"; fi
# The repository whose settings and PR matter: the upstream when the clone is a fork.
remote_slug() { git remote get-url "$1" 2>/dev/null | sed -E 's#^(https://github\.com/|git@github\.com:|ssh://git@github\.com/)##; s#\.git$##; s#/$##' | grep -E '^[^/]+/[^/]+$'; }
origin_slug=$(remote_slug origin); upstream_slug=$(remote_slug upstream)
slug=$origin_slug; fork=no; fork_via=""
if [ -n "$upstream_slug" ] && [ "$upstream_slug" != "$origin_slug" ]; then
  slug=$upstream_slug; fork=yes; fork_via="the upstream remote"
elif [ -n "$origin_slug" ] && [ "$HAVE_GH" = yes ]; then
  # On an HTTP error gh prints the response body to stdout, so the exit status is the only signal.
  parent=$(gh api "repos/$origin_slug" --jq 'if .fork then .parent.full_name else empty end' 2>/dev/null) || parent=""
  [ -n "$parent" ] && { slug=$parent; fork=yes; fork_via="gh, origin is a fork"; }
fi
say "github_repo: ${slug:-unknown} (the repository the GitHub settings and the PR target)"
say "origin_repo: ${origin_slug:-unknown}"
if [ "$fork" = yes ]; then say "fork: yes (origin is a fork of github_repo, found via $fork_via; the PR branch is pushed to origin, the PR opened on github_repo)"; else say "fork: no"; fi
if ! command -v gh >/dev/null 2>&1; then why="gh is not installed"; elif [ "$HAVE_GH" != yes ]; then why="gh is not logged in"; elif [ -z "$slug" ]; then why="no GitHub remote"; else why="gh cannot read the repository"; fi
role="not checked, $why"; otype=""; api_db=""
if [ -n "$slug" ] && [ "$HAVE_GH" = yes ] && repo_facts=$(gh api "repos/$slug" --jq '(if .permissions == null then "unknown" else (.permissions | if .admin then "admin" elif .maintain then "maintain" elif .push then "write" else "read" end) end) + " " + .owner.type + " " + .default_branch' 2>/dev/null); then
  set -- $repo_facts; role=$1; otype=${2:-}; api_db=${3:-}
fi
say "github_role: $role (the role of the gh login on this repository; rulesets take admin)"

db=""
if [ "$fork" = yes ]; then
  [ -n "$upstream_slug" ] && db=$(git symbolic-ref --short refs/remotes/upstream/HEAD 2>/dev/null | sed 's|^upstream/||')
  [ -z "$db" ] && db=$api_db
fi
[ -z "$db" ] && db=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
[ -z "$db" ] && db=$(git remote show origin 2>/dev/null | sed -n 's/^ *HEAD branch: //p' | head -1)
[ -z "$db" ] && db=$api_db
say "default_branch: ${db:-unknown}"
say "current_branch: $(git symbolic-ref --short HEAD 2>/dev/null || echo unknown)"

say "== Branch rules (Steps 9 and 11: the rulesets on the default branch, read with gh; classic branch protection rules are not read)"
KONFLUX_APP_ID=296509
br=""; checks_id=""; pr_id=""
if [ -n "$slug" ] && [ "$HAVE_GH" = yes ] && [ -n "$db" ]; then
  br=$(gh api "repos/$slug/rules/branches/$db" --jq '([.[] | select(.type=="required_status_checks") | .parameters.required_status_checks[].context] | join(", ")), ([.[] | select(.type=="required_status_checks") | .ruleset_id] | unique | map(tostring) | join(" ")), ([.[] | select(.type=="pull_request") | "\(.ruleset_id):\(.parameters.required_approving_review_count)"] | join(" ")), ([.[] | select(.type=="required_status_checks") | .parameters.strict_required_status_checks_policy] | any)' 2>/dev/null) && br="ok
$br"
fi
if [ -z "$br" ]; then
  say "branch_rules: not checked (takes gh logged in, a GitHub remote and a known default branch)"
  say "up_to_date_required: not checked"
else
  checks=$(printf '%s\n' "$br" | sed -n 2p); check_rs=$(printf '%s\n' "$br" | sed -n 3p); pr_rs=$(printf '%s\n' "$br" | sed -n 4p)
  checks_id=${check_rs%% *}; pr_id=${pr_rs%% *}; pr_id=${pr_id%%:*}; strict=$(printf '%s\n' "$br" | sed -n 5p)
  say "required_checks: ${checks:-none}"
  say "up_to_date_required: $([ "$strict" = true ] && printf yes || printf no) (the rule that a PR branch must be up to date before merging; with yes, rebasing only on conflict would stop every automerge PR, since Renovate never rebases a branch that is behind but not in conflict)"
  rsname() { gh api "repos/$slug/rulesets/$1" --jq .name 2>/dev/null; }
  rsbypass() { gh api "repos/$slug/rulesets/$1" --jq "[.bypass_actors[]? | select(.actor_type==\"Integration\" and .actor_id==$KONFLUX_APP_ID) | .bypass_mode] | join(\",\")" 2>/dev/null; }
  [ -z "$pr_rs" ] && say "approval_rule: none (no pull request rule on $db, nothing to bypass)"
  bypass_rs=""; both=no; need_approval=no; ap_name=""; ap_n=0; ap_bypass=""; ap_holds=no
  for e in $pr_rs; do
    id=${e%%:*}; n=${e#*:}; name=$(rsname "$id"); holds=no
    case " $check_rs " in *" $id "*) holds=yes ;; esac
    say "approval_rule: $n approval(s), ruleset \"$name\", also holds the required checks: $holds"
    b=$(rsbypass "$id")
    if [ -n "$b" ]; then
      case "$b" in *always*) bl="always, wider than the For pull requests only mode the skill recommends" ;; pull_request) bl="For pull requests only" ;; *) bl=$b ;; esac
      bypass_rs="${bypass_rs:+$bypass_rs; }\"$name\", mode: $bl"; [ "$holds" = yes ] && both=yes
    fi
    if [ "$need_approval" = no ] && [ "$n" != 0 ] && [ "$n" != null ]; then need_approval=yes; ap_name=$name; ap_n=$n; ap_bypass=$b; ap_holds=$holds; fi
  done
  say "konflux_bypass: ${bypass_rs:-none} (Red Hat Konflux in the bypass list of a ruleset holding the pull request rule)"
  say "konflux_bypasses_required_checks: $both"
fi

SB=""
say "== Settings status (Step 9 reads status_checks, Step 11 status_bypass; one verdict each, printed verbatim on the Currently lines)"
if [ -z "$br" ]; then
  say "status_checks: not checked, $why"
  SB="not checked, $why"; say "status_bypass: $SB"
else
  if [ -z "$checks" ]; then say "status_checks: ⚠️ none, nothing gates the merge yet"; else say "status_checks: ✅ $(printf '%s' "$checks" | awk -F', ' '{print NF}') required, compare them with the guidance below"; fi
  if [ "$need_approval" = no ]; then SB="✅ no approval rule on $db, nothing to do"; say "status_bypass: $SB"
  elif [ -z "$ap_bypass" ]; then SB="⚠️ The \`$db\` branch of this repository requires $ap_n approval(s) because of the ruleset \"$ap_name\", and Red Hat Konflux is not on its bypass list"; say "status_bypass: $SB"
  else
    case "$ap_holds,$ap_bypass" in
      yes,*always*) SB="⚠️ Red Hat Konflux bypasses \"$ap_name\", which also holds the required checks, in Always allow mode"; say "status_bypass: $SB" ;;
      yes,*) SB="⚠️ Red Hat Konflux bypasses \"$ap_name\", which also holds the required checks"; say "status_bypass: $SB" ;;
      no,*always*) SB="⚠️ Red Hat Konflux bypasses \"$ap_name\" in Always allow mode, wider than needed"; say "status_bypass: $SB" ;;
      *) SB="✅ Red Hat Konflux bypasses \"$ap_name\", For pull requests only, a ruleset without the required checks: in place"; say "status_bypass: $SB" ;;
    esac
  fi
fi

say "== Links (Steps 9 and 11: the GitHub pages where the settings live, built from the remote URL, no gh needed)"
if [ -z "$slug" ]; then
  say "links: none (no GitHub remote)"
else
  say "settings_rulesets: https://github.com/$slug/settings/rules"
  [ -n "$checks_id" ] && say "settings_ruleset_checks: https://github.com/$slug/settings/rules/$checks_id (the ruleset holding the required checks)"
  [ -n "$pr_id" ] && say "settings_ruleset_approval: https://github.com/$slug/settings/rules/$pr_id (the ruleset holding the pull request rule)"
  say "settings_branches: https://github.com/$slug/settings/branches (classic branch protection rules)"
  case "$otype" in
    User) say "settings_org_rulesets: none (the owner is a user account)" ;;
    Organization) say "settings_org_rulesets: https://github.com/organizations/${slug%%/*}/settings/rules (organization owners only, a 404 for a repository admin; printed in Step 11)" ;;
    *) say "settings_org_rulesets: https://github.com/organizations/${slug%%/*}/settings/rules (if the owner is an organization; organization owners only; printed in Step 11)" ;;
  esac
fi

say "== Ecosystems (manager: first matching files)"
ROWS=""; ALLF=""
row() { ROWS="$ROWS| $1 | $2 |
"; }
# Up to three files in backticks, then "+N" for the rest.
ticks() { awk '{ s=""; for (i=1;i<=NF && i<=3;i++) s = s (i>1?", ":"") "`" $i "`"; if (NF>3) s = s ", +" NF-3; print s }'; }
# eco <manager> <regex> <display name>
eco() {
  ALLF="$ALLF$(list "$2")
"
  f=$(list "$2" | head -5 | tr '\n' ' ')
  [ -n "$f" ] || return 0
  say "$1: $f"
  row "$3" "$(printf '%s' "$f" | ticks)"
}
eco maven '(^|/)pom\.xml$' "Maven"
eco gradle '(^|/)build\.gradle(\.kts)?$' "Gradle"
eco gomod '(^|/)go\.mod$' "Go modules"
eco npm '(^|/)package\.json$' "npm"
eco pip_requirements '(^|/)requirements[^/]*\.txt$' "Python, requirements"
eco pip_setup '(^|/)setup\.py$' "Python, setup.py"
eco pipenv '(^|/)Pipfile$' "Pipenv"
list '(^|/)pyproject\.toml$' | while read -r f; do
  if grep -q '^\[tool\.poetry\]' "$f"; then say "poetry: $f"; else say "pep621: $f"; fi
done
ALLF="$ALLF$(list '(^|/)pyproject\.toml$')
"
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
# Dependency files Renovate never reads: the ignorePaths of config:recommended, which MintMaker extends.
ign=$(printf '%s' "$ALLF" | grep -E '(^|/)(node_modules|bower_components|vendor|examples|__tests__|test|tests|__fixtures__)/' | sort -u | tr '\n' ' ')
say "ignored_by_renovate: ${ign:-none}"

# Manual-review candidates, packages with their own upgrade track: listed in the Screens section.
# To add one, add a cand line. The report line becomes the menu description and the rule comment.
CANDS=""
# cand <pattern> <file regex> <content regex> <name> <reason, reading on after the name> <link>
cand() {
  hit=$(list "$2" | while read -r p; do grep -q -E "$3" "$p" && printf x; done)
  [ -n "$hit" ] && CANDS="$CANDS- $4 (\`$1\`): $4 $5. $6
"
}
cand 'io.quarkus*' '(^|/)(pom\.xml|build\.gradle(\.kts)?)$' 'io\.quarkus' 'Quarkus' 'follows an LTS track, so a reviewer picks the target version' https://quarkus.io/releases/
cand 'org.springframework.boot*' '(^|/)(pom\.xml|build\.gradle(\.kts)?)$' 'org\.springframework\.boot' 'Spring Boot' 'pins every managed Spring dependency, so a reviewer picks the target version' 'https://spring.io/projects/spring-boot#support'
cand '/^django$/i' '(^|/)(requirements[^/]*\.txt|pyproject\.toml|Pipfile|setup\.py)$' '[Dd]jango' 'Django' 'follows an LTS track, so a reviewer picks the target version' 'https://www.djangoproject.com/download/#supported-versions'
cand '@angular/*' '(^|/)package\.json$' '"@angular/core"' 'Angular' 'follows an LTS track, so a reviewer picks the target version' https://angular.dev/reference/releases

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

say "== Other updaters (Step 12: Dependabot entries, and workflows that update base images on their own)"
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
    # Shared presets from other GitHub repos, fetched so Step 3 needs no command.
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
      if [ -n "$body" ]; then printf '%s\n' "$body" | sed 's/^/   /'; else say "   (not fetched: the repo may be private; read it by hand in Step 3, with gh api if available)"; fi
    done
    # Rows for the Step 3 table: the two known removals, the presets to read, the rest kept.
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
      $0 ~ key("platformAutomerge") { r("`platformAutomerge`", "⚠️ replaced by false: GitHub'"'"'s auto-merge never completes when a bypass actor meets the approval rule") }
      $0 ~ key("ignoreTests") { r("`ignoreTests`", "⚠️ replaced by the Step 9 gate choice") }
      $0 ~ key("rebaseWhen") { r("`rebaseWhen`", "⚠️ replaced by the Step 10 rebasing choice") }
      $0 ~ key("keepUpdatedLabel") { r("`keepUpdatedLabel`", "⚠️ replaced by the Step 10 rebasing choice") }
      $0 ~ key("groupName") { r("custom `groupName`", "kept, after the ecosystem rule of its manager, so its group stays and automerges with it") }
    ' "$c")
"
    grep -q -E "$(key packageRules)" "$c" && CFGKEPT="Existing package rules are kept and reviewed with the new ones."
  done
else
  say "config_files: none"
fi

# GitHub Actions in use, shown in the Step 6 table.
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

# Facts of one pull-request pipeline, "name|component|application|namespace|branches": the branches from the
# on-target-branch annotation or from every target_branch == "..." of the CEL expression, which PaC may wrap
# over several lines; a matches()/startsWith() test is reported as such; unknown when nothing names a branch.
pr_facts() {
  awk '
    /^metadata:/ { m=1 }
    m && /^  name:/ && name == "" { name=$2 }
    m && /^  namespace:/ { ns=$2 }
    /appstudio\.openshift\.io\/component:/ { comp=$2 }
    /appstudio\.openshift\.io\/application:/ { app=$2 }
    /pipelinesascode\.tekton\.dev\/on-cel-expression:/ { cel=1; s=$0; sub(/.*on-cel-expression:[[:space:]]*/, "", s); expr=s; next }
    cel && (/^[[:space:]]*[A-Za-z0-9._\/-]+:([[:space:]]|$)/ || /^[^[:space:]]/) { cel=0 }
    cel { s=$0; sub(/^[[:space:]]+/, "", s); expr=expr " " s }
    /pipelinesascode\.tekton\.dev\/on-target-branch:/ { s=$0; sub(/.*on-target-branch:[[:space:]]*/, "", s); gsub(/[][" ]/, "", s); tb=s }
    /^spec:/ { m=0; cel=0 }
    END {
      gsub(/"/, "", name); gsub(/"/, "", ns); gsub(/"/, "", comp); gsub(/"/, "", app)
      br=tb
      if (br == "") { s=expr; while (match(s, /target_branch[[:space:]]*==[[:space:]]*"[^"]+"/)) { t=substr(s, RSTART, RLENGTH); sub(/^[^"]*"/, "", t); sub(/"$/, "", t); br=(br == "" ? t : br "," t); s=substr(s, RSTART+RLENGTH) } }
      if (br == "") { s=expr; while (match(s, /target_branch\.(matches|startsWith|endsWith)\("[^"]+"\)/)) { t=substr(s, RSTART, RLENGTH); sub(/^target_branch\./, "", t); br=(br == "" ? t : br "," t); s=substr(s, RSTART+RLENGTH) } }
      if (br == "") br="unknown"
      printf "%s|%s|%s|%s|%s\n", name, comp, app, ns, br
    }' "$1"
}
PRFACTS=$(list '^\.tekton/.*\.ya?ml$' | while read -r f; do
  grep -q -E 'pipelinesascode\.tekton\.dev/on-(event|cel-expression).*pull_request' "$f" || continue
  printf '%s|%s\n' "$f" "$(pr_facts "$f")"
done)

say "== Branches (Step 2: the branches MintMaker runs on, every Konflux component of each, from the pull-request pipelines in .tekton/)"
# One line per branch with all its components and pipelines; the Step 2 how-to fills its placeholders from these.
BRLINES=$(printf '%s\n' "$PRFACTS" | awk -F'|' 'NF >= 6 { n=split($6, b, ",");
    for (i=1; i<=n; i++) { br=b[i]; if (!(br in order)) { order[br]=++k; names[k]=br }
      c=($3 == "" ? "unknown" : $3); if (!seen[br SUBSEP c]++) comps[br]=(comps[br] == "" ? c : comps[br] "," c)
      if (ns[br] == "" && $5 != "") ns[br]=$5
      pipes[br]=(pipes[br] == "" ? $1 : pipes[br] "," $1) } }
  END { for (j=1; j<=k; j++) { br=names[j]; printf "branch: %s namespace=%s components=%s pipelines=%s\n", br, (ns[br] == "" ? "unknown" : ns[br]), comps[br], pipes[br] } }')
if [ -z "$BRLINES" ]; then say "branches: none (no pull-request pipeline in .tekton/)"; nbr=0; else printf '%s\n' "$BRLINES"; nbr=$(printf '%s\n' "$BRLINES" | wc -l | tr -d ' '); fi
say "branches: $nbr"

say "== Konflux names (derived from .tekton/, verify on the first MintMaker PR)"
list '^\.tekton/.*\.ya?ml$' | while read -r f; do
  grep -q -E 'pipelinesascode\.tekton\.dev/on-(event|cel-expression).*pull_request' "$f" || continue
  pr=$(awk '/^metadata:/{m=1} m && /^  name:/{print $2; exit}' "$f")
  pf=""; grep -q -E 'on-cel-expression.*files\.' "$f" && pf=" (path-filtered: runs only when matching files change, so it cannot be required)"
  brs=$(pr_facts "$f" | cut -d'|' -f5)
  case ",$brs," in *",$db,"*|*unknown*) ;; *) [ -n "$db" ] && pf="$pf (targets \`$brs\`, not \`$db\`: never require it on \`$db\`)" ;; esac
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
say "### ▶️ Step 1/14 Detected ecosystems"
if [ "$konflux" != yes ]; then
  say "🛑 No \`.tekton/\` folder with Konflux markers, so this repo is not onboarded in Konflux and MintMaker does not run on it. This skill stops here: its rules build on MintMaker's global config, which nothing would apply. Onboarding: https://konflux-ci.dev/docs/"
  exit 0
fi
say "\`.tekton/\` holds $n pipeline file$([ "$n" = 1 ] || printf s) with Konflux markers."
say ""
if [ "$fork" = yes ]; then say "Repository: \`$slug\`, the upstream of your fork \`$origin_slug\`: the GitHub settings and the PR target it."; else say "Repository: \`${slug:-unknown}\`"; fi
say ""
say "Default branch: \`${db:-unknown}\`"
say ""
say "| Ecosystem | Found in |"
say "|---|---|"
printf '%s' "$ROWS"
if [ -z "$ACTIONS" ]; then
  say ""; say "== Actions table (print verbatim in Step 6)"; say "$([ "$WORKFLOWS_FOUND" = yes ] && echo "workflows: found, no action used" || echo "workflows: none")"
else
  table "Actions table (print verbatim in Step 6)" "| Action | Maintained by | Pinned by |"
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
  say ""; say "== Base images table (print verbatim in Step 7)"; say "base_images: none"
else
  table "Base images table (print verbatim in Step 7)" "| Base image | Container files | Pinned by |"
  # one row per image, with up to three of the files that use it, in order of first appearance
  say "$BASES" | awk -F': ' '{ img=$2; sub(/ \([^)]*\)$/, "", img); if (!(img in seen)) { seen[img]=1; order[++k]=img }
      if (index(" " files[img] " ", " " $1 " ") == 0) files[img] = files[img] (files[img] == "" ? "" : " ") $1 }
    END { for (i=1; i<=k; i++) print order[i] "\t" files[order[i]] }' | while IFS="$(printf '\t')" read -r img files; do
    files=$(printf '%s' "$files" | ticks)
    case "$img" in
      *@sha256:*) pin="digest, updates arrive as digest PRs"; shown=$(printf '%s' "$img" | sed -E 's/@sha256:[0-9a-f]{12}[0-9a-f]*/@sha256:…/') ;;
      *:latest)   pin="tag \`latest\` ⚠️ nothing to bump; only a digest pin brings updates"; shown="$img" ;;
      *:*)        pin="tag, no digest"; shown="$img" ;;
      *)          pin="no tag, means \`latest\` ⚠️ nothing to bump; only a digest pin brings updates"; shown="$img" ;;
    esac
    say "| \`$shown\` | $files | $pin |"
  done
fi

# Build toolchains, shown in the Step 5 table: the version pins every developer's tooling reads, not just CI's.
TC=""
tcrow() { TC="$TC| $1 | \`$2\` | $3 |
"; }
for f in $(list '(^|/)\.mvn/wrapper/maven-wrapper\.properties$'); do
  v=$(grep -E '^distributionUrl=' "$f" | sed -E 's/.*apache-maven-([0-9][^/-]*).*/\1/'); tcrow "Maven wrapper" "$f" "${v:-unknown}"
done
for f in $(list '(^|/)gradle/wrapper/gradle-wrapper\.properties$'); do
  v=$(grep -E '^distributionUrl=' "$f" | sed -E 's/.*gradle-([0-9][^/-]*)-(bin|all)\.zip.*/\1/'); tcrow "Gradle wrapper" "$f" "${v:-unknown}"
done
for f in $(list '(^|/)go\.mod$'); do
  v=$(awk '$1 == "toolchain" { print $2; exit }' "$f"); [ -n "$v" ] && tcrow "Go toolchain" "$f" "$v"
done
for f in $(list '(^|/)package\.json$'); do
  v=$(sed -n -E 's/^[[:space:]]*"packageManager"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' "$f" | head -1); [ -n "$v" ] && tcrow "npm packageManager" "$f" "$v"
  grep -qE '^[[:space:]]*"engines"[[:space:]]*:' "$f" && tcrow "npm engines" "$f" "$(sed -n -E 's/^[[:space:]]*"node"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' "$f" | head -1)"
done
if [ -z "$TC" ]; then
  say ""; say "== Toolchains table (print verbatim in Step 5)"; say "toolchains: none"
else
  table "Toolchains table (print verbatim in Step 5)" "| Toolchain | Pinned in | Version |"
  printf '%s' "$TC"
fi
if [ "$nbr" -le 1 ]; then
  say ""; say "== Branches table (print verbatim in Step 2)"; say "branches: one, \`$(printf '%s\n' "$BRLINES" | awk '{print $2; exit}')\`"
else
  table "Branches table (print verbatim in Step 2)" "| Branch | Namespace | Pipelines |"
  # the first pipeline, then +N for the others: one row per branch, whatever the number of components
  printf '%s\n' "$BRLINES" | awk -v db="$db" '{ b=$2; ns=$3; f=$5; sub(/^namespace=/, "", ns); sub(/^pipelines=/, "", f); n=split(f, p, ",")
    printf "| `%s`%s | `%s` | `%s`%s |\n", b, (b == db ? " (default)" : ""), ns, p[1], (n > 1 ? sprintf(", +%d", n-1) : "") }'
fi
if [ -n "$found" ]; then
  if [ -n "$(printf '%s' "$CFGTABLE" | tr -d '[:space:]')" ]; then
    table "Renovate config table (print verbatim in Step 3)" "| Where | Setting | What happens |"
    printf '%s' "$CFGTABLE" | sed '/^$/d'
  else
    say ""; say "== Renovate config table (print verbatim in Step 3)"; say "Nothing to remove from the existing config."
  fi
  [ -n "$CFGKEPT" ] && say "$CFGKEPT"
fi
say ""
say ""
say "== Skipped steps (each block is the first lines of the reply that reaches the step: print it verbatim, then the next step's screen)"
n_sk=0
if [ "$nbr" -le 1 ]; then skb=$(printf '%s\n' "$BRLINES" | awk '{print $2; exit}'); say "### ▶️ Step 2/14 Branches MintMaker updates"; say "Skipped: MintMaker runs on one branch, \`${skb:-$db}\`."; say ""; n_sk=$((n_sk+1)); fi
if [ -z "$TC" ]; then say "### ▶️ Step 5/14 Build toolchains"; say "Skipped: no build toolchain pinned in this repo."; say ""; n_sk=$((n_sk+1)); fi
if [ "$WORKFLOWS_FOUND" != yes ]; then say "### ▶️ Step 6/14 GitHub Actions"; say "Skipped: no GitHub workflows in this repo."; say ""; n_sk=$((n_sk+1)); fi
if [ -z "$BASES" ]; then say "### ▶️ Step 7/14 Base images"; say "Skipped: no container file in this repo."; say ""; n_sk=$((n_sk+1)); fi
case "$SB" in ✅*) say "### ▶️ Step 11/14 Konflux app bypass"; say "Skipped: ${SB#✅ }."; say ""; n_sk=$((n_sk+1)) ;; esac
if [ ! -f .github/dependabot.yml ] && [ -z "$ou" ]; then say "### ▶️ Step 12/14 Other updaters"; say "Skipped: no other updater in this repo."; say ""; n_sk=$((n_sk+1)); fi
[ "$n_sk" -gt 0 ] || say "(none: every step has something to ask)"
say "== Manual-review candidates (the first Never-automerge option of Step 4; one manual-review rule each, under the manager whose files hold the package)"
if [ -n "$CANDS" ]; then printf '%s' "$CANDS"; else say "(none)"; fi
exit 0

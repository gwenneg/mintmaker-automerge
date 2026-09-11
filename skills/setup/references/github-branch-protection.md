# GitHub branch-protection changes for automerge

The GitHub side of automerge, in the order Step 9 of the skill walks
through it: the required checks that gate the merge, and the bypass that
lets the Konflux app merge without a human approval when the branch
requires one. Part 3, the repository setting that lets GitHub do the
merging, is optional and only changes when the merge lands; the skill
mentions it as a tip in Step 10.

## Part 1: Required status checks, the actual gate

GitHub's auto-merge waits for required checks and nothing else, so this
part decides whether automerge is safe, not just whether it works.
Recommend the strongest gate the repo already has the pieces for:

- **Include**: whatever workflows build and test the actual code, a full
  `mvnw verify`/`go test`/`npm test` run, linting, checkstyle, anything that
  fails deterministically when the PR's own diff breaks something. If the
  repo has a build job and a separate test job, require both.
- **Include the Konflux PR pipeline check** whenever the `tekton` block is
  on: it is the only check that runs the updated pipeline of a `tekton` PR.
- **Exclude**: checks that can go red for reasons that have nothing to do
  with whether this specific PR is correct. Vulnerability/CVE scanning is
  the clearest example — a new CVE can be disclosed against a dependency
  that was already merged weeks ago, turning the scan red on every PR
  afterward, including ones that don't touch that dependency at all. A
  required check with that failure mode doesn't protect the branch, it just
  wedges it shut until someone unrelated to the PR fixes the underlying
  issue. The same logic applies to any workflow known to be flaky (e.g. a
  slow integration/e2e suite with a history of unrelated intermittent
  failures) — required-but-unreliable is worse than not-required, because
  it trains people to override the gate instead of trusting it.
- **Never require a check that does not run on every PR.** GitHub keeps a
  missing required check "Pending", which blocks the merge. Two cases at
  hand: the Renovate config validator workflow, path-filtered on the config
  file, so requiring it would block every dependency PR forever, and
  `renovate/stability-days`, Renovate's own release-age check, which shows
  up in the list of checks of a MintMaker PR but never on a human's PR.

Configure this under the repo's **Settings → Rules → Rulesets** → the
ruleset covering the target branch → **Require status checks to pass** →
add the selected workflow job names.

## Part 2: The Konflux bypass

If the branch's ruleset requires an approval before merging, the Konflux
app can't merge its own PRs any more than a human could without one. It
needs to be allowed to bypass that one requirement, and nothing else: it
should still have to pass the required status checks.

### Check org-level rules first

Some organizations grant this bypass once, at the organization level,
which makes per-repo setup unnecessary. Before walking the user through the
per-repo steps below, check (or ask the user to check) the organization's
ruleset settings
(`https://github.com/organizations/<org>/settings/rules`) for an existing
ruleset that already grants the Konflux app a bypass. If one exists and
covers this repo, this whole section can be skipped — tell the user that
and stop here.

Otherwise each repo needs its own bypass, as described below.

### The per-rule granularity problem

GitHub's bypass list is configured **per ruleset, not per rule**. If a
ruleset contains both "require a pull request with 1 approval" and other
rules (e.g. required status checks, restricted force-pushes, restricted
who can push), adding a bypass actor to that ruleset lets them bypass
*everything* in it — not just the approval requirement.

Since the goal here is "the Konflux app can skip the approval requirement,
but nothing else," check how the target branch's rules are currently
organized:

- **If "require PR + 1 approval" is the only rule in its ruleset**, you can
  add the bypass directly to that ruleset — nothing else is exposed.
- **If that rule shares a ruleset with anything else** (status checks,
  push restrictions, etc.), split it out: create a new ruleset containing
  only "require a pull request before merging" with the approval count,
  and remove that rule from the original ruleset. Add the bypass actor only
  to the new, narrowly-scoped ruleset. This keeps the other protections
  (status checks, etc.) bypass-free.

### Steps (per repo)

1. Go to the repo's **Settings → Rules → Rulesets**.
2. Identify (or create, per the splitting note above) the ruleset that
   contains only "Require a pull request before merging" with "Required
   approvals: 1".
3. Open that ruleset and scroll to **Bypass list**.
4. Click **Add bypass**, search for **Red Hat Konflux**, the GitHub App
   owned by `redhat-appstudio`, and add it.
5. Choose the bypass mode. Recommend **For pull requests only**: the app
   can then skip the approval rule only when the change comes in through a
   pull request, which is the only way Renovate ever merges, so the
   narrower mode loses nothing. **Always allow** also lets the app push to
   the branch directly, which nothing here needs.
6. Save the ruleset.
7. The first Konflux-app PR that merges with passing checks and no human
   approval confirms it; Step 10 of the skill tells the user to watch for
   that. Required status checks still apply to the app.

### Repos on classic branch protection rules

Some repos still use branch protection rules (**Settings → Branches**)
instead of rulesets. Their equivalent lives inside the "Require a pull
request before merging" rule: the option **Allow specified actors to bypass
required pull requests**, where the Konflux app can be added.
Unlike a ruleset bypass, it is scoped to the pull-request requirement, so
the splitting question above doesn't arise. GitHub recommends rulesets over
branch protection rules, so if the repo has both, look at the ruleset
first; the two are enforced together.

## Part 3: "Allow auto-merge" on the repository

GitHub's auto-merge is a repository setting: **Settings → General → Pull
Requests → Allow auto-merge**. When it's off, Renovate falls back to
merging the PR itself on a later MintMaker run, once every check has
passed, so the merge lands hours later. CI still gates it either way; the
setting only changes when the merge happens.

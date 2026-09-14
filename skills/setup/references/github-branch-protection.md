# GitHub settings for automerge

The GitHub side of automerge, in the order Step 10 of the skill walks
through it: the repository setting that lets GitHub do the merging, the
required checks that gate that merge, and the bypass that lets the Konflux
app merge without a human approval when the branch requires one.

## Who can change what

GitHub's docs, per setting: "Allow auto-merge" takes the Maintain role
("People with maintainer permissions can manage auto-merge"); rulesets
and branch protection rules take the Admin role ("People with admin
access to a repository, or a custom role with the 'edit repository rules'
permission, can create, edit, and delete rulesets"); an organization
ruleset takes an organization owner. The detect script reports the role of
the `gh` login on the repository as `github_role`, so Step 10 can say from
the start whether the user can do this alone.

## Part 1: "Allow auto-merge", so GitHub does the merging

**Settings → General → Pull Requests → Allow auto-merge**. The detect
script reports it as `allow_auto_merge` when `gh` is logged in, from the
REST field of the same name.

Renovate decides per PR: it asks GitHub to auto-merge only a PR whose
resolved config has `automerge: true`, the code being
`config.automerge && automergeType in (pr, branch) && platformAutomerge`.
A major, a Quarkus bump, a wrapper, anything without a rule opens as an
ordinary PR that nothing arms, and the setting changes nothing for it.
The rules in the config stay the whole trust decision; the setting only
changes who carries it out.

Renovate has two ways to merge a PR, and the setting decides which one
runs:

- With the setting on, Renovate arms GitHub's auto-merge on the PR when
  it opens it. That is `platformAutomerge`, on by default and untouched by
  MintMaker's global config. GitHub then merges the PR "automatically
  after all required reviews and status checks pass", the merge
  requirements of the base branch, where a required check counts once it
  is "successful, skipped, or neutral". A check that is not required is
  not a merge requirement: it can be running or failing, the PR merges.
- With the setting off, Renovate's GitHub code skips the native path
  ("GitHub-native automerge: not enabled in repo settings") and, as its
  docs say, "falls back to Renovate-based automerge". That fallback merges
  the PR on a later run and only when the branch is green, and the
  `ignoreTests` docs state what green means: "Currently Renovate's default
  behavior is to only automerge if every status check has succeeded."
  The platform code reads every check run and commit status on the head
  commit and returns red as soon as one check run has conclusion
  `failure`, required or not.

So with the setting off, the vulnerability scan Part 2 tells the user not
to require still blocks every automerge, from the day a new advisory turns
it red until someone fixes the finding, and two green required checks
change nothing. The setting is what makes "required checks only" true.

Two facts to know about the native path:

- GitHub accepts auto-merge only on a PR that "cannot be merged
  immediately", so the base branch needs a required check or an approval
  rule. With the checks of Part 2 in place a fresh PR always qualifies:
  its checks are still pending when Renovate opens it. Without any rule,
  Renovate falls back to merging the PR itself.
- Renovate arms auto-merge when it creates the PR and again whenever it
  pushes to the branch: its docs say it "re-enables the PR for
  platform-native automerge whenever it's rebased". A PR already open when
  the config lands is behind the base branch from that merge on, and
  `rebaseWhen=auto` resolves to `behind-base-branch` on a PR with
  `automerge=true`, so the next run rebases and arms it.

Renovate cannot do this on its own. Asked in discussion #23554 to ignore
non-required checks, a maintainer answered: "platform automerge uses the
GitHub automerge, which bypasses non required status checks. renovate
can't know which checks are mandatory. the API is only accessable to
admins." `ignoreTests` is not a substitute either: it makes Renovate's own
merge skip every check, and the ruleset is then the only thing between a
red PR and the branch.

## Part 2: Required status checks, the actual gate

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
  The distinction GitHub draws: a workflow skipped by a `paths:` or
  `branches:` filter leaves its checks "Pending", while a job skipped by an
  `if:` condition reports "Success" and satisfies the requirement. A check
  that only matters for some files can stay required if the filter moves
  from the workflow's `paths:` to a job-level `if:`.

Configure this under the repo's **Settings → Rules → Rulesets** → the
ruleset covering the target branch → **Require status checks to pass** →
add the selected workflow job names.

## Part 3: The Konflux bypass

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
but nothing else," and with GitHub doing the merging the required checks
are the only gate left, the app must never be on the bypass list of the
ruleset that holds them. The detect script reports
`konflux_bypasses_required_checks: yes` when it already is. Check how the
target branch's rules are currently organized:

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
   approval confirms it; Step 11 of the skill tells the user to watch for
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

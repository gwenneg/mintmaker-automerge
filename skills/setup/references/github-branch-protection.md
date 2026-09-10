# GitHub branch-protection changes for automerge

Enabling automerge in `renovate.jsonc` isn't enough on its own — three
things on the GitHub side need attention for it to work safely.

1. **Required status checks (not optional).** Renovate merges through
   GitHub's auto-merge (`platformAutomerge`, on by default), and GitHub only
   waits for the checks marked required. Renovate's docs warn that without
   that rule the platform might merge Renovate PRs before the tests have
   started, while they run, or after they failed.
   The required check is what makes automerge wait for CI. Set this up
   regardless of anything else in this doc.
2. **The Konflux bypass (mechanical, needed for automerge to fire at all).**
   If the branch also requires "at least 1 approval," the Konflux app can't
   merge its own PRs any more than a human could without one — it needs to
   be explicitly allowed to bypass that specific requirement.
3. **"Allow auto-merge" on the repo (speed, not safety).** Without it
   GitHub's auto-merge is unavailable and Renovate falls back to merging
   the PR itself on a later MintMaker run.

## Part 1: Required status checks — the actual gate

This is the part that determines whether automerge is safe, not just
whether it's technically possible. Recommend the strongest gate the repo
already has the pieces for:

- **Include**: whatever workflows build and test the actual code — a full
  `mvnw verify`/`go test`/`npm test` run, linting, checkstyle, anything that
  fails deterministically when the PR's own diff breaks something. If the
  repo has more than one of these (e.g. a build job and a separate test
  job), require all of them, not just one.
- **Include the Konflux PR pipeline check** whenever the `tekton` block is
  on. It is named like `Red Hat Konflux / <component>-on-pull-request`, with
  a prefix that depends on the Konflux instance, and it is the only check
  that runs the updated pipeline of a `tekton` PR. Without it, GitHub's
  auto-merge can merge that PR before the Konflux build finishes.
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
- **Never require a workflow that can be skipped.** GitHub keeps a skipped
  required check "Pending", which blocks the merge. The Renovate config
  validator workflow is the case at hand: it is path-filtered on the config
  file, so requiring it would block every dependency PR forever.
- **This is a per-repo call.** Which workflows exist, which are trustworthy
  signal, and which are known-flaky varies per repo — scan
  `.github/workflows/` for candidates and ask the user rather than guessing
  which ones to recommend as required.

Configure this under the repo's **Settings → Rules → Rulesets** → the
ruleset covering the target branch → **Require status checks to pass** →
add the selected workflow job names.

## Part 2: The Konflux bypass

If the branch's ruleset also requires "at least 1 approval" before merging,
Renovate/MintMaker/the Konflux app still can't merge its own PRs — the
approval requirement blocks it just like it would block a human. The app
needs to be explicitly allowed to bypass that one requirement (and, per
Part 1, nothing else — it should still have to pass required status
checks).

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
4. Click **Add bypass**, search for the Konflux GitHub App, and add it. Its
   name depends on the Konflux instance the repo is on; the setup skill
   reads it from the author of an existing MintMaker PR.
5. Choose the bypass mode. Recommend **For pull requests only**: the app
   can then skip the approval rule only when the change comes in through a
   pull request, which is the only way Renovate ever merges, so the
   narrower mode loses nothing. **Always allow** also lets the app push to
   the branch directly, which nothing here needs.
6. Save the ruleset.
7. Verify with the next PR from the Konflux app on a
   `konflux/mintmaker/...` branch: with passing checks and no human
   approval, it should merge on its own on a later MintMaker run. If the
   repo also requires status checks to pass, those still apply — this
   bypass only removes the approval blocker, which is the intended scope.

### Repos on classic branch protection rules

Some repos still use branch protection rules (**Settings → Branches**)
instead of rulesets. Their equivalent lives inside the "Require a pull
request before merging" rule: the option **Allow specified actors to bypass
required pull requests**, where the Konflux app can be added.
Unlike a ruleset bypass, it is scoped to the pull-request requirement, so
the splitting question above doesn't arise. GitHub recommends rulesets over
branch protection rules, so if the repo has both, look at the ruleset
first; the two are enforced together.

### What NOT to do

Don't add the Konflux app as a bypass actor to a ruleset that also
restricts pushes or requires status checks unless that's genuinely
intended — that would let the app skip CI or push directly, which is a
much bigger exception than "skip human approval on an automated dependency
PR."

## Part 3: "Allow auto-merge" on the repository

GitHub's auto-merge is a repository setting: **Settings → General → Pull
Requests → Allow auto-merge**. When it's off, Renovate can't hand the merge
to GitHub and falls back to its own automerge: it merges the PR itself on a
later run, once every check has passed. MintMaker runs every 4 hours, so the
merge lands hours later than it would with the setting on. Either way CI
still gates the merge; this setting only changes when it happens.

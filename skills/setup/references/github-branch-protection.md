# GitHub settings for automerge

The GitHub side of automerge: the required checks that gate GitHub's
auto-merge, behind Step 9 of the skill, and the exemption that lets the
Konflux app merge without a human approval when the branch requires one,
behind Step 11, with why the exemption has to be the Exempt bypass mode
and why the checks have to live in a ruleset of their own.

## Who can change what

GitHub's docs, per setting: rulesets
and branch protection rules take the Admin role ("People with admin
access to a repository, or a custom role with the 'edit repository rules'
permission, can create, edit, and delete rulesets"); an organization
ruleset takes an organization owner. The detect script reports the role of
the `gh` login on the repository as `github_role`, so Steps 9 and 11 can
say from the start whether the user can do this alone.

## Part 1: Who merges, and why the bypass mode has to be Exempt

Renovate has two ways to merge a PR. With `platformAutomerge`, on by
default, it asks GitHub to enable its auto-merge feature on the PR when it
opens it, and GitHub merges once the branch rules are met, minutes after
the required checks pass. With `platformAutomerge: false` it merges the PR
itself, on a later run, with `PUT /repos/{owner}/{repo}/pulls/{number}/merge`.
The skill keeps the default and writes it out, `platformAutomerge: true`,
because GitHub's merge lands within minutes and on any day, where
Renovate's own waits for the next MintMaker run, up to four hours, up to
twelve on a busy cluster, and lands one PR per run.

Renovate's own merge still runs underneath, on every run where the branch
got no new commit and every check on it is green
(`lib/workers/repository/update/branch/index.ts` calls `checkAutoMerge`
whatever `platformAutomerge` says, and the merge endpoint honors a bypass
actor in any mode). So a repository whose exemption is not applied yet
still merges, slowly, and the "Allow auto-merge" repository setting is a
requirement again: without it Renovate logs "GitHub-native automerge: not
enabled in repo settings" and falls back to its own merge.

### GitHub's auto-merge and bypass actors, measured

When the approval rule of the base branch is satisfied only by a bypass
actor in the "Always allow" or "For pull requests only" mode, GitHub's
auto-merge feature arms on the PR and never completes: the PR stays
BLOCKED and REVIEW_REQUIRED with every check green. The same holds for
classic branch protection, for a repository role or an organization admin
as the actor, and for a merge queue in front. The same PR merges at once
when the same actor calls the merge endpoint, which is what Renovate's
own merge does.

The third bypass mode, Exempt, shipped on 2025-09-10 ("exempt specific
actors (roles, teams, or GitHub Apps) from all enforced rules", GitHub
changelog), behaves differently: the rules are not evaluated for that
actor at all, so GitHub's auto-merge has no approval to wait for, and the
merge queue admits the PR.

Both measured on a public test repository, with a private GitHub App as
the bypass actor, the same actor type as Red Hat Konflux, and Renovate
43.268.1, MintMaker's version, run as that app. Every negative held
twenty minutes and was paired with a control. On 2026-09-24, PRs 1 to 12:
rulesets in both of the modes then tried, classic branch protection, a
repository admin role and an organization admin as the actor, auto-merge
never completed, a human approval completed it within seconds each time,
and the merge queue refused every entry. On 2026-10-08, PRs 22 to 28, with
the Exempt mode:

- PR 22, organization admin role exempt, auto-merge armed by the admin:
  merged in 64 seconds with no approval. PR 23, the same role in "Always
  allow" the same day: still blocked after twelve minutes, and flipping
  the ruleset to Exempt afterwards did not complete it, since auto-merge
  is only re-evaluated on PR events.
- PR 24, the same with a merge queue: queued in 52 seconds, merged by the
  queue a minute later.
- PR 25, the app exempt, Renovate 43.268.1 with `platformAutomerge`:
  merged by GitHub two minutes after its check, no approval. PR 26, the
  same behind a merge queue: queued in 39 seconds, merged by the queue.
- PR 27, control: the app exempt from the approval ruleset, the required
  checks in a ruleset of their own, one check red: blocked for seven
  minutes, then closed. PR 28: approval rule and required checks in one
  ruleset, the app exempt from it, one check red: merged 21 seconds after
  the check failed.
- Direct push to `main` by the app's token, no PR: accepted in Exempt
  and "Always allow" modes, refused in "For pull requests only" ("Changes
  must be made through a pull request"), and refused in Exempt mode once a
  separate ruleset required a check ("Required status check "ci" is
  expected"). Force-push of `main` to an older commit that had passed its
  check, the app exempt from the pull request rule: accepted with no
  force-push rule anywhere, refused once "Block force pushes" sat in the
  checks ruleset. Deleting `main`: refused, GitHub never deletes a default
  branch.
- Rule insights record every exempt merge and push as "pass" with each
  rule "skipped", never as a bypass; the "Always allow" push reads
  "bypass". The API docs say it: "When bypass_mode is exempt, rules will
  not be run for that actor and a bypass audit entry will not be created."

The write-up of the September part, with every PR linked:
https://github.com/orgs/community/discussions/208718, repository
https://github.com/gwenneg-mq-lab/mq-bypass-lab (its README maps the rules
to each PR).

Earlier reports of the auto-merge behavior, all read in full:

- 2025-01-19, Shunsuke Suzuki, the earliest: Renovate app on the bypass
  list of a code-owner ruleset, GitHub's auto-merge feature, never merged.
  https://zenn.dev/shunsuke_suzuki/scraps/ca7028a7f4fb73
- 2024-09 and 2024-10, maxbrunet and glasser, with a merge queue: "the
  bypass list of rule sets works for Renovate itself, it does not work for
  GitHub's auto-merge/merge-queue".
  https://github.com/renovatebot/renovate/discussions/31315 and
  https://github.com/orgs/community/discussions/142206
- 2025-06-12, discussion "auto-merge doesn't work with rulesets", never
  answered by GitHub staff.
  https://github.com/orgs/community/discussions/162623
- 2026-03-25, discussion 190610, answered by GitHub's product manager for
  pull requests on 2026-03-26 with "Thanks for reporting. A fix is in the
  queue." That thread is about a related symptom; the bypass case is
  raised in its follow-ups, unanswered.
  https://github.com/orgs/community/discussions/190610
- 2026-05-09, gh CLI issue 13388, repository role actor, with a maintainer
  confirming the CLI cannot work around it.
  https://github.com/cli/cli/issues/13388
- 2026-07-23, jgsuess: app actor, both modes, two repositories, polled for
  ten minutes; the direct merge as the same app worked at once.

None of them tried the Exempt mode.

### What Exempt costs, and what makes it safe

An exempt actor skips every rule of its ruleset, for pull requests and
for pushes alike, and nothing records it. Three things follow, each
measured above:

- The ruleset holding the exemption must contain "Require a pull request
  before merging" and nothing else. Required checks in it would be skipped
  too (PR 28), and so would force-push and deletion blocks.
- The required checks and "Block force pushes" live in a second ruleset
  with no bypass actor. That ruleset refuses the app's direct pushes, since
  a pushed commit has no passing check, and its force-pushes.
- The bypass counts an auditor reads no longer show the app's merges. The
  PR timeline and the commit history still do.

The exempt actor is the Konflux app alone, never a role or a team: an
exempt "Repository admin" role would exempt every admin from reviews.

### What the gate is now

GitHub's auto-merge reads the required checks of the base branch and
nothing else. A check that is not required never holds a merge, red or
not, and with no required check a PR merges as soon as it opens. Part 2
is therefore the whole safety of the setup, not a refinement of it. The
`ignoreTests` option of earlier versions, which made Renovate's own merge
read the required checks only, is gone with the choice it served.

"Require branches to be up to date before merging", in the checks
ruleset, decides whether every merge is retested against the branch it
lands on: with it, a behind PR waits for MintMaker's next run to rebase it
and rerun its checks, so merges land one run apart; without it, a green PR
merges within minutes, as tested against the base it was opened on. It
applies to every PR on the branch, so the skill reports it and recommends
nothing.

## Part 2: Required status checks, the actual gate

GitHub's required checks are the only thing between a red PR and the
branch, and this part decides whether automerge is safe, not just
whether it works. Recommend the strongest gate the repo already has the
pieces for:

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

Configure this under the repo's **Settings → Rules → Rulesets** → a
ruleset covering the target branch with no bypass actor → **Require
status checks to pass** → add the selected workflow job names, and
**Block force pushes** in the same ruleset.

## Part 3: The Konflux exemption

If the branch's ruleset requires an approval before merging, the Konflux
app can't merge its own PRs any more than a human could without one. It
needs to be exempt from that one rule, and nothing else: it should still
have to pass the required status checks. Only the Exempt bypass mode
works with GitHub's auto-merge, see Part 1.

### Check org-level rules first

Some organizations grant this exemption once, at the organization level,
which makes per-repo setup unnecessary. Before walking the user through the
per-repo steps below, check (or ask the user to check) the organization's
ruleset settings
(`https://github.com/organizations/<org>/settings/rules`) for an existing
ruleset that already lists the Konflux app as an Exempt bypass actor. If
one exists and covers this repo, this whole section can be skipped, tell
the user that and stop here.

Otherwise each repo needs its own exemption, as described below.

### The per-rule granularity problem

GitHub's bypass list is configured **per ruleset, not per rule**, and an
exempt actor skips *everything* in its ruleset: required status checks,
force-push and deletion blocks, signed commits, whatever sits next to the
pull request rule. PR 28 above is a PR with a red required check merged
by auto-merge for that reason, and the force-push test is the branch
rewound.

Since the goal here is "the Konflux app skips the approval requirement,
but nothing else", the app must never be on the bypass list of the
ruleset that holds the checks. The detect script reports the other rules
of the approval ruleset and whether a bypass-free ruleset blocks force
pushes. Check how the target branch's rules are currently organized:

- **If "require PR + 1 approval" is the only rule in its ruleset**, add
  the exemption directly to that ruleset: nothing else is exposed.
- **If that rule shares a ruleset with anything else** (status checks,
  push restrictions, etc.), split it out: create a new ruleset containing
  only "require a pull request before merging" with the approval count,
  and remove that rule from the original ruleset. Add the exemption only
  to the new, narrowly-scoped ruleset, and make sure the original one has
  "Block force pushes" and no bypass actor.

### Steps (per repo)

1. Go to the repo's **Settings → Rules → Rulesets**.
2. Identify (or create, per the splitting note above) the ruleset that
   contains only "Require a pull request before merging" with "Required
   approvals: 1".
3. Open that ruleset and scroll to **Bypass list**.
4. Click **Add bypass**, search for **Red Hat Konflux**, the GitHub App
   owned by `redhat-appstudio`, and add it.
5. In the menu next to the app, choose **Exempt**. "Always allow" and
   "For pull requests only" both leave GitHub's auto-merge waiting for an
   approval that never comes; Renovate then merges the PR itself on a
   later run, slowly. Exempt also lets the app push to the branch
   directly, which the checks ruleset of the next step refuses.
6. Save the ruleset.
7. In the ruleset holding **Require status checks to pass**, make sure
   **Block force pushes** is on and the bypass list is empty.
8. In **Settings → General → Pull Requests**, turn on **Allow
   auto-merge**: without it Renovate cannot arm the merge.
9. The first Konflux-app PR that merges with passing checks and no human
   approval confirms it; Step 14 of the skill tells the user to watch for
   that. Required status checks still apply to the app.

### Repos on classic branch protection rules

Some repos still use branch protection rules (**Settings → Branches**)
instead of rulesets. Their "Allow specified actors to bypass required
pull requests" option has no Exempt mode, and GitHub's auto-merge does not
honor it (PR 3 and PR 12 of the September tests), so a branch on classic
protection moves to rulesets first. GitHub recommends rulesets over branch
protection rules anyway; if the repo has both, the two are enforced
together, and the classic rule's approval requirement blocks auto-merge
even once the ruleset exempts the app.

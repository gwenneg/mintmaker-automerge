# GitHub settings for automerge

The GitHub side of automerge: why Renovate merges the PR itself instead
of GitHub's native auto-merge and the required checks that gate that
merge, behind Step 9 of the skill, then the bypass that lets the Konflux
app merge without a human approval when the branch requires one, behind
Step 11.

## Who can change what

GitHub's docs, per setting: rulesets
and branch protection rules take the Admin role ("People with admin
access to a repository, or a custom role with the 'edit repository rules'
permission, can create, edit, and delete rulesets"); an organization
ruleset takes an organization owner. The detect script reports the role of
the `gh` login on the repository as `github_role`, so Steps 9 and 11 can
say from the start whether the user can do this alone.

## Part 1: Why Renovate merges the PR itself

Renovate has two ways to merge a PR. With `platformAutomerge`, on by
default, it asks GitHub to enable its auto-merge feature on the PR when it
opens it, and GitHub merges once the branch requirements are met. With
`platformAutomerge: false` it merges the PR itself, on a later run, with
`PUT /repos/{owner}/{repo}/pulls/{number}/merge`. The skill writes
`platformAutomerge: false`, because the native path is broken for the
case this skill exists for.

### The bug: GitHub's auto-merge feature and bypass actors

When the approval rule of the base branch is satisfied only by a bypass
actor, GitHub's auto-merge feature arms on the PR and never completes. The
PR stays BLOCKED and REVIEW_REQUIRED with every check green, forever. It
happens on rulesets and on classic branch protection, with a GitHub App
or a repository role as the actor, in "For pull requests only" and
"Always allow" modes, and with a merge queue in front. The same PR merges
instantly when the same app calls the merge endpoint directly, which is
what Renovate's own merge does.

Reproduced on 2026-09-24 on a public test repository, with a private
GitHub App as the bypass actor, the same actor type as Red Hat Konflux, and
Renovate 43.268.1 and 44.111.4 run as that app: every negative held twenty
minutes and paired with a control on the same PR. Rulesets in both bypass
modes, classic branch protection, a repository admin role and an
organization admin as the actor: auto-merge never completed, and one human
approval completed it within seconds each time. The merge endpoint honored
the bypass every time. With a merge queue, on rulesets and on classic
protection: auto-merge never queued the PR, `enqueuePullRequest` was
refused with "At least 1 approving review is required by reviewers with
write access", Renovate's own merge got 405 "Changes must be made through
the merge queue", and Renovate 44's enqueue fallback got the same refusal.
Giving the app a bypass of the queue rule made it merge outside the queue.
The write-up with every PR linked:
https://github.com/orgs/community/discussions/208718, repository
https://github.com/gwenneg-mq-lab/mq-bypass-lab (its README maps the rules
to each PR).

Earlier reports, all read in full:

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

No changelog entry, docs note or roadmap item mentions it as of
2026-09-17. GitHub Support has told users an enhancement request exists.

### What works instead

- The merge endpoint honors bypass actors, on rulesets and on classic
  branch protection. Renovate uses it when `platformAutomerge` is false:
  on each run where the branch got no new commit, if the PR is up to date,
  not conflicted, not modified by someone else and, unless `ignoreTests`
  is set, every check on its head commit is green, Renovate sends the
  merge request. GitHub still enforces the required checks itself and
  answers 405 until they pass; Renovate logs it and retries on the next
  run. A merge therefore lands on the first MintMaker run after the gate
  opens, up to four hours later, up to twelve on a busy cluster.
- A merge queue does not help: entry into the queue is evaluated like
  auto-merge, so a bypass actor's PR never gets in, whoever tries to add it,
  and a bypass of the queue rule itself makes the merge skip the queue. See
  the reproduction above.
- A second identity approving the PR also lets GitHub's auto-merge feature finish,
  but an app approval never satisfies a code owner review, and it needs a
  credential the PR author cannot use. The skill does not use this.

"Allow auto-merge" in the repository settings plays no part once
`platformAutomerge` is false.

### What `ignoreTests` changes

By default Renovate's own merge waits for every check on the head commit,
required or not: `ignoreTests` docs, "Currently Renovate's default
behavior is to only automerge if every status check has succeeded." One
scanner that goes red on a new advisory then holds every automerge until
someone fixes the finding. With `ignoreTests: true`, Renovate reads no
check at all and asks for the merge as soon as the PR is otherwise ready;
the required checks of the base branch become the whole gate, and with
none of them a PR merges on red CI. That is why the skill offers it as the
risky option of Step 9, never as the recommended one, and why Part 2
matters more when it is chosen.

## Part 2: Required status checks, the actual gate

With `ignoreTests`, GitHub's required checks are the only thing between
a red PR and the branch, and this part decides whether automerge is
safe, not just whether it works. Without it, Renovate waits for every
check on the PR itself, and the required checks play no part in its
merge; the skill then shows them for information only.
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
should still have to pass the required status checks. The merge request
Renovate sends honors the bypass, on rulesets and on classic branch
protection; GitHub's auto-merge feature does not, see Part 1.

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
   approval confirms it; Step 14 of the skill tells the user to watch for
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

# Why the config looks the way it does

Read this when the user asks why a rule exists or why an alternative was not
chosen. The short form of each point is a comment in the generated config;
this file is the long form.

## No `extends` of MintMaker's global config

MintMaker runs Renovate with `config/renovate/renovate.json` from
`konflux-ci/mintmaker` as the global config and merges the repository's
config on top of it. Its user docs say: "Do not copy the base configuration
to your own project. Always start with an empty configuration file."
Extending that file again from the repo pulls global-only options
(`onboarding`, `autodiscover`, `platformCommit`, `allowedCommands`) into
repo config, and it tracks `main` while the docs say the deployment "may
use a configuration from a specific commit". Older configs often have the
line because early examples did; that is history, not a reason.

The header comment replaces it: it names what is inherited, how the merge
works, and where the global config and the docs live. The merge rules in it
come from Renovate's option definitions: `packageRules` and manager blocks
are mergeable, `enabledManagers` is not.

## No `baseBranchPatterns`

MintMaker's GitHub component sets `baseBranchPatterns` to the branch the
Konflux component tracks. Renovate also defaults to the repo's default
branch. A repo-level value repeats that at best; on a component that tracks
`master` or a release branch, it points Renovate at the wrong branch.

## No `minimumReleaseAge`

MintMaker's global config sets `minimumReleaseAge` to 3 days (at the time
of writing) and `minimumReleaseAgeBehaviour` to `timestamp-optional`. The delay exists
because supply-chain compromises usually ship as a patch release and are
caught and pulled within days of publishing.

The delay holds the update back before any branch exists, not at merge
time. Renovate's `internalChecksFilter` option defaults to `strict`, and
MintMaker does not change it, so a release younger than the delay gets no
branch and no PR. Renovate's minimum-release-age docs: with `strict`,
"branches are not created if the `minimumReleaseAge` status check,
`renovate/stability-days`, does not pass". The PR appears once the release
is old enough, with that check already passing, and automerge proceeds
from there. Two consequences:

- The delay covers every update that has a publish date, whether it
  automerges or waits for a human; the limit below says which have none.
- Updates held by the delay are invisible: Renovate lists them on the
  dependency dashboard, and MintMaker's global config disables it.

Renovate's docs also describe a mode where the PR opens at once and only
the merge waits. That needs `internalChecksFilter` set to `none` or
`flexible`, which MintMaker does not do.

Setting the value again in the repo is redundant at best and, if MintMaker
changes its value, silently out of sync at worst. The same goes for quoting
the value in a comment of the generated file, which is why the header names
the setting and links to the global config instead.

The one limit: with `timestamp-optional`, Renovate's docs say it "will
treat a release without a releaseTimestamp as stable". A release whose
registry reports no publish date is not delayed. Container images are the
common case: Renovate's docker datasource docs say release timestamps are
"only supported on Docker Hub", so a base image from
`registry.access.redhat.com` or `quay.io`, and the Konflux task bundles on
`quay.io`, get no delay at all. For those, the required checks are the
only gate.

## Vulnerability fixes skip the delay

MintMaker's global config enables `vulnerabilityAlerts`, so Renovate raises
fix PRs for the repository's GitHub security alerts. Those PRs skip the
release-age delay.
Renovate's docs say such PRs "skip the line" on limits and schedule. The
delay part is not in the docs but in Renovate's option definitions: the
default `vulnerabilityAlerts` object sets `minimumReleaseAge` to null,
MintMaker only adds `enabled: true` on top, and Renovate applies the
object as a `force` block on each fix, which wins over every package rule.
A fix that is a patch or minor bump in an automerged ecosystem therefore
merges as soon as CI passes, without the wait. A fix that needs a major
bump stays manual like any other major.

The plugin keeps this behavior and writes nothing for it: fast patching
is the point of a fix PR, and the attack it exposes needs a published
advisory pointing at a malicious version. Renovate's one warning applies:
"There's a small chance that a wrong vulnerability alert results in a
flapping/looping vulnerability fix." A fix that merged without the delay
is worth a look after the fact.

Because nothing in the repo sets it, the behavior can change upstream, if
Renovate changes that default or MintMaker sets a delay inside its
`vulnerabilityAlerts` block. The places to re-check are Renovate's
`lib/config/options/index.ts` and MintMaker's global config.

## Why GitHub Actions get an allow-list and libraries get options

Actions run arbitrary code in CI, with whatever the workflow's token and
secrets can reach, so each one is vetted by name with `matchDepNames`.

The allow-list only protects SHA-pinned actions. With
`uses: owner/action@<sha> # v1.2.3`, Renovate proposes a `digest` update when
the tag is moved to another commit, and the patch/minor filter keeps that
out of automerge. With `uses: owner/action@v1`, CI runs whatever the tag
points at and Renovate has nothing to open. That is why the skill offers
`helpers:pinGitHubActionDigests`, which Renovate's docs define as
`pinDigests: true` for the `action` and `workflow` dep types. The pin PRs
have the `pinDigest` update type, or `pin` when the ref was a floating
tag such as `v4`, and stay manual. The preset stays in the file when
every action is already pinned: it finds nothing to do then, and an
action added later as `@v1` gets its pin PR from it, SHA and full version
at once, where the pin rule alone would leave it on a movable tag. The
version in the comment has to be a full one, the next section says why.

Library ecosystems are offered three widths because the tradeoff differs
per team. Every patch and minor bump relies on the release-age delay as the
defense against a compromised release. Development dependencies only keeps
the runtime dependency list from changing unattended, but build and test
tooling still runs in CI on those PRs, install scripts included, and a
bundler or compiler among it produces the shipped artifact. An allow-list
is the strongest and the most maintenance.

For Go, MintMaker's global config enables updates of indirect dependencies
(`matchDepTypes: ["indirect"]` in its `gomod` block), so option 1
automerges them too. The same block sets `postUpdateOptions` to
`gomodTidy` and `gomodUpdateImportPaths`, so every Go PR arrives tidied;
the repo file restates neither.

## Why the version comment carries a full version

The github-actions manager reads the comment next to a SHA as the version
and the SHA as the digest. Its versioning, `github-actions`, treats `v4` as
a floating tag and keeps the shortest tag that exists: its readme says that
from `v7`, an upgrade to `v7.5.3` stays `v7`. So a `# v4` comment never
changes, and every release of the action arrives as a `digest` update of
`v4`, which the patch-and-minor rule never matches. A repository that
referenced its actions as `@v4` and let `helpers:pinGitHubActionDigests`
pin them ends up with `# v4` comments on every line, and an allow-list
that matches nothing. Seen on a Quarkus repository in September 2026:
every allow-listed action had a floating comment, and the first release
after the pin, `github/codeql-action` 4.38.1, arrived as a digest PR.

Automerging `digest` updates would not fix it: with a floating comment, a
normal release and a moved tag are the same digest PR, and Renovate 43.x,
the line MintMaker ran in September 2026, applies no release-age delay to
digest updates at all (added upstream on 2026-07-30 in
renovatebot/renovate#44965, after 43.268.1). The fix is a full version in
the comment: a release is then a `patch` or `minor` update that carries
the new SHA, waits for the delay and automerges, while a moved tag is
still a `digest` update that stays manual.

The skill writes `rangeStrategy: pin` for the `action` depType, next to
the allow-list rule, whenever the user did not decline pinning, every
action already SHA-pinned included. Renovate resolves a floating value
to the highest full version it matches and emits a `pin` update, which
the versioning turns into the full version. `pin` is not in the automerge
rule's update types, and Renovate's default `pin` config groups every
such update into one "Pin dependencies" PR. An action still referenced
as `@v6` gets one update that pins the SHA and writes the full version at
once. Actions already on a full version, and reusable workflows, get
nothing from the rule. Verified by running Renovate 43.268.1 in dry-run
on 2026-09-22: `v4` with SHA `b96794f` became a pin to `v4.38.1` with the
commit of that tag, `v7` on `actions/checkout` a pin to `v7.0.1` with the
SHA unchanged, and a `# master` reusable workflow was untouched. Sources: the
`github-actions` versioning readme and `getNewValue`, `lookup/index.ts`
and `lookup/current.ts` in Renovate, and the lookup test "handles pin for
github actions".

When the user declines pinning, the rule is dropped with the `extends`
block: they chose floating tags, and the rule would rewrite `@v4` to
`@v4.2.2`, then open a PR per release for every action, allow-listed or
not. The "Don't pin" option says what that costs: the allow-list guards
version bumps only, not moved tags, and only for the actions referenced
by a full version, since one on a floating tag keeps following it with
no PR.

The `helpers:pinGitHubActionDigestsToSemver` preset converts the comments
too, but it swaps the versioning for a regex and types the conversion as
`minor`, so it would automerge.

## Why build toolchains get a step of their own

A wrapper is the JVM shape of a wider thing: a pinned tool version that
every developer's tooling reads, not just CI's. `mvnw` and `gradlew`
download the version their properties file pins. The `toolchain` line of
`go.mod` makes the `go` command fetch that exact compiler, and Renovate's
gomod docs say updates to it "should" be "proposed by default", under the
`toolchain` depType, while the `go` directive is not bumped by default.
In `package.json`, `packageManager` is what corepack installs and
`engines` constrains Node; Renovate's npm manager handles both under
depTypes of the same names. Renovate treats each as a dependency, so the
plain patch-and-minor rule of the manager would merge a new Go release or
a new pnpm line on its own. The toolchain rules keep them manual by
default; opting in flips them to patch and minor, with CI as the gate.
Version files such as `.nvmrc`, `.python-version` or `.tool-versions`
have managers of their own that MintMaker enables, and no rule from the
skill, so they stay manual like any ecosystem without a rule.

## Why the Tekton block can automerge

MintMaker's `tekton` manager only reads `.tekton/**`. The updates are task
bumps from the Konflux catalog, pinned by digest, and the pipeline
migrations MintMaker runs alongside them with its post-upgrade tool. They
are the pipeline itself, so the PR's own Konflux build runs the updated
pipeline: if the migration breaks the build, the check fails. With the
recommended gate, Renovate waits for every check, so that red check holds
the PR; with the required checks as the only gate, it holds the PR only
when it is required, which is why Step 9 says to require it. The block sets
`automerge` for the whole manager, so every update type it produces is
covered, the task replacements MintMaker configures included.

`"schedule": ["at any time"]` is a separate decision. MintMaker's global
config schedules the tekton manager on Saturdays; the override makes
pipeline updates arrive within hours instead. Dropping the line keeps the
weekly batch. When the repo has merge days, the line carries their cron
instead, so the pipeline follows the same days.

## Why GitHub's auto-merge feature is off, and what the gate choice means

The generated file sets `platformAutomerge: false`. With the default,
Renovate asks GitHub to enable its auto-merge feature on each PR it opens, and
GitHub never completes that merge when the approval rule of the base
branch is satisfied only by a bypass actor, which is exactly how the
Konflux app merges without a human. The PR stays blocked with every check
green. Reported since January 2025 on rulesets and classic protection
alike, acknowledged by GitHub in March 2026, unfixed in September 2026;
`references/github-branch-protection.md` has the dated sources. Renovate's
own merge goes through the merge endpoint, which honors the bypass, so the
skill turns the feature off and the "Allow auto-merge" repository
setting no longer matters.

That merge waits for every check on the PR's head commit, required or
not. Step 9 makes this explicit as the recommended gate: keep the checks,
and Renovate merges only when 100% of them pass. The alternative,
`ignoreTests: true`, makes
Renovate ask for the merge without reading any check, so the required
checks of the base branch are the whole gate and a non-required scanner
that stays red never holds a merge. It is offered as the risky option,
for repositories where a check can turn red for reasons outside the PR,
because with no required check a PR then merges on red CI. Which
checks are required is decided in Step 9, right after the choice, and the PR body says the gate
is the whole gate when this option was chosen.

## Why the merge days are a `schedule`, not an `automergeSchedule`

Renovate has an option named for the job, `automergeSchedule`, and the
skill does not use it. `schedule` bounds when Renovate opens and rebases
branches, and MintMaker's global config sets `updateNotScheduled` to
false, so on a run outside the schedule an existing branch is skipped
before any merge attempt: the merge waits for the next run inside the
days, which is the bound the user asked for, with one option instead of
two. `* * * * 1-4` is Monday to Thursday in UTC, in the cron form
MintMaker uses for its own schedules; Renovate's cron takes `*` for the
minutes and reads it in UTC unless the `timezone` option names another.
MintMaker runs every four hours from 00:00 UTC, twice a day on busy Konflux
clusters, so the last run inside that window is Thursday 20:00 UTC at
the latest, and a `timezone` line moves the window
to the team's clock.

Two things stay outside the days. Vulnerability fix PRs ignore the
schedule by design, so a fix opens and merges on a Friday like any other
day. And a PR a person merges by hand merges whenever they click.

## Why everything stays in one file, not a shared preset

Renovate can load rules from a preset in another repository, and some
organizations share one that way to keep grouping and commit conventions
identical across many repos. That fits conventions. It does not fit
automerge rules, for three reasons:

- The file is small, about forty lines with its comments. Splitting it
  saves nothing and costs the reader a second repo and a precedence
  question on top of MintMaker's global config.
- It almost never changes. An action joins the allow-list once, when the
  repo starts using it, and the release-age delay is already the defense
  against a bad release. There is no stream of changes to centralize.
- Automerge is the repo owner's trust decision. A preset moves it to
  whoever can merge in the shared repo, and changes there reach every
  consumer with no PR in their own repo.

## Why MintMaker is disabled on a branch through its Konflux components, not in the config

Two facts decide this. MintMaker creates one Renovate job per repository
and branch: it walks the Konflux components, and the first one it meets
for a branch gets the job, the others are skipped as duplicates (its docs
say "randomly select one component"; the controller takes the first in
its list). And Renovate reads the repository config from the default
branch only, since `useBaseBranchConfig` defaults to `none`. Most users
expect to disable MintMaker on a branch in `renovate.jsonc`, so the four ways to
try are listed here with what stops each of them.

- **A package rule that disables the branch**, `matchBaseBranches` plus
  `enabled: false`. It stops ordinary updates and nothing else. MintMaker's
  global config sets `vulnerabilityAlerts` to `enabled: true`; Renovate
  turns every GitHub or OSV alert into a package rule that carries that
  object as a forced block, and `mergeChildConfig` applies forced values
  at every merge, so a dependency with an open alert is re-enabled and
  the fix PR opens on the branch. Package rules are also applied only
  once dependencies exist, never at extraction, so they cannot keep
  Renovate from reading the branch at all.
- **A whitelist with `baseBranchPatterns`**, set to the default branch.
  It does stop the other branch, but the value overrides the branch each
  job was given, so every job now processes the default branch: two
  identical jobs on it at the same time. MintMaker's docs describe the
  case under "Potential issues with baseBranchPatterns configuration"
  and say
  "conflicts can occur leading to unexpected behavior". Their own
  workaround is to disable MintMaker on all but one component, which is
  the annotation below.
- **A config file on the branch itself.** Nothing there is read unless the
  default branch's file sets `useBaseBranchConfig: merge`, and then the
  branch's file must carry the same name. `enabled: false` in it fails
  for the reason above, the forced alert rules. `ignorePaths: ["**"]` does
  work, since it removes every package file before any rule runs, but on
  a branch that a job or a person refreshes from the default branch, the
  next refresh brings the default branch's file back, so that does
  not hold there.
- **Disabling vulnerability alerts** to make the first route complete
  turns them off for the default branch too, since the setting is
  repository-wide.

What MintMaker documents for this is the annotation
`mintmaker.appstudio.redhat.com/disabled: "true"` on the Konflux
component, set with `oc annotate`. The controller drops every annotated
component before it walks the list, and creates a branch's job from any
component left, so a branch stops only once all of its components carry
the annotation, which the docs say in as many words: "when a repository
or branch has multiple components, you must annotate each component
individually". The value must be exactly `true`. Then no job runs on the
branch, vulnerability fixes included, and nothing in the repository
changes, which is why it survives a branch sync. Two consequences
to know: no job means nobody closes the MintMaker PRs already open on the
branch, and the Konflux UI has no code reading the annotation, so the only
visible effect is that the component's Dependency updates tab stops
receiving runs. The skill prints the commands and applies nothing, as
with the GitHub settings.

The login command comes from the Konflux UI's help menu, "Copy login
command": `oc login <api server> --web -n <namespace>`, where `--web`
authenticates in the browser. Installing `oc` is left to the OpenShift
CLI documentation, which the how-to links; the skill prints no download
command of its own, so a moved mirror or a new install path never dates
it.

Sources: MintMaker user docs, sections "Offboarding a repository" and
"Potential issues with baseBranchPatterns configuration"; MintMaker's
`dependencyupdatecheck_controller.go`, the disabled-annotation filter and
the one-run-per-repository-and-branch loop; Renovate's docs for
`useBaseBranchConfig`, `ignorePaths` and `vulnerabilityAlerts`, and its
`lib/util/package-rules/index.ts` and `lib/config/utils.ts` for the
forced block.


## Why the automerged updates are batched per ecosystem

Renovate merges one PR per run. Its branch loop stops as soon as a branch
was automerged, because the base branch changed under the list it computed
at the start of the run (`lib/workers/repository/process/write.ts`, "Stop
processing other branches because base branch has been changed"), and the
repository job restarts once, never twice (`lib/workers/repository/index.ts`,
"Restarting repository job after automerge result"). In the restarted pass
every other open PR is behind the base branch, and `rebaseWhen: auto`
resolves to `behind-base-branch` for a branch with automerge on and to
`conflicted` for the others (`lib/workers/repository/update/branch/reuse.ts`),
so every automerge PR is force-pushed and its checks rerun, while the PRs on
manual review stay as they are until they conflict. MintMaker runs a repository every four hours, twice a day on busy Konflux
clusters (the four-hour base schedule is in its docs, the busy-cluster
cadence comes from the MintMaker operators), so a queue of single PRs drains at one merge per run while every
merge, and every human push to the base branch, costs a rebuild of every
open PR. Seen on a Go repository in September 2026: twenty open MintMaker
PRs, the concurrent limit, fourteen of them green, one merge per run, and
each of them force-pushed five to fifteen times, against zero to two for
the major bumps on manual review.

A group PR lands every member in that one merge. The skill groups per
ecosystem by default, one `groupName` per automerge rule, so a red Go
build holds the Go group and nothing else. Renovate's noise-reduction docs
name the cost: a group that "breaks" waits until every member passes, and
one bad member holds the rest. That member needs a rule of its own,
`automerge: false` with `groupName: null`, until it builds.

Two mechanics shape the rules. A group automerges only when every member
does: `lib/workers/repository/updates/generate.ts` sets the branch's
`automerge` to `upgrades.every((u) => u.automerge)`. So every rule that
keeps something manual inside a grouped manager, the toolchain and indirect
rules, the npm `packageManager` rule and the manual-review rules, unsets the
group with `"groupName": null`, or the group silently stops automerging.
`null` is Renovate's own idiom: its default `vulnerabilityAlerts` block
carries `groupName: null`, which is why vulnerability fixes get PRs of their
own, and MintMaker's config validator accepts it in strict mode (verified
with renovate-config-validator 43.288.0). Majors are never matched by the
patch-and-minor rules, so they stay in PRs of their own, and pin updates
have Renovate's own "Pin dependencies" group.

A member joins the group only once its own release-age delay has passed,
since `internalChecksFilter: strict` filters per dependency at lookup. When
a new member joins, the group branch gets a new commit and its checks
rerun, so the merge waits for the next run.

## Why rebasing on every move is the default, and what rebasing only on conflict costs

Renovate's `rebaseWhen` docs say `conflicted` "is not recommended if you
have enabled Renovate automerge", for two reasons: two updates merged one
after another are never tested together, so the base branch can break, and
a rule that requires branches to be up to date makes automerge impossible
for a branch that is behind but not conflicted. The automerge concepts page
adds the design behind the default: after a merge Renovate recomputes the
state of every remaining branch, wants each one up to date before it
merges, and merges one per run because merging several in a row "does not
work reliably". The recommended answer keeps that: every merge is tested
against the branch it lands on.

The other answer, `rebaseWhen: conflicted`, is offered because it removes
the rebuild storm and the reset on every human push, and lets the restarted
pass merge a second green PR. It works on GitHub because Renovate's PR
automerge checks conflicts, the branch status and whether someone else
pushed, never whether the branch is behind (`lib/workers/repository/update/pr/automerge.ts`;
the "cannot merge" reason it also checks is set by the Gitea platform
only), and GitHub allows a merge of a behind branch unless a rule requires
branches to be up to date. The cost is the first reason above: a PR merges
as tested against the base it was opened on, like a human merge without
"Update branch", and a broken combination shows on the base branch's build
instead of on the PR. The scan reads the rulesets' `strict_required_status_checks_policy`, GitHub's
"Require branches to be up to date before merging", and reports it as
`up_to_date_required`; when it is set, the skill withholds the option,
since a behind branch that does not conflict could never merge. The
skill writes the `keepUpdatedLabel` option next
to it, Renovate's per-PR way back to `behind-base-branch`, and says so in
the summary and the PR body. MintMaker's `tekton` and `lockFileMaintenance`
blocks set `rebaseWhen: behind-base-branch` themselves, and a manager block
wins over the top-level key, so pipeline updates and lockfile refreshes
keep rebasing whatever the answer.

A merge queue would give both, retesting and throughput, and Renovate
resolves `rebaseWhen: auto` to `conflicted` behind one for that reason. It
is out of reach on a branch that requires an approval: the queue never
admits a PR whose approval is satisfied by a bypass actor, see
`references/github-branch-protection.md`.

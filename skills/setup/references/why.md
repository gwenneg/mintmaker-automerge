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

The header comment replaces it with a link to the global config. The merge
itself follows Renovate's option definitions: `packageRules` and manager
blocks are mergeable, `enabledManagers` is not.

## No `baseBranchPatterns`

MintMaker's GitHub component sets `baseBranchPatterns` to the branch the
Konflux component tracks. Renovate also defaults to the repo's default
branch. A repo-level value repeats that at best; on a component that tracks
`master` or a release branch, it points Renovate at the wrong branch.

## No `minimumConfidence` or `matchConfidence`

MintMaker does not support Renovate's Merge Confidence features. Without
them, Renovate rates every update `neutral`: a `minimumConfidence` above
that holds every update it covers on a pending
`renovate/merge-confidence` check forever, and a `matchConfidence` rule
fails config validation, which stops Renovate on the repository.

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
the value in a comment of the generated file, which is why the header only
links to the global config.

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

The name is always `owner/repo`, never with the subpath a monorepo action
adds: the github-actions manager's `depName` drops it
(`lib/modules/manager/github-actions/extract.ts`, `packageName = owner/repo`).
A repo that calls `github/codeql-action/init`, `/autobuild` and `/analyze`
still allow-lists one name, `github/codeql-action`; the detect script
collapses all three `uses:` lines to it in the table for the same reason.
Seen on notifications-backend in September 2026: an earlier plugin version
put each subpath in `matchDepNames`, none of which ever matched, so the
allow-list rule silently automerged nothing for that action.

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

## Why RPM lockfile refreshes can automerge

MintMaker's `rpm-lockfile` manager is its own extension to Renovate. It
reads `rpms.in.yaml`, the repositories and packages of a hermetic build,
and regenerates the `rpms.lock.yaml` next to it with
`rpm-lockfile-prototype`. An RPM cannot be pinned to a version range there,
so there is no per-package update: the whole lockfile is refreshed at once,
in one `Refresh RPM lockfiles` PR, whenever the repositories publish newer
builds. MintMaker's global config schedules those refreshes nightly, from
0:00 to 4:59 UTC, and a refresh fixing a CVE arrives as a separate
`[SECURITY]` PR that ignores the schedule. MintMaker docs:
https://konflux-ci.dev/docs/mintmaker/rpm-lockfile/

A refresh has no publish date, so the release-age delay never applies,
and the Konflux PR build is the check that matters: it prefetches the
RPMs of the new lockfile, installs them in the image, and the integration
tests run on that image. That is the same protection a base image digest
gets in Step 7, and the RPMs come from the same vendor repositories.

The setting is `"rpm-lockfile": {"automerge": true}`, a manager block, and
MintMaker documents that it covers both the regular and the `[SECURITY]`
refreshes. A package rule would not do: MintMaker notes that a rule
matching package names never applies to a lockfile refresh. The
security-only option writes `rpmVulnerabilityAutomerge: "ALL"` instead,
MintMaker's setting for automerging `[SECURITY]` refreshes above a CVE
severity, `ALL` meaning any; it is ignored once the manager block
automerges every refresh, so the file never holds both.

The two kinds of refresh often carry the same change. A `[SECURITY]`
refresh is opened when a CVE in MintMaker's database is fixed by a newer
build, and the nightly refresh picks up the same newest builds, so both PRs
can hold the same lockfile, byte for byte: RedHatInsights/scheduler had
#175 and #178 open side by side for the same `util-linux` update. Merging
either leaves the other with nothing to change. That is why the
security-only answer automerges more than it sounds: whenever the newest
builds include a CVE fix, the regular refresh is covered by it.

A threshold already set in the repo is kept rather than replaced by `ALL`.
MintMaker's `cve-automerge-*` presets set it too, `critical`, `high`,
`moderate` (`MEDIUM`) or `all`, together with a rule automerging every
vulnerability fix. Renovate merges a file's `extends` presets first and
the file's own keys on top, so a threshold written in the file wins over
the preset's; a preset left in place still automerges the `[SECURITY]`
refreshes, which is why "keep them manual" is not offered while one is
there.

## Why a base image update refreshes the RPM lockfile too

`rpm-lockfile-prototype` resolves the RPMs against the base image named in
the `context` of `rpms.in.yaml`: a package the image already has stays out
of the lockfile, and a dependency is picked to fit what the image ships.
A new base image can make that resolution stale, so MintMaker ships
`refresh-rpm-lockfiles`, a post-upgrade task that regenerates the lockfiles
inside the base image PR, and the Konflux build then tests the new base
with RPMs resolved against it. MintMaker allows the command in its global
`allowedCommands` and offers it as the `refresh-rpm-lockfiles` preset; the
skill writes the preset's rule inline instead, for the reasons of the
shared preset section below. The rule is written only when every RPM
refresh automerges: otherwise an automerged base image PR would carry an
RPM change the user chose to review. https://github.com/konflux-ci/refresh-rpm-lockfiles

## Why GitHub's auto-merge feature does the merging, and what the required checks mean

The generated file sets `platformAutomerge: true`, Renovate's default,
written out so a config from an earlier version of the plugin, which set
it to false, shows the change in the Step 3 table. Renovate then asks
GitHub to arm its auto-merge feature on each PR it opens, and GitHub
merges the PR the moment the branch rules allow it: minutes after the
required checks pass, on any run or none. Renovate's own merge still runs
as a fallback, on the next run where the branch got no new commit and
every check on it is green (`lib/workers/repository/update/branch/index.ts`
calls `checkAutoMerge` whatever `platformAutomerge` says), so a repository
whose exemption is not applied yet still merges, one PR per run, as the
plugin's earlier versions did.

GitHub's auto-merge does not honor a bypass actor in the "Always allow" or
"For pull requests only" modes: the PR stays blocked with every check
green. It honors the Exempt mode, since an exempt actor is never asked for
the approval at all. Both measured on a public test repository;
`references/github-branch-protection.md` has the dated results. That is
why Step 11 asks for Exempt and nothing else, and why the "Allow
auto-merge" repository setting is back on the checklist: without it
Renovate cannot arm the merge and falls back to its own.

GitHub's auto-merge reads the required checks of the base branch and
nothing else, so those checks are the whole gate, and Step 9 is where the
user takes them on: a check that is not required never holds a merge, red
or not, and with no required check a PR merges as soon as it opens. The
`ignoreTests` option of earlier versions is gone with the choice it
served: Renovate's own merge waits for every check on the PR, required or
not, which only matters on the fallback path.

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

Every merge moves the base branch, and `rebaseWhen: auto` resolves to
`behind-base-branch` for a branch with automerge on and to `conflicted`
for the others (`lib/workers/repository/update/branch/reuse.ts`), so on
MintMaker's next run, every four hours, twice a day on busy Konflux
clusters (the four-hour base schedule is in its docs, the busy-cluster
cadence comes from the MintMaker operators), every other automerge PR is
force-pushed and its checks rerun, while the PRs on manual review stay as
they are until they conflict. Ten single PRs are ten merges and ten
rounds of rebuilds; when the branch rules require branches to be up to
date, they are also ten MintMaker runs, since a behind PR cannot merge
before its rebase. Seen on a Go repository in September 2026: twenty open
MintMaker PRs, the concurrent limit, fourteen of them green, and each of
them force-pushed five to fifteen times, against zero to two for the major
bumps on manual review.

A group PR lands every member in one merge. The skill groups per
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

## Why the config says nothing about rebasing

Earlier versions asked whether to rebase an open PR whenever the base
branch moves or only on conflict, and wrote `rebaseWhen: conflicted` for
the second answer. With GitHub doing the merging the question is moot:
Renovate's `platformAutomerge` docs say GitHub "might automerge a Renovate
branch even if it's behind the base branch at the time", so a green PR
merges before Renovate's next run gets to rebase it, whatever `rebaseWhen`
says. What decides whether every merge is tested against the branch it
lands on is GitHub's own rule, "Require branches to be up to date before
merging", in the checks ruleset. With it, a behind PR waits for Renovate's
next run to rebase it and rerun its checks, so merges land one MintMaker
run apart; without it, a green PR merges within minutes, as tested against
the base it was opened on, the case Renovate's `rebaseWhen` docs warn
about for `conflicted`. The rule applies to every PR on the branch, human
ones included, so the plugin neither asks for it nor recommends it: the
scan reads it as `up_to_date_required`, and the Step 10 tip says what the
current setting means for the merges. `rebaseWhen` itself stays out of the
file: `auto` already resolves to `behind-base-branch` under automerge, and
`conflicted` would leave a behind PR unrebased, and unmergeable under the
up-to-date rule. MintMaker's `tekton` and `lockFileMaintenance` blocks set
`rebaseWhen: behind-base-branch` themselves.

A merge queue would give retesting and throughput at once, and GitHub's
queue admits a PR armed by an exempt actor, measured on the test
repository. The plugin does not set one up: the queue runs the checks on
a `merge_group` event, and Pipelines-as-Code, which runs the Konflux PR
pipeline, has no handler for that event (none in its source as of
2026-10-08), so the queue would wait on a required check that never
comes.

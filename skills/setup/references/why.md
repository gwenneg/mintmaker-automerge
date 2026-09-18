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
have the `pinDigest` update type and stay manual.

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
MintMaker runs every four hours from 00:00 UTC, so the last run inside
that window is Thursday 20:00 UTC, and a `timezone` line moves the window
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


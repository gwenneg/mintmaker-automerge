# Why the config looks the way it does

Read this when the user asks why a rule exists or why an alternative was not
chosen. The short form of each point is a comment in the generated config;
this file is the long form.

## The goal, and what stays out of scope

The goal isn't to edit a config file. It is to cut the engineering time
spent merging routine, low-risk dependency bumps, so that review effort
goes to the few bumps where a human's judgment matters. Every patch or minor
bump that needs someone to notice a PR, skim it, and click merge is a small
recurring tax. Letting Renovate merge the safe ones removes that tax without
removing review from the updates that need it.

The scope is deliberate. Narrow, explicit, config-driven rules (an
allow-list, a release-age delay, carve-outs for known-risky packages) are
what make it acceptable to remove the human from the loop for this category
of update, because nothing depends on a reviewer catching a bad release in
the moment. Bumps that are too complex or context-dependent for Renovate's
rules to judge are a different problem with a different solution, for
instance an AI-assisted review of the specific bump, and out of scope here.

Setting that expectation up front matters. A user who thinks this will
handle all their dependency updates will be alarmed the first time a
major-version PR still waits for them. A user who understands the scope
reads that as the system working as designed.

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

- The delay covers every update, whether it automerges or waits for a
  human.
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
registry reports no publish date is not delayed.

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
per team:

1. Every patch and minor bump. It relies on the release-age delay as the
   defense against a compromised release.
2. Development dependencies only. The runtime dependency list never changes
   unattended, but build and test tooling does. It runs in CI on those PRs,
   install scripts included, and a bundler or compiler among it produces
   the shipped artifact.
3. An allow-list, like the actions rule. Strongest, and the most
   maintenance.

For Go, MintMaker's global config enables updates of indirect dependencies
(`matchDepTypes: ["indirect"]` in its `gomod` block), so option 1
automerges them too.

## Why the Tekton block can automerge

MintMaker's `tekton` manager only reads `.tekton/**`. The updates are task
bumps from the Konflux catalog, pinned by digest, and the pipeline
migrations MintMaker runs alongside them with its post-upgrade tool. They
are the pipeline itself, so the PR's own Konflux build runs the updated
pipeline: if the migration breaks the build, the check fails. That only
blocks the merge when the Konflux PR pipeline check is required, because
GitHub's auto-merge waits for required checks alone. The block sets
`automerge` for the whole manager, so every update type it produces is
covered, the task replacements MintMaker configures included.

`"schedule": ["at any time"]` is a separate decision. MintMaker's global
config schedules the tekton manager on Saturdays; the override makes
pipeline updates arrive within hours instead. Dropping the line keeps the
weekly batch.

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

A repo that already extends a shared preset should know what the preset
sets. A `minimumReleaseAge` shorter than MintMaker's weakens the delay
without anything in the repo showing it, because repo config wins over the
global one.

## What the validator checks

`renovate-config-validator` checks syntax and schema. MintMaker's docs say
it "cannot verify that, for example, a file matching pattern will actually
match any files in your repository". A misspelled package or action name
passes and silently matches nothing.

## Why required status checks are the gate

Renovate merges through GitHub's auto-merge (`platformAutomerge`, on by
default), which only waits for required checks. Renovate's docs, in the
`platformAutomerge` entry, say that without the platform's own
"Require status checks before merging" rule the platform might merge
Renovate PRs even if the repository's tests have not started, are still in
progress, or have failed. The full GitHub-side steps are in
`github-branch-protection.md`.

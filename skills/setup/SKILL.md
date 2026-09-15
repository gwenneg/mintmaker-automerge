---
name: setup
description: Turns on Renovate automerge for low-risk dependency updates in a Konflux-onboarded repository, one decision at a time, and documents the GitHub branch-protection changes it needs. Run it from the repository with /mintmaker-automerge:setup.
disable-model-invocation: true
model: sonnet
allowed-tools:
  - Bash(${CLAUDE_SKILL_DIR}/scripts/detect.sh)
---

# Renovate automerge setup

A guided conversation in twelve short steps that ends with a reviewed Renovate config on a branch, an open PR, and the GitHub settings in place.
Automerge is a trust decision, so the user makes every consequential choice; your job is to make each choice small, well framed and quick to answer, and to teach just enough along the way.

## Rules

The user is in a terminal.
Claude Code renders Markdown tables, bold, code and emoji, and AskUserQuestion draws a selection menu.

**The shape of a step.** Every step, 1 to 12, is one reply in two parts, in this order: the screen, as ordinary assistant text, then the step's one AskUserQuestion call, which ends the reply; the answer starts the next.
The screen opens with the header `### ▶️ Step N/12 <title>`, then a table or a few bullets with what was found and at most one 💡 note, under about twelve lines.
Nothing comes between the two parts, no tool call and no line; whatever a step needs to read or run comes before the screen.
Claude Code renders text in full and folds only thinking into a one-line summary, so a reply that goes from an answer straight to a menu call shows the user nothing.

The reply to an answer opens with the next step's header: no acknowledgement, no announcement, no extra question, and nothing before the header, a skipped step included, whose `Skipped:` line comes after its header and is followed by the next screen, never by a question.
A step the report makes moot still prints its full `### ▶️ Step N/12 <title>` header line, then one line saying why, then the next step's full screen in the same reply.
A step closes with a plain line only where this file spells one out, because it carries a fact the user needs; the exceptions to the shape are written out where they apply: the how-to of Step 2, Step 8's closing line, the `.jsonc` case of Step 3, and the write phase of Step 10.

**Menus.** Every decision is an AskUserQuestion, all of a step's questions in one call, up to four.
The recommended option comes first with "(Recommended)" inside its label, as in `Rename to renovate.jsonc (Recommended)`, exactly one per question, in a multi-select too; the mark does not show in a description. The one question without it is the Branches question of Step 2: whether a branch keeps getting MintMaker PRs is not this skill's call.
Each option's description states its consequence in one line.
Never offer a single option: the tool rejects it.
A follow-up for typed input, package names or a reason, is an AskUserQuestion call as well, with two options: `I'll type them (Recommended)`, the user typing the answer in its place, and `None after all`, which falls back to the recommended answer of the question it follows; a question asked as plain text ends the reply with nothing to answer.
After the follow-up, go on to the next step.

**Notes and emoji.** The 💡 notes in this file are shown where they stand, verbatim, one or two sentences each: they are how the user learns what Renovate and MintMaker do while deciding.
When the user asks why, answer from `references/why.md` in a few lines.
Emoji, each with one meaning: ⚠️ needs attention, as a table status or a one-line warning where this file places one, ✅ its opposite, as a table status or opening a Currently line of Step 11, 🟢 automerges, 🛑 stays manual, 💡 a note, ▶️ before every step header, 🤖 once in the welcome title, 1️⃣ 2️⃣ 3️⃣ the three settings of Step 11, each followed by two spaces, since terminals draw a keycap wider than they count it.
None in prose.

**The report.** The bundled `scripts/detect.sh` scanned the repository when this skill loaded; its output is under "Repo facts" below.
It is read-only, looks at tracked files only, and is never run again: Steps 1 to 10 read from it.
Its last sections hold the Step 1 and 3 screens, the Step 2 table, the Step 4 candidates and the Step 5, 6 and 7 tables, ready to print verbatim.
Only when the report is missing entirely, detect by hand from `git ls-files`, never `find`, which walks `node_modules/`, `target/` and vendored directories.

**GitHub.** The report's Tooling section says whether `gh` is logged in.
It is the easiest route and never a requirement: the REST API over `curl` with a `GITHUB_TOKEN` or `GH_TOKEN` from the environment, the raw file URL for public files, `git` for branches and refs, and as a last resort a link the user opens with the text to paste.
Pick the route, say which in a few words, and never ask the user to install or log into anything.

**Trust.** The user chooses what gets automerged: never generate the whole config unilaterally, and never change a GitHub setting, even with confirmation.

## Repo facts

!`"${CLAUDE_SKILL_DIR}/scripts/detect.sh"`

## Welcome screen

Print this verbatim on every run, the stop path included, then the Step 1 screen in the same reply, so the first menu the user meets is the one confirming the detected ecosystems.

```
### 🤖 MintMaker Automerge Setup

This plugin turns on automerge for the dependency updates you decide are low-risk, gated by your CI checks and by MintMaker's release-age delay. Everything else still needs a reviewer, human or AI, so your attention goes to the updates that deserve it.

How this works:
- Twelve short steps, a few quick decisions along the way, about twenty minutes end to end.
- The config is written only after you approve the summary, in Step 10.
- GitHub settings are checked and explained in Step 11, each with a link to its page, but never changed by this skill: you apply them yourself, which requires the Admin role on the repository.
- The PR is opened only after you approve it, in Step 12.
```

## Step 1: Detected ecosystems

The report's Screens section holds this screen: the Konflux check line and the ecosystems table, or the stop message.
Print it verbatim, tables included.
On the stop message the conversation ends there: this skill only applies to repos onboarded in Konflux, and improvising a generic Renovate setup is not it.
The table lists the ecosystems found and the files behind them; what automerges is decided in Steps 4 to 8 and shown in Step 10.
Under the table, not on the stop message, this note:

💡 MintMaker already opens PRs for every ecosystem in this table. The next steps only decide which of those PRs stop waiting for you.

Only when the report's `ignored_by_renovate` line names files, add one sentence to the note naming them: MintMaker inherits Renovate's `config:recommended`, which skips dependency files under `test/`, `tests/`, `examples/`, `vendor/` and similar directories, so those files never get a PR.

Ask, header "Ecosystems": Looks right (Recommended) / Needs a correction, the fix typed as the answer, since detection can be wrong, a `pom.xml` kept for a subproject nobody builds.
The screen's Repository line is the report's `github_repo`, the upstream when `fork: yes`; a correction naming another repository replaces it for Steps 11 and 12, and Step 11's current-state lines then read `not checked, repository corrected in Step 1`.
When the default branch is `unknown`, add a "Default branch" question to the same call, with the report's `current_branch` as the recommended option.

## Step 2: Branches MintMaker updates

The report's Branches section lists the branches MintMaker runs on, read from the pull-request pipelines in `.tekton/`, one line per branch with its namespace and every Konflux component and pipeline that targets it; the Screens section holds this step's table, one row per branch with the first pipeline and a `+N` for the others.
One branch in the report: print the header `### ▶️ Step 2/12 Branches MintMaker updates`, then one line, `Skipped: MintMaker runs on one branch, \`<branch>\`.`, then the Step 3 screen in the same reply.
Otherwise the header, the table verbatim, this note, then one question.

💡 Renovate reads this repo's config from the default branch only, and MintMaker runs one job per branch in this table, so the rules you choose next apply to every branch here. The Renovate config cannot switch a branch off: security fixes still get PRs there, and `baseBranchPatterns` makes the jobs of the other branches run on `<default_branch>` too, two identical jobs at once, which MintMaker warns leads to conflicts. The only switch is in Konflux: an annotation on each component that builds the branch, set with `oc`.

In the note and the how-to, `<default_branch>` is the report's `default_branch` and `<branch>` the branch chosen.
When the report's `oc:` line says yes, the install line of the how-to is left out.

Header "Branches", question "Should MintMaker stop opening PRs on one of these branches?", no option marked recommended: `No, keep MintMaker on every branch`, the rules chosen next apply to all of them / one option per branch other than the default, `Show me how to switch it off on <branch>`, the steps printed next, once per component of the branch, nothing applied by this skill.
More than three such branches: one option `Show me how to switch it off on a branch I'll name`, the branch typed as the answer.
On "No", the reply opens with the Step 3 header.
On a branch, the reply opens with the how-to below for that branch, its placeholders filled from the report's `branch:` line, and ends with one more question, header "Next", question "Ready to move on to the Renovate config?": `Yes, go to the next step (Recommended)` / `I need more with this step`. On the second, explain from `references/why.md` in a few lines, answer what the user asks, then ask again; on the first, the reply opens with the Step 3 header. The how-to is the one place a reply to an answer does not open with a step header, and Step 2 the one step with a second question of its own.
The how-to shows one component, the first of the report's `components=` list, under a line saying the steps are done for each component, since MintMaker's docs say a branch with several components needs each one annotated.
A `namespace` or a component the report gives as `unknown` stays a placeholder, with one line saying the Konflux UI shows both on the component's page.

```
### Switching MintMaker off on `<branch>`

Install `oc`, which is not on your PATH, by following the OpenShift CLI documentation: https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/cli_tools/openshift-cli-oc#cli-installing-cli_cli-developer-commands

Log in. In the Konflux UI, open the help menu, the question mark in the header, then `Copy login command`, and run it in your terminal. The `--web` flag opens your browser to authenticate, so there is no token to paste.

For each component that builds `<branch>`:

1. Annotate the component:
   `oc -n <namespace> annotate component/<component> mintmaker.appstudio.redhat.com/disabled=true`
2. Verify; this must print `true`, the only value MintMaker honors:
   `oc -n <namespace> get component <component> -o jsonpath='{.metadata.annotations.mintmaker\.appstudio\.redhat\.com/disabled}'`

The Konflux UI shows nothing for the annotation. The component's `Dependency updates` tab just stops getting runs.

To undo it, remove the annotation from each component with a trailing dash: `oc -n <namespace> annotate component/<component> mintmaker.appstudio.redhat.com/disabled-`.
```

`<namespace>` and `<components>` come from the report's line for that branch, and `<component>` is the first of those components.

## Step 3: Renovate config file

The report names every config file found, with its full content and the other files that name it, and its Screens section holds this step's table: what gets removed or is redundant, which presets were read, or one plain line when there is nothing of the kind.
Every ⚠️ row is removed in Step 10, for the reason the row gives; existing custom rules are preserved.
When a row names a shared preset, its content is in the report: say what it sets under the table, in particular a `minimumReleaseAge` shorter than MintMaker's.
Only when the report says it could not fetch it, read it before the screen.

The screen: the header, the table verbatim, this note, then one of three cases.

💡 MintMaker runs Renovate with its own global config and merges this file on top, so this file only holds what is specific to this repo. Package rules add up, but a list such as `enabledManagers` replaces MintMaker's list outright and would turn off every manager not named here.

- **A `.jsonc` or `.json5` file exists.** No question: close with one line saying the file stays where it is, then the Step 4 screen in the same reply.
- **A strict `.json` file exists.** This line verbatim, the file name filled in, with no other lead-in, then a question, header "Rename": `Rename to renovate.jsonc (Recommended)`, for the comments / `Keep .json`, the comments then show as errors in some editors.
  On rename, the report's "is named in" line lists the files to update, a workflow path filter, a README, an AGENTS.md: a rename that breaks a validator workflow is worse than none.

  `<config file>` is a strict `.json` file, and every rule written by this plugin has a comment saying why it exists: Renovate accepts comments in a `.json` file, but editors such as VS Code flag them as errors there, and `.jsonc` is the file name that allows them.
- **No config.** Question, header "Location": `renovate.jsonc` at the root (Recommended), the first place Renovate looks and the one MintMaker's docs use / `.github/renovate.jsonc`.

## Step 4: Libraries

For the library ecosystems found (Maven, Gradle, Go, npm, Python, Cargo, Bundler): this screen, then three questions in one call, a fourth when `go.mod` was found.
The report's manual-review candidates are not listed on the screen; they are the first option of the second question.

```
### ▶️ Step 4/12 Libraries

Proposed rule for <the library ecosystems found, e.g. Go modules and npm>: patch and minor bumps merge on their own once CI passes, majors stay on manual review. Narrow or widen it below.
```

💡 Whichever option you pick below, the same two protections apply: MintMaker's release-age delay and your required GitHub checks. "Development dependencies only" is not the safe choice it sounds like: a compromised dev dependency still runs in CI, where it can read secrets and alter the build.

Header "Scope": Every patch and minor bump (Recommended) / Development dependencies only, where the manager knows the difference, npm does / Only packages I'll name, the names in a follow-up / Decide per ecosystem, one question per ecosystem with the first three scopes.

Header "Never automerge", question "Any packages that should never be automerged, whatever the scope?", multiSelect: one option per candidate of the report, marked (Recommended), the report's reason as its description, several candidates folded into one option / Other packages, I'll name them, the names in a follow-up / None, marked (Recommended) when the report has no candidate.
These packages still get PRs, on manual review whatever the update type.

Header "Majors", question "Any packages whose major bumps may automerge too?": No package, majors stay on manual review (Recommended) / Yes, for packages I'll name.
Propose no candidates, here and in Step 6: which majors are safe unattended is project knowledge, a test framework with good coverage or a tool used only in CI, and a guess widens the scope beyond what was asked.
Ask in the follow-up why their majors are safe: that reason becomes the rule's comment, and CI is the only gate on them.

Header "Go indirect", when `go.mod` was found: Automerge indirect dependencies too (Recommended), MintMaker's global config opens PRs for them / Keep them manual.

## Step 5: Build toolchains

`toolchains: none` in the report: print the header `### ▶️ Step 5/12 Build toolchains`, then one line, `Skipped: no build toolchain pinned in this repo.`, then the Step 6 screen in the same reply.
Otherwise the header, the report's toolchains table verbatim, the note, then one question.

💡 These are every developer's build tool, not just CI's: `mvnw` and `gradlew` download the version they pin, the `toolchain` line of `go.mod` makes the `go` command fetch that exact compiler, and `packageManager` is what corepack installs. Renovate bumps them like any dependency, so they get a rule of their own instead of falling under the patch-and-minor rules of Step 4.

Header "Toolchains": Keep manual (Recommended), updates are rare and a bad one breaks every developer's local build, not just CI / Automerge patch and minor, CI builds with the new toolchain on every PR.

## Step 6: GitHub Actions

No workflow in the report: print the header `### ▶️ Step 6/12 GitHub Actions`, then one line, `Skipped: no GitHub workflows in this repo.`, then the Step 7 screen in the same reply.
Otherwise the header, the report's actions table verbatim, the note, then three questions in one call.

💡 In March 2025 the `tj-actions/changed-files` action was hijacked: every release tag was moved to a malicious commit, so workflows pinned to a tag ran it and workflows pinned to a SHA did not. With a SHA pin, a moved tag becomes a PR that never automerges; with a tag pin, CI runs the new code with no PR at all.

Header "Pin actions", only when the table has tag-pinned actions: Pin every action to a SHA (Recommended), Renovate opens one manual PR per action to replace the tag with its SHA and a version comment / Don't pin, the allow-list then guards version bumps only, not moved tags.

Header "Allow-list", multiSelect, options built from the table's "Maintained by" column: Actions maintained by GitHub (Recommended), the `actions/*` and `github/*` ones, named in the description / Third-party actions, the rest, named with their owners / I'll type which ones to allow.
Both groups ticked allows every action; a typed answer replaces the groups.
Reusable workflows stay out: they are workflows called with `uses:`, not actions.
An action pinned to a bare SHA without a version comment gets no PRs at all, since Renovate cannot tell which version it is; say so and name the fix, a `# vX.Y.Z` comment.

Header "Majors", question "Any actions whose major bumps may automerge too?": No action, majors stay on manual review (Recommended), a major often changes an action's inputs or the Node runtime it needs / Yes, for actions I'll name, which must be on the allow-list, the reason in the same follow-up.

## Step 7: Base images

No container file in the report: print the header `### ▶️ Step 7/12 Base images`, then one line, `Skipped: no container file in this repo.`, then the Step 8 screen in the same reply.
Otherwise the header, the report's base images table verbatim, the note, then up to two questions in one call, the second only when relevant.

💡 The release-age delay does not cover most base images: Renovate only learns publish dates from Docker Hub, and MintMaker treats a release without one as old enough. For an image from `registry.access.redhat.com` or `quay.io`, your required checks are the only protection, and the Konflux PR build is the check that actually builds on the new base: remember that in Step 11.

Header "Base images": Automerge digest, patch and minor bumps (Recommended), the Konflux PR build builds the image and the tests run on it, majors such as a new RHEL or JDK line stay manual / Keep them manual.
Header "Pin base images", only when an image has no digest: Pin to `tag@sha256` (Recommended), Renovate opens one manual pin PR, after which rebuilds of the same tag arrive as digest PRs / Keep tags only, rebuilds then go unnoticed.

When the table flags a `latest` tag, one line above the questions: a `latest` tag carries no version, so Renovate has nothing to bump; with the digest pinned, rebuilds of `latest` arrive as digest PRs, the only update those files can get.
The automerge option then says "digest updates" rather than "patch and minor".

## Step 8: Merge days

The screen is the header and the framing line, printed verbatim, then the menu.

```
### ▶️ Step 8/12 Merge days

Renovate opens, rebases and merges PRs only on the days chosen below; vulnerability fix PRs ignore them. The Konflux pipeline follows its own schedule, the second question.
```

Two questions in one call.
Header "Merge days", question "On which days may updates open and merge?": Any day (Recommended), MintMaker runs every four hours and a bump merges within hours of clearing the release-age delay / Monday to Thursday, no PR opens, rebases or merges from Friday to Sunday, UTC, so a bump due on a Friday waits for Monday / Other days, I'll type them, the days in a follow-up.
Header "Pipeline": Konflux pipeline updates on the same days as the rest (Recommended), within hours of a catalog bump, since task bundles carry no publish date for the release-age delay / Keep MintMaker's Saturday batch, pipeline PRs then open and merge on Saturdays whatever the merge days say.
When the report flags path-filtered PR pipelines, add a third option, Keep pipeline updates manual, and say in the question why: a path-filtered pipeline cannot be a required check, so a `tekton` PR for it would merge before its build reports.

Close the step with one line: `Rules chosen.
Summary in Step 10.`
That line opens the reply to this step's answer, and the same reply goes on with the Step 9 screen, or its Skipped line and the Step 10 screen: nothing of it is held back for a later reply.

## Step 9: Other updaters

`dependabot.yml: none` and `base_image_workflows: none` in the report: print the header `### ▶️ Step 9/12 Other updaters`, then one line, `Skipped: no other updater in this repo.`, then the Step 10 screen in the same reply.
Otherwise two updaters on one ecosystem race to open a PR for the same bump: the screen is the header, one table of every other updater found, then the note, then the questions in one call.

Columns: updater, what it covers, status.

- One row per workflow of the `base_image_workflows` line, typically a home-grown base-image update, with its path and the `FROM` lines it touches.
  Status: ⚠️ overlaps Renovate when Step 7 chose to automerge base images, else "not covered by Renovate" without a mark.
- One row per entry under the `dependabot.yml: found` line, with ecosystem and directory.
  Status: ⚠️ overlaps Renovate for an ecosystem the report lists, since MintMaker's Renovate opens PRs for it whatever automerges; ✅ not covered by Renovate for one it does not list; ⚠️ directory missing for a stale entry, which covers nothing since Dependabot silently finds no files there, flagged whatever the overlap.

💡 Removing `dependabot.yml` stops Dependabot's update PRs, not Dependabot alerts, which are a separate GitHub setting. Keep the alerts on: MintMaker's vulnerability fix PRs are built from them.

Header "Base image workflow", only when a workflow row overlaps: Remove it, Renovate covers this now (Recommended) / Keep it, two updaters on the same FROM line.
Header "Dependabot", only when `dependabot.yml` exists: every entry overlapping, Remove `dependabot.yml` (Recommended) / Keep it, two PRs per bump; some entries not overlapping, Narrow it to the entries Renovate doesn't cover (Recommended) / Remove it entirely / Keep it.
Next to the Remove option: this removes Dependabot version updates only; the Dependabot alerts setting under Settings, Advanced Security stays on, because Renovate's vulnerability fix PRs are built from those alerts.

The answers are applied in Step 10, after "Write it", never here.

## The config blocks

Assemble the config in Step 10 from the two blocks below, driven by the answers of Steps 4 to 8.
Never fetch an example config from another repository: these blocks are the reference.

### The skeleton

Header comment, the optional `extends` block for action pinning, the `tekton` block, and a `{{PACKAGE_RULES}}` placeholder.
Drop the `extends` block when the user declined pinning or every action is already SHA-pinned; drop the `tekton` block's `schedule` line and its comment when they kept the Saturday batch.
Merge days other than any day add the two lines of the merge-days block below, right after the header comment, and the `tekton` block's `schedule` line then takes the same cron with the comment `// Same days as the rest, instead of MintMaker's Saturday batch.`
Typed merge days become a cron with `*` for the minutes, the way MintMaker writes its own schedules, `0` being Sunday; a timezone named in the answer becomes a top-level `"timezone"` line with its IANA name, and without one the days are UTC.
The days are a `schedule`, not an `automergeSchedule`: Renovate ignores the latter once GitHub's auto-merge is on, and the schedule bounds the merge because a PR merges as soon as the checks of its last rebase pass.
The comments are part of the file the user keeps: copy them as they are, never add instructions meant for you, and never restate what the header already says.

```jsonc
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  // Renovate overrides for this repository. MintMaker merges them on top of its
  // global config, which sets the managers, the release-age delay, the
  // vulnerability alerts, branch naming and PR limits:
  // https://github.com/konflux-ci/mintmaker/blob/main/config/renovate/renovate.json
  // A key set here replaces the inherited value; packageRules are added to the
  // inherited ones; enabledManagers would replace the whole list, so it is never set.
  // Policy: patch and minor updates of the ecosystems below merge on their own once
  // the required checks pass. Majors stay on manual review unless a rule names them.
  // MintMaker docs: https://konflux-ci.dev/docs/mintmaker/user/
  // Automerge set up with the MintMaker Automerge plugin: https://github.com/gwenneg/mintmaker-automerge
  "extends": [
    // Pins actions to commit SHAs, so a version bump can be told from a moved tag.
    "helpers:pinGitHubActionDigests"
  ],
  "tekton": {
    // Konflux pipeline updates in .tekton/: the PR's own Konflux build tests them.
    "automerge": true,
    // Any day, instead of MintMaker's Saturday batch.
    "schedule": ["at any time"]
  },
  "packageRules": [
    {{PACKAGE_RULES}}
  ]
}
```

The merge-days block, here for Monday to Thursday:

```jsonc
  // PRs open and rebase Monday to Thursday, UTC, and merge once their checks pass.
  // Vulnerability fix PRs ignore the schedule.
  "schedule": ["* * * * 1-4"],
```

### The rule blocks

One block per Renovate manager, with variants where a choice exists.
Copy the blocks for the detected ecosystems into the placeholder, fill the names marked `<...>`, and copy exactly one variant where several are offered.
Rules apply in order and a later rule overrides an earlier one, so a manual-review rule or a majors rule goes after the ecosystem rule it narrows or widens.
Everything MintMaker's global config already sets stays out of the file; if the user asks for a key the blocks don't have, check the global config first, since a duplicate drifts out of sync.

Each ecosystem opens with a separator line that states its decision, the same facts as its row of the Step 10 table: what merges on its own, then what stays manual.
That line is the comment of the plain patch-and-minor rule, which carries none of its own.
A rule that narrows or widens the policy carries one or two lines saying why, and nothing else: no "optional", no "delete if", no restating of the policy.

```jsonc
[
  // --- github-actions: patch and minor of the actions named below; majors, digest-only and every other action stay manual
  {
    // Vetted by name: an action runs arbitrary code in CI. Patch and minor only, so a
    // moved tag with no version change, the shape of a hijacked action, never merges alone.
    "matchManagers": ["github-actions"],
    "matchUpdateTypes": ["patch", "minor"],
    "matchDepNames": ["<action-in-use>", "<action-in-use>"],
    "automerge": true
  },

  // --- maven: patch and minor; majors, <the manual-review packages> and the wrapper stay manual
  {
    "matchManagers": ["maven"],
    "matchUpdateTypes": ["patch", "minor"],
    "automerge": true
  },
  {
    // The wrapper is every developer's build tool, not just CI's.
    "matchManagers": ["maven-wrapper"],
    "automerge": false
  },

  // --- gradle: patch and minor; majors, <the manual-review packages> and the wrapper stay manual
  {
    "matchManagers": ["gradle"],
    "matchUpdateTypes": ["patch", "minor"],
    "automerge": true
  },
  {
    // The wrapper is every developer's build tool, not just CI's.
    "matchManagers": ["gradle-wrapper"],
    "automerge": false
  },

  // --- dockerfile: digest, patch and minor of the base images; majors stay manual
  {
    // The Konflux PR build builds and tests the image. A digest update is a rebuild of
    // the same tag; a new RHEL or JDK line is a major and stays on manual review.
    "matchManagers": ["dockerfile"],
    "matchUpdateTypes": ["digest", "patch", "minor"],
    "automerge": true
  },
  {
    // Pins FROM lines to tag@sha256, so rebuilds of a tag arrive as digest PRs.
    "matchManagers": ["dockerfile"],
    "pinDigests": true
  },

  // --- gomod: patch and minor, indirect dependencies included; majors and the toolchain stay manual
  {
    "matchManagers": ["gomod"],
    "matchUpdateTypes": ["patch", "minor"],
    "automerge": true
  },
  {
    // Indirect dependencies stay on manual review.
    "matchManagers": ["gomod"],
    "matchDepTypes": ["indirect"],
    "automerge": false
  },
  {
    // The toolchain line is every developer's compiler, not just CI's.
    "matchManagers": ["gomod"],
    "matchDepTypes": ["toolchain"],
    "automerge": false
  },

  // --- npm: patch and minor; majors, packageManager and engines stay manual
  {
    "matchManagers": ["npm"],
    "matchUpdateTypes": ["patch", "minor"],
    "automerge": true
  },
  {
    // Development dependencies only: the runtime dependency list never changes unattended.
    "matchManagers": ["npm"],
    "matchDepTypes": ["devDependencies"],
    "matchUpdateTypes": ["patch", "minor"],
    "automerge": true
  },
  {
    // packageManager and engines pin every developer's tools, not just CI's.
    "matchManagers": ["npm"],
    "matchDepTypes": ["packageManager", "engines"],
    "automerge": false
  },

  // --- python: patch and minor; majors stay manual
  {
    "matchManagers": ["pip_requirements", "pip_setup", "pipenv", "poetry", "pep621"],
    "matchUpdateTypes": ["patch", "minor"],
    "automerge": true
  },

  // --- cargo: patch and minor; majors stay manual
  {
    "matchManagers": ["cargo"],
    "matchUpdateTypes": ["patch", "minor"],
    "automerge": true
  },

  // --- bundler: patch and minor; majors stay manual
  {
    "matchManagers": ["bundler"],
    "matchUpdateTypes": ["patch", "minor"],
    "automerge": true
  },

  // manual review, any manager
  {
    // <the candidate's line from the report, name first: Quarkus follows an LTS track, so a reviewer picks the target version. https://quarkus.io/releases/>
    "matchManagers": ["<manager>"],
    "matchPackageNames": ["<pattern>"],
    "automerge": false
  },

  // majors of named packages, any manager
  {
    // Majors of these packages merge too: <the user's reason>. CI is the only gate.
    "matchManagers": ["<manager>"],
    "matchPackageNames": ["<package>", "<package>"],
    "matchUpdateTypes": ["major"],
    "automerge": true
  },

  // allow-list width, any manager
  {
    // Only these packages merge on their own; the rest of <manager> stays manual.
    "matchManagers": ["<manager>"],
    "matchPackageNames": ["<package>", "<package>"],
    "matchUpdateTypes": ["patch", "minor"],
    "automerge": true
  }
]
```

How the answers map to the blocks:

- Toolchains: the wrapper rules, the gomod toolchain rule and the npm packageManager rule are the toolchain rules; they stay as written when the user kept them manual or the step was skipped, and they stand whatever the scope of their manager, an allow-list included, since the file says what was decided.
  When the user opted in, each toolchain rule of a manager the report found becomes `"matchUpdateTypes": ["patch", "minor"], "automerge": true`, with the comment `// CI builds with the new toolchain on every PR.`, and the separator lines say the toolchain merges.
  Its `matchDepTypes` list stays as written: `engines` stays next to `packageManager` even when the report lists no engines pin, since the rule describes the policy, not the repo's current files.
- Manual-review packages: the "manual review" block once per candidate kept or package named, after the rule of its manager, with the pattern and comment the report gives for a candidate, under the manager whose files hold it.
  A package the user typed gets the managers whose files hold it and the comment `// Named during setup: stays on manual review whatever the update type.`
  Candidates folded into one menu option still get one rule each; none when the user chose none, and the separator line then names no packages.
- Base images: drop the `pinDigests` rule when the images are already pinned or the user kept tags only; drop the automerge rule when they kept base images manual, and the separator line then says so.
- Go: drop the indirect rule when the user automerges indirect dependencies; the separator line says whether they are included.
- npm: copy exactly one of the two scope rules, then the packageManager rule; the allow-list width is the "allow-list width" block with `npm` as the manager.
- Python: keep only the managers the report detected.
- Majors: one block per manager; for GitHub Actions use `matchDepNames` instead of `matchPackageNames`.
  The user's reason from the follow-up is the comment.

## Step 10: Summary

**Nothing touches the working tree before the "Write it" answer.** Up to that answer the skill has only read files and asked questions, and `git status` looks exactly as it did when the skill started.
No Write, no Edit, no `git rm` or `git mv`, no doc update, no removal decided in Step 9, and no name check that needs the file to exist.
The menu labels below are fixed: a menu that says the files are already written means the order was wrong, not that the labels need adapting.

Show the whole trust decision in one table: one row per detected ecosystem, one for the Konflux pipeline, one for vulnerability fixes, one for the build toolchains when the report lists any, and one row per ecosystem found that gets no rule.
This screen is never skipped and never shortened, whatever came before it, and the "Write it" menu is not asked until it has been printed: the user approves what they see in that table, nothing else.
Below it, one line with the merge days when they are not any day, the cron said in words, then one line with the Step 9 decision, when there was one, then one line with the branch switched off in Step 2, when one was, `MintMaker: to be switched off on \`<branch>\` by annotating its component(s) \`<components>\` yourself; the rules above stop applying there.`, then one line saying what the answer does: it writes files in the working tree, nothing more.
The pipeline row says "any day" when the merge days are any day, "Saturdays" when the batch was kept.
Nothing is committed or pushed before Step 12.

```
### ▶️ Step 10/12 Summary

| Ecosystem | 🟢 Automerges | 🛑 Stays manual | Why |
|---|---|---|---|
| Maven | patch, minor; majors of `org.assertj:*` | other majors, `io.quarkus*` | Quarkus follows an LTS track; AssertJ is test-only |
| GitHub Actions | patch, minor of `actions/checkout`, `actions/setup-java` | majors, digest-only, every other action | allow-list, SHA-pinned |
| Konflux pipeline | task bumps, migrations, Monday to Thursday | – | the Konflux PR build tests them |
| Vulnerability fixes | patch, minor, without the release-age delay | fixes needing a major | inherited from MintMaker |
| Base images | digest, patch, minor of `ubi9/openjdk-21` | majors, a new RHEL or JDK line | the Konflux PR build tests the image |
| Build toolchains | – | Maven wrapper | kept manual, every developer builds with it |

Merge days: Monday to Thursday, UTC. Vulnerability fixes still arrive and merge any day.

Dependabot: `dependabot.yml` removed, alerts stay on.

Writing means editing files in your working tree. Nothing is committed or pushed until Step 12.
```

Ask, header "Write it", labels `Write the files to disk (Recommended)`, described as local edits only, no commit, no push / `Change something`, with the free text saying what.

After the "Write the files" answer, and only then, the write phase, in this order:

1. Build the config file, or edit the existing one, rename it when Step 3 said so, drop every ⚠️ row of the Step 3 table, and show the diff.
   When migrating an existing config, list what you removed or restructured and why, so a rewrite never quietly drops a rule the user still wants.
2. Apply the Step 9 decisions: remove or narrow `dependabot.yml`, remove the base-image workflow, and update any doc that describes what they covered.
   Files those tools wrote, such as a digest tracking file, go with the workflow that wrote them; say so in one line.
3. Check the names.
   The validator workflow below checks syntax and schema only: a misspelled package or action name passes and silently matches nothing.
   Compare every name in the rules against the files and workflows of the scan yourself, and say `Written, every name checked against the repo.`
4. The validator workflow, below.

A bad edit to the Renovate config otherwise surfaces only when MintMaker chokes on it; there is no local build step.
The report's `validator_workflow` line names an existing one.
When it exists, say so in one line.
When missing, add this workflow, show the file, and close the step with one line: no question, since there is nothing to decide.

```yaml
# Never make this workflow a required status check. It only runs when
# {{CONFIG_FILENAME}} changes; on any other PR GitHub keeps a skipped required
# check "Pending" forever, so every dependency PR would be blocked from merging.
name: Renovate Config Validator
on:
  pull_request:
    branches:
      - {{BASE_BRANCH}}
    paths:
      - {{CONFIG_FILENAME}}
  push:
    branches:
      - {{BASE_BRANCH}}
    paths:
      - {{CONFIG_FILENAME}}
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: {{CHECKOUT_ACTION}}
      # The same action MintMaker runs on its own repository. It checks syntax
      # and schema only: a rule that matches no file or package still passes.
      - uses: konflux-ci/renovate-config-validator-action@{{VALIDATOR_ACTION_REF}} # main
        with:
          config_file: {{CONFIG_FILENAME}}
          strict: true
```

Fill in `{{BASE_BRANCH}}` from Step 1, `{{CONFIG_FILENAME}}` from Step 3, `{{CHECKOUT_ACTION}}` pinned the way the repo's other workflows pin it so the new file doesn't stick out, and `{{VALIDATOR_ACTION_REF}}` with the current commit of the action's `main` branch, since it has no version tags: the report's `validator_action_main_sha` line has it, and when that says unknown, resolve it by any route that reaches GitHub, `git ls-remote` on the action's repository being the simplest.

💡 Never make this workflow a required check: it only runs when the config file changes, and GitHub blocks a PR forever when a required check never runs. With `strict: true`, it also fails when a setting in the file has been renamed or retired by Renovate, so you find out before MintMaker does.

The write phase ends there, with no question: no "does this look right", no confirmation of the files, and no question about the pull request, which is Step 12's.
With no question pending there is no answer to wait for, so the same reply goes on with the Step 11 header and the required-checks screen below, and the Checks menu comes only once that screen is printed.

## Step 11: GitHub settings

One screen, from this file, no tool call, then one menu.
The `<...>` placeholders come from the report: `github_role` and `default_branch` in the Tooling section, the required checks in the Branch rules section, the URLs in the Links section, and the three verdicts of the Step 11 status section, printed verbatim on the Currently lines, ✅ or ⚠️ included; `not checked` where the report says so.
Settings 1 and 3 each have two blocks below, a full one and a short one: the short block prints when the setting's verdict opens with ✅, the full block otherwise, `not checked` included.
Each line that names a place ends with its URL, so the terminal makes it clickable; with no GitHub remote the report has none, and the words stand alone.
Which checks to require is the user's decision: the skill suggests no list.
`references/github-branch-protection.md` is the long form for "why?" questions, not to paraphrase into the screen.

The screen, with the full blocks:

```
### ▶️ Step 11/12 GitHub settings

Three settings make automerge work and keep it safe. Changing them takes the Admin role on the repository (yours: <github_role>), and this skill changes none of them: you apply them in GitHub.

1️⃣  **Allow auto-merge**, under Pull Requests: <settings_general>

Currently on this repository: <status_auto_merge>.

Renovate marks each PR that matches your rules and asks GitHub to merge it. GitHub does so the moment the required checks pass, whatever the other checks do. With the setting off, Renovate merges the PR itself on a later run, and only once every check on it is green: one failing scan then holds every automerge.

2️⃣  **Required status checks**, the rule "Require status checks to pass" in the ruleset for `<default_branch>`: <settings_ruleset_checks, or settings_rulesets when the report has none>

Currently required: <status_checks>
- <one bullet per check in the report's required_checks, in backticks; no bullet when there is none>

This is the gate: GitHub's auto-merge waits for these checks and for nothing else. Require what proves the PR's own change is good:
- the build, and the tests when they are a separate job
- the Konflux PR pipeline, `Red Hat Konflux / <component>-on-pull-request`: the only check that runs an updated pipeline

Never require:
- a check that skips some PRs, such as the config validator or `renovate/stability-days`: GitHub keeps it "Pending" forever
- a check that goes red for reasons outside the PR, such as a vulnerability scan: one new advisory would block every PR

3️⃣  **The Konflux app bypass**, only if the base branch requires a pull request with approvals.

Currently on this repository: <status_bypass>.

That rule blocks the app like anyone else, so the app needs to bypass it, and nothing else. Organization first: if an organization ruleset already lets `Red Hat Konflux` bypass the pull request rule, nothing to do here either; with many Konflux repositories in the organization, one such ruleset from an organization owner beats repeating this in each of them.

Per repository, on rulesets (recommended): the ruleset holding "Require a pull request before merging" › Bypass list › Add bypass › `Red Hat Konflux`, the GitHub App owned by `redhat-appstudio` › "For pull requests only", so the app can never push straight to the branch: <settings_ruleset_approval, or settings_rulesets when the report has none>

On branch protection rules, only if the repository still uses them: the rule for the branch › "Require a pull request before merging" › "Allow specified actors to bypass required pull requests" › add the app: <settings_branches>

⚠️ Never let the app bypass the required checks. A bypass covers the whole ruleset, so if the ruleset holding the pull request rule also holds the required checks, move the pull request rule to a ruleset of its own before adding the bypass. On branch protection rules the bypass option is part of the pull request rule itself, so there is nothing to split.
```

The short block of setting 1, in place of its full block when `status_auto_merge` opens with ✅:

```
1️⃣  **Allow auto-merge**, under Pull Requests: <settings_general>

Currently on this repository: <status_auto_merge>.

Renovate marks each PR that matches your rules and asks GitHub to merge it. GitHub does so the moment the required checks pass, whatever the other checks do.
```

The short block of setting 3, in place of its full block, the ⚠️ line included, when `status_bypass` opens with ✅:

```
3️⃣  **The Konflux app bypass**, only if the base branch requires a pull request with approvals: <settings_ruleset_approval, or settings_rulesets when the report has none>

Currently on this repository: <status_bypass>.

That rule blocks the app like anyone else, so the app needs to bypass it, and nothing else.
```

Menu, header "Settings": `I read it, understood it, and will apply the three settings before automerge goes live (Recommended)` / `I'm not sure, help me understand`.
When all three verdicts open with ✅, the first label is `I read it, understood it, and the three settings are in place (Recommended)` instead.
On the second, explain from the reference in a few lines, the ruleset splitting and the organization ruleset in particular, and answer what the user asks, with the report's "Konflux names" and "Workflow jobs" sections as illustration of this repository's check names, never as a list to set; then ask again.

The answer is an acknowledgement, recorded as such in the PR body: the skill verifies nothing.

## Step 12: Pull request, then what to expect

The header `### ▶️ Step 12/12 Pull request`, one line, `Merging this PR is what turns automerge on.`, then this note:

💡 The new rules also apply to the PRs MintMaker already has open. On its next run, each one that matches is rebased and marked for GitHub's auto-merge, and merges once the required checks pass: the first unattended merges will most likely be those.

Then the menu, header "Ship it": Branch, commit, push and open the PR (Recommended) / Commit on a branch, I'll push myself / Stop here, keep the changes uncommitted.
Nothing leaves the machine before that answer.
Open the PR by the GitHub route available: `gh pr create`, `POST /repos/<github_repo>/pulls` with a token, or push the branch and give the link `https://github.com/<github_repo>/pull/new/<branch>` with the title and body to paste.
When the report says `fork: yes`, the branch is pushed to `origin`, the fork, and the PR opened on `<github_repo>` with the head `<origin owner>:<branch>`: `gh pr create --repo <github_repo> --head <origin owner>:<branch>`, the same `head` in the `POST` body, or the link `https://github.com/<github_repo>/compare/<default_branch>...<origin owner>:<branch>?expand=1`.

The PR body carries the three Step 11 settings as a checklist.
A tick records that the user read, understood and took on the setting, nothing more, so a reviewer checks the gate instead of trusting it:

    Automerge starts when this PR merges. The plugin changes no GitHub
    setting: the branch protection behind automerge is applied by hand.
    During the setup, the author acknowledged the three settings below,
    what each one does and that it is theirs to apply:
    - [x] Allow auto-merge on the repository, so GitHub does the merging
          and waits for the required checks alone: read, understood, to
          be turned on before this PR merges
    - [x] Required status checks on the base branch, the gate: read,
          understood, to be set before this PR merges
    - [x] Konflux app bypass of the approval rule only, "For pull
          requests only", never of the required checks: read,
          understood, to be set if the base branch requires approvals

    The ticks record that acknowledgement, not a verified state.
    Reviewer: check the three settings before merging.

A setting whose Step 11 verdict opened with ✅ ends its item with `read, understood, already in place` instead of the `to be ...` clause.
A box stays unticked when Step 11 ended without the "I read it" answer, and the body names what is still open.
When Step 2 printed a how-to, one more paragraph before the attribution line: `MintMaker is being switched off on <branch> by annotating its Konflux component(s) <components>, by hand: the rules in this file stop applying there once it is.`
The body ends with the attribution line, verbatim:

    Set up with the [MintMaker Automerge](https://github.com/gwenneg/mintmaker-automerge) plugin for Claude Code.

**The closing message.** Once the PR is open, the skill is done with GitHub: no check watch, no poll, no background task.
One reply, in this order, the table never shortened, because it is what makes a PR that sits open for a while read as the system working:

1. The PR link on its own line.
2. One line: the validator workflow reports on the PR page; a failure there is a syntax or schema error to fix and push again.
3. The table below, verbatim.
4. When Step 2 printed a how-to, one line: `<branch>`: no MintMaker run there once every component is annotated; close its open MintMaker PRs yourself.
5. A one-line farewell, and nothing after it.

```
Once it is live:

| When | What you'll see |
|---|---|
| Every 4 hours | MintMaker runs. Each PR that matches your rules opens marked for GitHub's auto-merge, and GitHub merges it the moment the required checks pass. With Allow auto-merge off, Renovate merges it itself on a later run, and only once every check on it is green. |
| Once the release-age delay has passed | The PR for it appears, `renovate/stability-days` already green. Held updates are invisible: the dependency dashboard is off. |
| Right away | A vulnerability fix PR skips the release-age delay: a patch or minor fix in an automerged ecosystem merges as soon as the required checks pass, a fix that needs a major stays manual. Worth a look afterwards. |
| One at a time | Each merge makes the other Renovate branches stale; they rebase and merge on later runs. |
| In every PR body | `Automerge: Enabled` when the rules matched. Missing means the config didn't match that update: first thing to check. |
| First unattended merge | A Konflux-app PR merged with green checks and no approval confirms the bypass. Until then it's unverified. |
| Still waiting for you | Majors except the packages you named, the manual-review list, build toolchains unless you opted in, ecosystems without a rule. That is the intended scope. |
```

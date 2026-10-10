---
name: setup
description: Turns on Renovate automerge for low-risk dependency updates in a Konflux-onboarded repository, one decision at a time, and documents the GitHub branch-protection changes it needs. Run it from the repository with /mintmaker-automerge:setup.
disable-model-invocation: true
model: claude-sonnet-5
allowed-tools:
  - Bash(${CLAUDE_SKILL_DIR}/scripts/detect.sh)
  - Bash(${CLAUDE_SKILL_DIR}/scripts/version.sh)
  - Bash(${CLAUDE_SKILL_DIR}/scripts/check-comments.sh *)
---

!`"${CLAUDE_SKILL_DIR}/scripts/version.sh"`

# Renovate automerge setup

A guided conversation in fourteen short steps that ends with a reviewed Renovate config on a branch, an open PR, and the GitHub settings in place.
Automerge is a trust decision, so the user makes every consequential choice; your job is to make each choice small, well framed and quick to answer, and to teach just enough along the way.

## Rules

The user is in a terminal.
Claude Code renders Markdown tables, bold, code and emoji, and AskUserQuestion draws a selection menu.

**The shape of a step.** Every step, 1 to 14, is one reply in two parts, in this order: the screen, as ordinary assistant text, then the step's one AskUserQuestion call, which ends the reply; the answer starts the next.
The screen opens with the header `### ▶️ Step N/14 <title>`, then a table or a few bullets with what was found and at most one 💡 note, under about thirteen lines.
Nothing comes between the two parts, no tool call and no line; whatever a step needs to read or run comes before the screen.
Claude Code renders text in full and folds only thinking into a one-line summary, so a reply that goes from an answer straight to a menu call shows the user nothing.
Only the fenced blocks and the lines this file marks verbatim are ever printed. A sentence of this file that says what a reply opens with, or what comes next, is an instruction to follow silently, never a line of the reply.

The reply to an answer opens with the next step's header: no acknowledgement, no announcement, no extra question, and nothing before the header, a skipped step included, whose `Skipped:` line comes after its header and is followed by the next screen, never by a question.
A step the report makes moot still prints its full `### ▶️ Step N/14 <title>` header line, then one line saying why, then the next step's full screen in the same reply: the report's "Skipped steps" section holds those two lines for every such step, and the reply that reaches the step starts with them, copied verbatim, before the next screen.
A step closes with a plain line only where this file spells one out, because it carries a fact the user needs; the exceptions to the shape are written out where they apply: the how-to of Step 2, the required-checks guidance of Step 9, Step 8's closing line, the `.jsonc` case of Step 3, and the write phase of Step 13.

**Menus.** Every decision is an AskUserQuestion, all of a step's questions in one call, up to four.
The recommended option comes first with "(Recommended)" inside its label, as in `Rename to renovate.jsonc (Recommended)`, exactly one per question, in a multi-select too; the mark does not show in a description. The one question without it is the Branches question of Step 2: whether a branch keeps getting MintMaker PRs is not this skill's call.
Each option's description states its consequence in one line.
Never offer a single option: the tool rejects it.
A follow-up for typed input, package names or a reason, is an AskUserQuestion call as well, with two options: `I'll type them (Recommended)`, the user typing the answer in its place, and `None after all`, which falls back to the recommended answer of the question it follows; a question asked as plain text ends the reply with nothing to answer.
After the follow-up, go on to the next step.

**Notes and emoji.** The 💡 notes in this file are shown where they stand, verbatim, one or two sentences each: they are how the user learns what Renovate and MintMaker do while deciding.
When the user asks why, answer from `references/why.md` in a few lines.
Emoji, each with one meaning: ⚠️ needs attention, as a table status or a warning where this file places one, ✅ its opposite, as a table status or opening a Currently line of Steps 9 and 11, 🟢 automerges, 🛑 stays manual, 💡 a note, ▶️ before every step header, 🤖 once in the welcome title, no keycap digits, since Step 11 has a single setting.
None in prose.

**The report.** The bundled `scripts/detect.sh` scanned the repository when this skill loaded; its output is under "Repo facts" below.
It is read-only, looks at tracked files only, and is never run again: Steps 1 to 12 read from it.
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
`<version>` in the title is the `plugin_version` line at the top of this file, printed as `v0.6.0`.

```
### 🤖 MintMaker Automerge Setup <version>

This plugin turns on automerge for the dependency updates you decide are low-risk, gated by your CI checks and by MintMaker's release-age delay. Everything else still needs a reviewer, human or AI, so your attention goes to the updates that deserve it.

How this works:
- Fourteen short steps, a few quick decisions along the way, about twenty minutes end to end.
- The required checks and the Konflux app exemption, the GitHub settings behind every unattended merge, are checked and explained in Steps 9 and 11, with links to their pages, but never changed by this skill: you apply them yourself, which requires the Admin role on the repository.
- The config is written on disk only after you approve the summary, in Step 13.
- The PR is opened only after you approve it, in Step 14.
```

## Step 1: Detected ecosystems

The report's Screens section holds this screen: the Konflux check line and the ecosystems table, or the stop message.
Print it verbatim, tables included.
On the stop message the conversation ends there: this skill only applies to repos onboarded in Konflux, and improvising a generic Renovate setup is not it.
The table lists the ecosystems found and the files behind them; what automerges is decided in Steps 4 to 8 and shown in Step 13.
Under the table, not on the stop message, this note:

💡 MintMaker already opens PRs for every ecosystem in this table. The next steps only decide which of those PRs stop waiting for you.

Only when the report's `ignored_by_renovate` line names files, add one sentence to the note naming them: MintMaker inherits Renovate's `config:recommended`, which skips dependency files under `test/`, `tests/`, `examples/`, `vendor/` and similar directories, so those files never get a PR.

Ask, header "Ecosystems": Looks right (Recommended) / Needs a correction, the fix typed as the answer, since detection can be wrong, a `pom.xml` kept for a subproject nobody builds.
The screen's Repository line is the report's `github_repo`, the upstream when `fork: yes`; a correction naming another repository replaces it for Steps 9, 11 and 14, and the current-state lines of Steps 9 and 11 then read `not checked, repository corrected in Step 1`.
When the default branch is `unknown`, add a "Default branch" question to the same call, with the report's `current_branch` as the recommended option.

## Step 2: Branches MintMaker updates

The report's Branches section lists the branches MintMaker runs on, read from the pull-request pipelines in `.tekton/`, one line per branch with its namespace and every Konflux component and pipeline that targets it; the Screens section holds this step's table, one row per branch with the first pipeline and a `+N` for the others.
One branch in the report: print the report's Skipped steps block for Step 2 verbatim, then the Step 3 screen in the same reply.
Otherwise the header, the table verbatim, this note, then one question.

💡 Renovate reads this repo's config from the default branch only, and MintMaker runs one job per branch in this table, so the rules you choose next apply to every branch here. The Renovate config cannot disable MintMaker on a branch: security fixes still get PRs there, and `baseBranchPatterns` makes the jobs of the other branches run on `<default_branch>` too, two identical jobs at once, which MintMaker warns leads to conflicts. The only way to disable it on a branch is in Konflux: an annotation on each component that builds the branch, set with `oc`.

In the note and the how-to, `<default_branch>` is the report's `default_branch` and `<branch>` the branch chosen.
When the report's `oc:` line says yes, the install line of the how-to is left out.

Header "Branches", question "Should MintMaker stop opening PRs on one of these branches?", no option marked recommended: `No, keep MintMaker on every branch`, the rules chosen next apply to all of them / one option per branch other than the default, `Show me how to disable MintMaker on <branch>`, the steps printed next, once per component of the branch, nothing applied by this skill.
More than three such branches: one option `Show me how to disable MintMaker on a branch I'll name`, the branch typed as the answer.
On "No", the reply opens with the Step 3 header.
On a branch, the reply opens with the how-to below for that branch, its placeholders filled from the report's `branch:` line, and ends with one more question, header "Next", question "Ready to move on to the Renovate config?": `Yes, go to the next step (Recommended)` / `I need more help with this step`. On the second, explain from `references/why.md` in a few lines, answer what the user asks, then ask again; on the first, the reply opens with the Step 3 header. The how-to, the required-checks guidance of Step 9 and the rebasing tip of Step 10 are the places a reply to an answer does not open with a step header, and Steps 2, 9 and 10 the steps with a second question of their own.
The how-to shows one component, the first of the report's `components=` list, under a line saying the steps are done for each component, since MintMaker's docs say a branch with several components needs each one annotated.
A `namespace` or a component the report gives as `unknown` stays a placeholder, with one line saying the Konflux UI shows both on the component's page.

```
### Disabling MintMaker on `<branch>`

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
Every ⚠️ row is removed in Step 13, for the reason the row gives; existing custom rules are preserved.
When a row names a shared preset, its content is in the report: say what it sets under the table, in particular a `minimumReleaseAge` shorter than MintMaker's.
Only when the report says it could not fetch it, read it before the screen.

The screen: the header, the table verbatim, this note, then one of three cases.

💡 MintMaker runs Renovate with its own global config and merges this file on top, so this file only holds what is specific to this repo. Package rules add up, but a list such as `enabledManagers` replaces MintMaker's list outright and would turn off every manager not named here.

- **A `.jsonc` or `.json5` file exists.** No question: close with one line saying the file stays where it is, then the Step 4 screen in the same reply.
- **A strict `.json` file exists.** This line verbatim, the file name filled in, with no other lead-in, then a question, header "Rename": `Rename to renovate.jsonc (Recommended)`, for the comments / `Keep .json`, the comments then show as errors in some editors.
  On rename, the report's "is named in" line lists the files to update, a workflow path filter, a README, an AGENTS.md: a rename that breaks a validator workflow is worse than none.

  `<config file>` is a strict `.json` file, and this plugin writes a comment wherever a setting needs its reason next to it: Renovate accepts comments in a `.json` file, but editors such as VS Code flag them as errors there, and `.jsonc` is the file name that allows them.
- **No config.** Question, header "Location": `renovate.jsonc` at the root (Recommended), the first place Renovate looks and the one MintMaker's docs use / `.github/renovate.jsonc`.

## Step 4: Libraries

For the library ecosystems found (Maven, Gradle, Go, npm, Python, Cargo, Bundler): this screen, then three questions in one call, a fourth when `go.mod` was found.
The report's manual-review candidates are not listed on the screen; they are the first option of the second question.

```
### ▶️ Step 4/14 Libraries

Proposed rule for <the library ecosystems found, e.g. Go modules and npm>: patch and minor bumps merge on their own once CI passes, majors stay on manual review. Narrow or widen it below.
```

💡 Whichever option you pick below, the same two protections apply: MintMaker's release-age delay and your required GitHub checks. "Development dependencies only" is not the safe choice it sounds like: a compromised dev dependency still runs in CI, where it can read secrets and alter the build.

Header "Scope": Every patch and minor bump (Recommended) / Development dependencies only, where the manager knows the difference, npm does / Only packages I'll name, the names in a follow-up / Decide per ecosystem, one question per ecosystem with the first three scopes.

Header "Never automerge", question "Any packages that should never be automerged, whatever the scope?", multiSelect: one option holding every candidate of the report, all named in its label and marked (Recommended), their reasons as its description, never one option per candidate / Other packages, I'll name them, the names in a follow-up / None, marked (Recommended) when the report has no candidate.
These packages still get PRs, on manual review whatever the update type.

Header "Majors", question "Any packages whose major bumps may automerge too?": No package, majors stay on manual review (Recommended) / Yes, for packages I'll name.
Propose no candidates, here and in Step 6: which majors are safe unattended is project knowledge, a test framework with good coverage or a tool used only in CI, and a guess widens the scope beyond what was asked.
Ask in the follow-up why their majors are safe: that reason becomes the rule's comment, and CI is the only gate on them.

Header "Go indirect", when `go.mod` was found: Automerge indirect dependencies too (Recommended), MintMaker's global config opens PRs for them / Keep them manual.

## Step 5: Build toolchains

`toolchains: none` in the report: print the report's Skipped steps block for Step 5 verbatim, then the Step 6 screen in the same reply.
Otherwise the header, the report's toolchains table verbatim, the note, then one question.

💡 These are every developer's build tool, not just CI's: `mvnw` and `gradlew` download the version they pin, the `toolchain` line of `go.mod` makes the `go` command fetch that exact compiler, and `packageManager` is what corepack installs. Renovate bumps them like any dependency, so they get a rule of their own instead of falling under the patch-and-minor rules of Step 4.

Header "Toolchains": Keep manual (Recommended), updates are rare and a bad one breaks every developer's local build, not just CI / Automerge patch and minor, CI builds with the new toolchain on every PR.

## Step 6: GitHub Actions

No workflow in the report: print the report's Skipped steps block for Step 6 verbatim, then the Step 7 screen in the same reply.
Otherwise the header, the report's actions table verbatim, the note, then three questions in one call.

💡 In March 2025 the `tj-actions/changed-files` action was hijacked: every release tag was moved to a malicious commit, so workflows pinned to a tag ran it and workflows pinned to a SHA did not. With a SHA pin, a moved tag becomes a PR that never automerges; with a tag pin, CI runs the new code with no PR at all.

Header "Pin actions", only when the table has an action pinned by tag, a reusable workflow not counting: Pin every action to a SHA (Recommended), Renovate opens one manual Pin dependencies PR replacing each tag with its SHA and the full version as a comment / Don't pin, the allow-list then guards version bumps only, not moved tags, and only for actions referenced by a full version: one on a floating tag such as `v4` keeps following it with no PR.

Header "Allow-list", multiSelect, options built from the table's "Maintained by" column: Actions maintained by GitHub (Recommended), the `actions/*` and `github/*` ones, named in the description / Third-party actions, the rest, named with their owners / I'll type which ones to allow.
Both groups ticked allows every action; a typed answer replaces the groups.
Reusable workflows stay out: they are workflows called with `uses:`, not actions.
An action pinned to a bare SHA without a version comment gets no PRs at all, since Renovate cannot tell which version it is; say so and name the fix, a `# vX.Y.Z` comment.

Header "Majors", question "Any actions whose major bumps may automerge too?": No action, majors stay on manual review (Recommended), a major often changes an action's inputs or the Node runtime it needs / Yes, for actions I'll name, which must be on the allow-list, the reason in the same follow-up.

## Step 7: Base images

No container file and no RPM lockfile in the report: print the report's Skipped steps block for Step 7 verbatim, then the Step 8 screen in the same reply.
Otherwise the header, the report's base images table verbatim, then its RPM lockfiles table verbatim when it has one, the note, then up to three questions in one call, each only when relevant.
With RPM lockfiles and no base image, the base images table, the note and the two base image questions are left out.

💡 The release-age delay does not cover most base images: Renovate only learns publish dates from Docker Hub, and MintMaker treats a release without one as old enough. For an image from `registry.access.redhat.com` or `quay.io`, your required checks are the only protection, and the Konflux PR build is the check that actually builds on the new base: remember that if you make the required checks the gate in Step 9.

Header "Base images": Automerge digest, patch and minor bumps (Recommended), the Konflux PR build builds the image and the tests run on it, majors such as a new RHEL or JDK line stay manual / Keep them manual.
Header "Pin base images", only when an image has no digest: Pin to `tag@sha256` (Recommended), Renovate opens one manual pin PR, after which rebuilds of the same tag arrive as digest PRs / Keep tags only, rebuilds then go unnoticed.
Header "RPM lockfiles", only when the report has an RPM lockfiles table, question "Should the RPM lockfile refreshes merge on their own?": Automerge every refresh (Recommended), the regular ones and the `[SECURITY]` ones: the Konflux PR build installs the refreshed RPMs and builds the image, and the tests run on it; with base images in the repo, add that their PRs refresh the lockfile too, so the new base is built with matching RPMs / Automerge the `[SECURITY]` refreshes only, whatever the severity of their CVEs: the nightly refresh often carries the same builds and has nothing left once the `[SECURITY]` one merges / Keep them manual.
When the report's `rpm_security_threshold` is not `none`, the second option keeps it instead, `Keep automerging the [SECURITY] refreshes at <threshold> or higher`, said as today's setting, and when that threshold comes from a preset, the third option is left out: the preset keeps automerging them whatever this file says, and only taking it out of `extends` stops that, which the user can ask for at the Step 13 summary.
When the existing config sets `automerge: true` in a top-level `lockFileMaintenance` block, which the Step 3 table flags, the question is not asked: one line under the table says every RPM refresh already automerges through it, with the other lockfiles of the repo; when no other question of the step is left, that line closes it and the Step 8 screen follows in the same reply.

With an RPM lockfiles table, one line above the questions: MintMaker refreshes the whole lockfile at once from the repositories in `rpms.in.yaml`, with no release-age delay, so the Konflux PR build is what tests the new RPMs, as for a base image.

When the table flags a `latest` tag, one line above the questions: a `latest` tag carries no version, so Renovate has nothing to bump; with the digest pinned, rebuilds of `latest` arrive as digest PRs, the only update those files can get.
The automerge option then says "digest updates" rather than "patch and minor".

## Step 8: Merge days

The reply to the Step 7 answer opens with the block below, header and framing line, then the menu; no question comes before that block.

```
### ▶️ Step 8/14 Merge days

Renovate opens and rebases PRs only on the days chosen below, and GitHub merges each one within minutes of its checks passing, so merges follow the same days; vulnerability fix PRs ignore them. The Konflux pipeline follows its own schedule, the second question.
```

Two questions in one call.
Header "Merge days", question "On which days may updates open and merge?": Any day (Recommended), MintMaker runs every four hours, twice a day on busy Konflux clusters, and a bump merges within hours of clearing the release-age delay / Monday to Thursday, no PR opens, rebases or merges from Friday to Sunday, UTC, so a bump due on a Friday waits for Monday / Other days, I'll type them, the days in a follow-up.
Header "Pipeline": Konflux pipeline updates on the same days as the rest (Recommended), within hours of a catalog bump, since task bundles carry no publish date for the release-age delay / Keep MintMaker's Saturday batch, pipeline PRs then open and merge on Saturdays whatever the merge days say.
When the report flags path-filtered PR pipelines, add a third option, Keep pipeline updates manual, and say in the question why: a path-filtered pipeline cannot be a required check, so a `tekton` PR for it would merge before its build reports.
Close the step with one line: `Rules chosen.
Summary in Step 13.`
That line opens the reply to this step's answer, and the same reply goes on with the Step 9 screen: nothing of it is held back for a later reply.

## Step 9: Required checks

The screen is the header and the guidance below, filled from the report, then one question: GitHub's auto-merge merges a PR as soon as the required checks of `<default_branch>` pass, so those checks are the whole gate, and this step is where the user takes them on.
The `<...>` placeholders come from the report: `status_checks` printed verbatim on the Currently line, ✅ or ⚠️ included, `required_checks` as the bullets, the URLs in the Links section, `github_role` in the Tooling section.

```
### ▶️ Step 9/14 Required checks

GitHub merges a PR the moment the required checks of `<default_branch>` pass, with no approval, so a check missing from that list never holds a merge, red or not. The rule is "Require status checks to pass" in a ruleset for `<default_branch>` that nobody bypasses: <settings_ruleset_checks, or settings_rulesets when the report has none>. Changing it takes the Admin role on the repository (yours: <github_role>), and this skill changes nothing: you apply it in GitHub.

Currently required: <status_checks>
- <one bullet per check in the report's required_checks, in backticks; no bullet when there is none>

Require what proves the PR's own change is good, and nothing less:
- the build, and the tests when they are a separate job
- the Konflux PR pipeline, `Red Hat Konflux / <component>-on-pull-request`: the only check that runs an updated pipeline

Never require:
- a check that skips some PRs, such as the config validator or `renovate/stability-days`: GitHub keeps it "Pending" forever
- a check that goes red for reasons outside the PR, such as a vulnerability scan: one new advisory would block every PR
```

When `status_checks` opens with ⚠️, one more line under the Currently bullets: `⚠️ With no required check, GitHub merges every matching PR as soon as it opens, whatever CI says. Set the checks before this PR merges.`

Menu, header "Gate checks": `I read it, understood it, and will set the required checks before automerge goes live (Recommended)`, or `and the required checks are in place (Recommended)` when `status_checks` opens with ✅ / `I'm not sure, help me understand`.
On the second, explain from `references/github-branch-protection.md` in a few lines, with the report's "Konflux names" and "Workflow jobs" sections as illustration of this repository's check names, never as a list to set; then ask again.
The answer is an acknowledgement, recorded in the PR body: the skill verifies nothing, and which checks to require is the user's decision.
The reply to it opens with the Step 10 screen.

## Step 10: Automerge throughput

The screen is the header and the tip, printed verbatim, the tip chosen by the report's `up_to_date_required` line, then one question.
The tip explains before it asks, because the question only makes sense once the user knows how the PRs merge under MintMaker.
In the tip, `<default_branch>` is the report's `default_branch`, or the branch chosen in Step 1 when the report had none: `master` on a repository whose default branch is `master`, never the literal placeholder.

```
### ▶️ Step 10/14 Automerge throughput
```

The tip when `up_to_date_required` says yes:

💡 After each merge the other open PRs are behind `<default_branch>`, which requires branches to be up to date, so each one waits for MintMaker's next run, every four hours, twice a day on busy Konflux clusters, to rebase it and rerun its checks before GitHub can merge it. One PR per ecosystem merges all its bumps at once. However, if one bump fails a check, the whole PR waits until that bump is fixed or excluded with a rule of its own.

The tip otherwise, no or not checked:

💡 A green PR merges within minutes of its checks passing, as tested against the `<default_branch>` it was opened on, so two bumps merged in a row were never tested together. One PR per ecosystem merges all its bumps at once, tested together. However, if one bump fails a check, the whole PR waits until that bump is fixed or excluded with a rule of its own.

Header "Batching", question "How many PRs should the automerged updates share?": One PR per ecosystem (Recommended), `Update Go modules`, `Update base images`: one merge lands every bump of that ecosystem that passed the release-age delay, and a red member holds only its ecosystem / One PR for all ecosystems, a single `Update all non-major dependencies` PR, where a red member holds everything / One PR per update, Renovate's default: every bump is its own PR and its own merge.
Majors, vulnerability fixes, toolchains, the manual-review packages and the pin PRs stay outside the groups whatever the answer: a member that never automerges would hold the group.
The reply to the answer opens with the Step 11 screen, the Konflux app exemption, or its Skipped line and the Step 12 screen.

## Step 11: Konflux app exemption

One screen, from this file, no tool call, then one menu when there is something to apply: the Konflux app exemption, the one GitHub setting without which no unattended merge happens on a branch that requires an approval.
The `<...>` placeholders come from the report: `github_role` in the Tooling section, the URLs in the Links section, and the `status_bypass` and `status_auto_merge` verdicts of the Step 11 status section, printed verbatim where the screen names them, ✅ or ⚠️ included; `not checked` where the report says so.
The organization link is left out when the report has `settings_org_rulesets: none`; with `not checked` the first sentence reads `The exemption could not be checked (<the reason from the verdict>). When \`<default_branch>\` requires an approval, no MintMaker PR ever merges unattended until the Konflux app is exempt from that rule.`
The full screen and its menu print unless both verdicts open with ✅. A verdict that reads `not checked` is not ✅: the rules could not be read, so the screen prints with its first sentence in the not-checked form, and the user is asked. Only two ✅ verdicts skip the step like any moot step: the report's Skipped steps block for Step 11, which carries the verdicts as the report gives them, never a verdict written by you, then the Step 12 screen in the same reply, no question.
Each line that names a place ends with its URL, so the terminal makes it clickable; with no GitHub remote the report has none, and the words stand alone.
`references/github-branch-protection.md` is the long form for "why?" questions, not to paraphrase into the screen.

The full screen:

```
### ▶️ Step 11/14 Konflux app exemption

<status_bypass, the ⚠️ dropped>. Without it, no MintMaker PR ever merges unattended: GitHub's auto-merge ignores a bypass actor in any other mode, and only an exempt actor is never asked for an approval.

💡 An exempt actor skips every rule of its ruleset, and nothing is logged as a bypass. So keep "Require a pull request before merging" in a ruleset of its own, and the required checks and "Block force pushes" in a ruleset nobody bypasses: in one ruleset, the app could merge a PR with a red check or force-push the branch.

Where to add `Red Hat Konflux`, the GitHub App owned by `redhat-appstudio`, with the bypass mode Exempt:
1. Organization ruleset (recommended), by an organization owner: covers every Konflux repository at once: <settings_org_rulesets, when the report has one>
2. Repository ruleset, Admin role (yours: <github_role>): add the app to the bypass list of the ruleset holding the pull request rule, and only that rule: <settings_ruleset_approval, or settings_rulesets when the report has none>
Classic branch protection rules have no Exempt mode: a branch on them moves to rulesets first: <settings_branches>
"Allow auto-merge" in the repository settings, which Renovate needs to arm the merge: <status_auto_merge>: <settings_repo>

This skill never touches GitHub settings, by design: applying the exemption is yours to do.
```

The skipped form, when both verdicts open with ✅, is the report's Skipped steps block for Step 11, verbatim.

Menu of the full screen, header "Settings": `I read it, understood it, and will apply the settings before automerge goes live (Recommended)` / `I'm not sure, help me understand`.
On the second, explain from the reference in a few lines, the ruleset splitting, the Exempt mode and the organization ruleset in particular, and answer what the user asks; then ask again.

The answer is an acknowledgement, recorded as such in the PR body: the skill verifies nothing.
The reply to it opens with the full Step 12 screen, Other updaters, or its Skipped line and the Step 13 screen, never with a menu alone; in the skipped form the same reply already holds it.

## Step 12: Other updaters

`dependabot.yml: none` and `base_image_workflows: none` in the report: the reply to the Step 11 answer opens with the report's Skipped steps block for Step 12, its two lines copied as they are, then the Step 13 screen, with no sentence of this file's instructions in between.
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

The answers are applied in Step 13, after "Write it", never here.

## The config blocks

Assemble the config in Step 13 from the two blocks below, driven by the answers of Steps 4 to 8 and 10.
Never fetch an example config from another repository: these blocks are the reference.

### The comments

Every comment in the file is copied word for word from these blocks, or from a comment this file quotes as `// ...`: never written, reworded, merged, wrapped or adapted to the repository. A `<...>` in a comment is filled in, and nothing else changes. A rule whose block has no comment gets none.
A setting kept from the existing config keeps its own comments as they were, under one marker line of its own, right above them: `// Repository rule, not written by the plugin:` above a kept rule, `// Repository setting, not written by the plugin:` above a kept key. A kept rule goes after the ecosystem rule of its manager, before that ecosystem's manual rules, as the Batching item below says, or at the end of `packageRules` when it names no manager of the file; a kept top-level key goes after `packageRules`; a key kept inside a block the plugin writes, such as `rpm-lockfile` or `extends`, stays in that block.
In a config this plugin wrote before, a comment of an earlier version, the `// ---` separator lines included, is replaced by the comment of the current block, or dropped when the current block has none.

### The skeleton

Header comment, the optional `extends` block for action pinning, the `tekton` block, the RPM block below when Step 7 automerged RPM lockfile refreshes, and a `{{PACKAGE_RULES}}` placeholder.
Drop the `extends` block only when the user declined pinning, never because every action is already SHA-pinned: it costs nothing then, and an action added later as `@v1` gets its pin PR from it, SHA and full version at once. The `rangeStrategy` rule of the github-actions block follows the same answer. Drop the `tekton` block's `schedule` line and its comment when they kept the Saturday batch.
Merge days other than any day add the two lines of the merge-days block below, after the `platformAutomerge` line, and the `tekton` block's `schedule` line then takes the same cron with the comment `// Same days as the rest, instead of MintMaker's Saturday batch.`
Typed merge days become a cron with `*` for the minutes, the way MintMaker writes its own schedules, `0` being Sunday; a timezone named in the answer becomes a top-level `"timezone"` line with its IANA name, and without one the days are UTC.
The days are a `schedule`, not an `automergeSchedule`: MintMaker sets `updateNotScheduled` to false, so a run outside the days skips an existing branch before any merge attempt, and one option bounds the pushes and the merges alike.
The marker is the first line of the file and the Overrides line the second, both before the opening brace, which Renovate and the validator accept; `<version>` in it is the `plugin_version` line at the top of this file, printed as in the welcome title. When the existing config already has the marker, on its first line or in its header, replace it there, so the file names the version that last wrote it.

```jsonc
// Set up with the MintMaker Automerge plugin <version>: https://github.com/gwenneg/mintmaker-automerge
// Overrides MintMaker's global config: https://github.com/konflux-ci/mintmaker/blob/main/config/renovate/renovate.json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  // GitHub merges each PR as soon as its required checks pass, once the Konflux app is
  // exempt from the approval rule.
  "platformAutomerge": true,
  "extends": [
    // Keep even when every action is pinned: it pins the next one added.
    "helpers:pinGitHubActionDigests"
  ],
  "tekton": {
    // The PR's own Konflux build runs the updated pipeline.
    "automerge": true,
    // Any day, instead of MintMaker's Saturday batch.
    "schedule": ["at any time"]
  },
  "packageRules": [
    {{PACKAGE_RULES}}
  ]
}
```

The RPM block, after the `tekton` block, when Step 7 chose to automerge every RPM lockfile refresh.
It is a manager block rather than a package rule: MintMaker's docs note that a rule matching package names never applies to a lockfile refresh, and its `lockFileMaintenance` schedule, nightly from 0:00 to 4:59 UTC, stays in force whatever the merge days of Step 8 are.

```jsonc
  "rpm-lockfile": {
    // The Konflux build installs the refreshed RPMs, so a refresh is tested like any PR.
    "automerge": true
  },
```

When Step 7 chose the `[SECURITY]` refreshes only, this line takes its place, at the same spot:

```jsonc
  // Regular refreshes stay manual.
  "rpmVulnerabilityAutomerge": "ALL",
```

When the user kept an existing threshold, the value is that threshold and the comment is `// Regular refreshes, and fixes of CVEs below <threshold>, stay manual.`, the threshold in lowercase, `MEDIUM` said as moderate.
An existing `rpm-lockfile` block keeps its other keys: the `automerge` line goes into it, or out of it when the refreshes stay manual.

The merge-days block, here for Monday to Thursday; for other days, the comment names them the same way, with the timezone in place of UTC when the answer named one:

```jsonc
  // <Monday to Thursday, UTC>. Vulnerability fixes ignore the schedule.
  "schedule": ["* * * * 1-4"],
```

### The rule blocks

One block per Renovate manager, with variants where a choice exists.
Copy the blocks for the detected ecosystems into the placeholder, fill the names marked `<...>`, and copy exactly one variant where several are offered.
Rules apply in order and a later rule overrides an earlier one, so a manual-review rule or a majors rule goes after the ecosystem rule it narrows or widens.
Everything MintMaker's global config already sets stays out of the file; if the user asks for a key the blocks don't have, check the global config first, since a duplicate drifts out of sync.

A blank line separates the ecosystems; no line names them, since `matchManagers` does.
The github-actions block keeps its `rangeStrategy` rule whenever the block is written, every action already pinned included: a `# v4` comment next to a SHA needs it as much as a `@v4` ref, since without it that action never gets a patch or minor PR and the allow-list matches nothing. The one case that drops the rule, and the `extends` block with it, is a "Don't pin" answer: the user chose floating tags, and the rule would rewrite them.
The `groupName` lines are the batching of Step 10, written below for one PR per ecosystem: every automerge rule names its group, and every rule that keeps something manual inside a grouped manager unsets it with `null`, since a group automerges only when every member does.

```jsonc
[
  {
    // Needed even when SHA-pinned: without it, a v4-style tag gets only digest PRs, which
    // never automerge. Expect one manual PR that writes the full version.
    "matchManagers": ["github-actions"],
    "matchDepTypes": ["action"],
    "rangeStrategy": "pin"
  },
  {
    // Named actions only: an action runs code in CI. Digest-only updates stay manual:
    // a moved tag with no version change is what a hijacked action looks like.
    "matchManagers": ["github-actions"],
    "matchUpdateTypes": ["patch", "minor"],
    "matchDepNames": ["<action-in-use>", "<action-in-use>"],
    "automerge": true,
    "groupName": "GitHub Actions"
  },

  {
    "matchManagers": ["maven"],
    "matchUpdateTypes": ["patch", "minor"],
    "automerge": true,
    "groupName": "Maven dependencies"
  },
  {
    // The wrapper is every developer's build tool, not just CI's.
    "matchManagers": ["maven-wrapper"],
    "automerge": false
  },

  {
    "matchManagers": ["gradle"],
    "matchUpdateTypes": ["patch", "minor"],
    "automerge": true,
    "groupName": "Gradle dependencies"
  },
  {
    // The wrapper is every developer's build tool, not just CI's.
    "matchManagers": ["gradle-wrapper"],
    "automerge": false
  },

  {
    // The Konflux PR build builds and tests the image. A digest update rebuilds the same
    // tag; a new RHEL or JDK line is a major and stays manual.
    "matchManagers": ["dockerfile"],
    "matchUpdateTypes": ["digest", "patch", "minor"],
    "automerge": true,
    "groupName": "base images"
  },
  {
    // Keep even when every FROM line is pinned: it pins the next image added.
    "matchManagers": ["dockerfile"],
    "pinDigests": true
  },
  {
    // Refreshes the RPM lockfiles in the base image PR, so the build tests both together.
    // Don't edit the command: MintMaker runs it only on an exact allow-list match.
    "matchManagers": ["dockerfile"],
    "postUpgradeTasks": {
      "commands": ["refresh-rpm-lockfiles -f \"$RENOVATE_POST_UPGRADE_COMMAND_DATA_FILE\""],
      "fileFilters": ["**/rpms.lock.yaml"],
      "executionMode": "branch",
      "dataFileTemplate": "[{{#each upgrades}}{\"packageFile\": \"{{{packageFile}}}\"}{{#unless @last}},{{\/unless}}{{\/each}}]"
    }
  },

  {
    "matchManagers": ["gomod"],
    "matchUpdateTypes": ["patch", "minor"],
    "automerge": true,
    "groupName": "Go modules"
  },
  {
    // No group: a member that never automerges would hold the whole group.
    "matchManagers": ["gomod"],
    "matchDepTypes": ["indirect"],
    "automerge": false,
    "groupName": null
  },
  {
    // The toolchain is every developer's compiler, not just CI's.
    // No group: a member that never automerges would hold the whole group.
    "matchManagers": ["gomod"],
    "matchDepTypes": ["toolchain"],
    "automerge": false,
    "groupName": null
  },

  {
    "matchManagers": ["npm"],
    "matchUpdateTypes": ["patch", "minor"],
    "automerge": true,
    "groupName": "npm dependencies"
  },
  {
    "matchManagers": ["npm"],
    "matchDepTypes": ["devDependencies"],
    "matchUpdateTypes": ["patch", "minor"],
    "automerge": true,
    "groupName": "npm dependencies"
  },
  {
    // These pin every developer's tools, not just CI's.
    // No group: a member that never automerges would hold the whole group.
    "matchManagers": ["npm"],
    "matchDepTypes": ["packageManager", "engines"],
    "automerge": false,
    "groupName": null
  },

  {
    "matchManagers": ["pip_requirements", "pip_setup", "pipenv", "poetry", "pep621"],
    "matchUpdateTypes": ["patch", "minor"],
    "automerge": true,
    "groupName": "Python dependencies"
  },

  {
    "matchManagers": ["cargo"],
    "matchUpdateTypes": ["patch", "minor"],
    "automerge": true,
    "groupName": "Cargo dependencies"
  },

  {
    "matchManagers": ["bundler"],
    "matchUpdateTypes": ["patch", "minor"],
    "automerge": true,
    "groupName": "Bundler dependencies"
  }
]
```

The manual-review rule, once per package, any manager. For a candidate, the first comment line is the candidate's line from the report, from the name to the link, as in `// Quarkus follows an LTS track, so a reviewer picks the target version: https://quarkus.io/releases/`; a package the user typed has no such line.

```jsonc
  {
    // <the candidate's line from the report>
    // No group: a member that never automerges would hold the whole group.
    "matchManagers": ["<manager>"],
    "matchPackageNames": ["<pattern>"],
    "automerge": false,
    "groupName": null
  },
```

The majors rule, for packages whose majors may merge, any manager:

```jsonc
  {
    // Majors merge too: <the user's reason>.
    "matchManagers": ["<manager>"],
    "matchPackageNames": ["<package>", "<package>"],
    "matchUpdateTypes": ["major"],
    "automerge": true
  },
```

The allow-list rule, for a scope limited to named packages, any manager:

```jsonc
  {
    "matchManagers": ["<manager>"],
    "matchPackageNames": ["<package>", "<package>"],
    "matchUpdateTypes": ["patch", "minor"],
    "automerge": true,
    "groupName": "<the group name of its manager's block>"
  },
```

How the answers map to the blocks:

- Toolchains: the wrapper rules, the gomod toolchain rule and the npm packageManager rule are the toolchain rules; they stay as written when the user kept them manual or the step was skipped, and they stand whatever the scope of their manager, an allow-list included, since the file says what was decided.
  When the user opted in, each toolchain rule of a manager the report found becomes `"matchUpdateTypes": ["patch", "minor"], "automerge": true`, with `// CI builds with the new toolchain on every PR.` in place of its comment lines, one or two, and `"groupName": null` kept where the rule has it, since an opted-in toolchain still gets a PR of its own.
  Its `matchDepTypes` list stays as written: `engines` stays next to `packageManager` even when the report lists no engines pin, since the rule describes the policy, not the repo's current files.
- Manual-review packages: the manual-review rule once per candidate kept or package named, after the rule of its manager, with the pattern and comment the report gives for a candidate, under the manager whose files hold it.
  A package the user typed gets the managers whose files hold it, and the no-group line as its only comment.
  Candidates folded into one menu option still get one rule each; none when the user chose none.
- Base images: drop the `pinDigests` rule only when the user kept tags only, never because the images are already pinned, since an image added later on a bare tag gets its pin PR from it; drop the automerge rule when they kept base images manual.
- RPM lockfiles: the RPM block of the skeleton carries the answer, and nothing is written for it when they were kept manual.
  The `postUpgradeTasks` rule of the dockerfile block is written only when Step 7 chose to automerge every RPM refresh and the report's `rpm_refresh_on_base_image` says no; it stands whatever the base images answer, since a base image PR that needs review gets the matching lockfile as well, and it is dropped in every other case, so a base image PR never carries an RPM change the user kept manual.
  Copy its `commands` and `dataFileTemplate` strings exactly: the command must match MintMaker's `allowedCommands` character for character, or MintMaker refuses to run it.
- Go: drop the indirect rule when the user automerges indirect dependencies.
- npm: copy exactly one of the two scope rules, then the packageManager rule; the allow-list width is the allow-list rule with `npm` as the manager.
- Python: keep only the managers the report detected.
- Majors: one block per manager; for GitHub Actions use `matchDepNames` instead of `matchPackageNames`.
  The user's reason from the follow-up is the comment. No `groupName`: majors stay in PRs of their own.
- Batching: for one PR per ecosystem, the `groupName` lines are written as they stand.
  For one PR for all ecosystems, every `groupName` value becomes `all non-major dependencies`, the `null` ones staying `null`.
  For one PR per update, drop every `groupName` line, the `null` ones with the comment line above them included.
  The manual-review rule of a package the user typed unsets the group the same way as a candidate's.
  A kept custom rule that sets its own `groupName` goes after the ecosystem rule of its manager, so its group stays, automerges like the rest of the ecosystem when its updates match the ecosystem rule, and lands as a PR of its own; the Step 13 table names it in its ecosystem's row, and it stays whatever the batching answer.

## Step 13: Summary

**Nothing touches the working tree before the "Write it" answer.** Up to that answer the skill has only read files and asked questions, and `git status` looks exactly as it did when the skill started.
No Write, no Edit, no `git rm` or `git mv`, no doc update, no removal decided in Step 12, and no name check that needs the file to exist.
The menu labels below are fixed: a menu that says the files are already written means the order was wrong, not that the labels need adapting.

Show the whole trust decision in one table: one row per detected ecosystem, one for the Konflux pipeline, one for vulnerability fixes, one for the build toolchains when the report lists any, and one row per ecosystem found that gets no rule.
This screen is never skipped and never shortened, whatever came before it, and the "Write it" menu is not asked until it has been printed: the user approves what they see in that table, nothing else.
Below it, one line with the merge days when they are not any day, the cron said in words, adding that RPM lockfile refreshes keep MintMaker's nightly window when Step 7 automerged them, then one line with the batching choice, `Batching: one PR per ecosystem.`, `one PR for all ecosystems.` or `one PR per update.`, then one line with the Step 12 decision, when there was one, then one line with the branch MintMaker is disabled on, from Step 2, when there is one, `MintMaker: to be disabled on \`<branch>\` by annotating its component(s) \`<components>\` yourself; the rules above stop applying there.`, then one line saying what the answer does: it writes files in the working tree, nothing more.
The pipeline row says "any day" when the merge days are any day, "Saturdays" when the batch was kept.
Nothing is committed or pushed before Step 14.

```
### ▶️ Step 13/14 Summary

| Ecosystem | 🟢 Automerges | 🛑 Stays manual | Why |
|---|---|---|---|
| Maven | patch, minor; majors of `org.assertj:*` | other majors, `io.quarkus*` | Quarkus follows an LTS track; AssertJ is test-only |
| GitHub Actions | patch, minor of `actions/checkout`, `actions/setup-java` | majors, digest-only, every other action | allow-list, SHA-pinned |
| Konflux pipeline | task bumps, migrations, Monday to Thursday | – | the Konflux PR build tests them |
| Vulnerability fixes | patch, minor, without the release-age delay | fixes needing a major | inherited from MintMaker |
| Base images | digest, patch, minor of `ubi9/openjdk-21` | majors, a new RHEL or JDK line | the Konflux PR build tests the image |
| RPM lockfiles | refreshes of `rpms.lock.yaml`, `[SECURITY]` ones included, nightly, and with each base image update | – | the Konflux PR build installs them |
| Build toolchains | – | Maven wrapper | kept manual, every developer builds with it |

Merge days: Monday to Thursday, UTC. Vulnerability fixes still arrive and merge any day.

Batching: one PR per ecosystem.

Dependabot: `dependabot.yml` removed, alerts stay on.

Writing means editing files in your working tree. Nothing is committed or pushed until Step 14.
```

Ask, header "Write it", labels `Write the files to disk (Recommended)`, described as local edits only, no commit, no push / `Change something`, with the free text saying what.

After the "Write the files" answer, and only then, the write phase, in this order:

1. Build the config file, or edit the existing one, rename it when Step 3 said so, drop every ⚠️ row of the Step 3 table, and show the diff.
   When migrating an existing config, list what you removed or restructured and why, so a rewrite never quietly drops a rule the user still wants.
   A rule holding `matchConfidence` goes whole, since without its matcher it would apply to more than it was written for; a rule left with nothing but matchers once a ⚠️ key is gone goes too.
   Then run the report's `check_comments` script as `<check_comments> <config file>`, here and never earlier; there is nothing to read in it first. It prints every comment that is not a template word for word, with its line number: replace each with its block's comment, drop it when the block has none, or, when it belongs to a setting kept from the existing config, write that setting's marker line above it. Run it again until it prints nothing.
2. Apply the Step 12 decisions: remove or narrow `dependabot.yml`, remove the base-image workflow, and update any doc that describes what they covered.
   Files those tools wrote, such as a digest tracking file, go with the workflow that wrote them; say so in one line.
3. Check the names.
   The validator workflow below checks syntax and schema only: a misspelled package or action name passes and silently matches nothing.
   Compare every name in the rules against the files and workflows of the scan yourself, and say `Written, every name checked against the repo.`
   For github-actions, a name is `owner/repo` only: Renovate drops any subpath, so a monorepo action used as `owner/repo/init` and `owner/repo/analyze`, such as `github/codeql-action`, is still one entry, `owner/repo`, however many subpaths the workflow uses. A name with a subpath still attached, table-derived or typed by the user, matches nothing and fails this check.
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

The write phase ends there, with no question: no "does this look right", no confirmation of the files, and no question about the pull request, which is Step 14's.
With no question pending there is no answer to wait for, so the same reply goes on with the Step 14 header and the pull request screen, and the "Ship it" menu comes only once that screen is printed.

## Step 14: Pull request, then what to expect

The header `### ▶️ Step 14/14 Pull request`, one line, `Merging this PR is what turns automerge on.`, then this note:

💡 The new rules also apply to the PRs MintMaker already has open. On its next run, each one that matches is rebased and armed for auto-merge, and GitHub merges it once its checks pass: the first unattended merges will most likely be those.

Then the menu, header "Ship it": Branch, commit, push and open the PR (Recommended) / Commit on a branch, I'll push myself / Stop here, keep the changes uncommitted.
Nothing leaves the machine before that answer.
Open the PR by the GitHub route available: `gh pr create`, `POST /repos/<github_repo>/pulls` with a token, or push the branch and give the link `https://github.com/<github_repo>/pull/new/<branch>` with the title and body to paste.
When the report says `fork: yes`, the branch is pushed to `origin`, the fork, and the PR opened on `<github_repo>` with the head `<origin owner>:<branch>`: `gh pr create --repo <github_repo> --head <origin owner>:<branch>`, the same `head` in the `POST` body, or the link `https://github.com/<github_repo>/compare/<default_branch>...<origin owner>:<branch>?expand=1`.

The PR body carries the GitHub settings acknowledged during the run as a checklist: the required checks of Step 9 and the exemption of Step 11.
A tick records that the user read, understood and took on the setting, nothing more, so a reviewer checks the gate instead of trusting it:

    Automerge starts when this PR merges. Renovate arms GitHub's
    auto-merge on every PR that qualifies, and GitHub merges it as soon
    as the required checks of the base branch pass, with no approval.
    The plugin changes no GitHub setting: the branch rules behind
    automerge are applied by hand. During the setup, the author
    acknowledged the settings below, what they do and that they are
    theirs to apply:
    - [x] Required status checks on the base branch, the whole gate,
          in a ruleset nobody bypasses: read, understood, to be set
          before this PR merges
    - [x] Konflux app exemption: Red Hat Konflux as an Exempt bypass
          actor of the ruleset holding the pull request rule and
          nothing else, "Block force pushes" in the checks ruleset,
          "Allow auto-merge" on: read, understood, to be set if the
          base branch requires approvals

    The ticks record that acknowledgement, not a verified state.
    Reviewer: check the settings before merging, and make sure the
    required checks are the ones that prove a change is good.

A setting whose verdicts opened with ✅ was not asked about: its item ends with `already in place` instead of the `read, understood, to be ...` clause.
A box stays unticked when its step ended without the "I read it" answer, and the body names what is still open.
When the Step 3 table removed `minimumConfidence` or a `matchConfidence` rule, one more paragraph before the attribution line, naming what was removed: `Removed \`minimumConfidence\`: MintMaker does not support Renovate's Merge Confidence features.`
When Step 2 printed a how-to, one more paragraph before the attribution line: `MintMaker is being disabled on <branch> by annotating its Konflux component(s) <components>, by hand: the rules in this file stop applying there once it is.`
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
| Every 4 hours, twice a day on busy Konflux clusters | MintMaker runs. A PR opens with GitHub's auto-merge armed, and GitHub merges it as soon as the required checks of the base branch pass: minutes after they went green, with no approval. |
| Once the release-age delay has passed | The PR for it appears, `renovate/stability-days` already green. Held updates are invisible: the dependency dashboard is off. |
| Right away | A vulnerability fix PR skips the release-age delay: a patch or minor fix in an automerged ecosystem merges as soon as the required checks pass, a fix that needs a major stays manual. Worth a look afterwards. |
| After each merge | The other open PRs are behind the base branch. When the branch rules require branches to be up to date, each one waits for MintMaker's next run to rebase it and rerun its checks; otherwise a green one merges as it is. A group PR lands its whole ecosystem in one merge. |
| In every PR body | `Automerge: Enabled` when the rules matched. Missing means the config didn't match that update: first thing to check. |
| First unattended merge | A PR merged by GitHub's auto-merge, armed by the Konflux app, with no approval confirms the exemption. Until then it's unverified. |
| Still waiting for you | Majors except the packages you named, the manual-review list, build toolchains unless you opted in, ecosystems without a rule. That is the intended scope. |
```

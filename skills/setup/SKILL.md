---
name: setup
description: Turns on Renovate automerge for low-risk dependency updates in a Konflux-onboarded repository, one decision at a time, and documents the GitHub branch-protection changes it needs. Run it from the repository with /mintmaker-automerge:setup.
disable-model-invocation: true
allowed-tools:
  - Bash(${CLAUDE_SKILL_DIR}/scripts/detect.sh)
---

# Renovate automerge setup

## Start here

Open with this paragraph, as is, then the plan:

> This skill configures Renovate to automerge the patch and minor
> dependency updates you vet as safe, gated by your CI checks and by
> MintMaker's release-age delay. Major bumps, packages you carve out,
> build-tool wrappers, and every ecosystem the config doesn't name stay
> manual. The goal is fewer PRs that need a human, not zero.

Then the plan, as a numbered list, so the user knows what's coming and which
questions they will get:

1. Check that the repo is onboarded in Konflux.
2. Detect the ecosystems, the default branch, and how GitHub Actions are
   pinned. Question: is the detected list right?
3. Find or place the Renovate config file. Question: where, if none exists.
4. Propose the automerge rules. Questions: how wide automerge goes per
   ecosystem, which packages stay manual, how to pin actions, whether to
   group npm bumps, whether to keep MintMaker's Saturday schedule for
   pipeline updates.
5. Check for Dependabot overlap. Question: remove, narrow, or keep
   `dependabot.yml`.
6. Show a summary table of what automerges and what stays manual, then write
   the config and show the diff.
7. Add the CI workflow that validates the config, if missing.
8. Walk through the GitHub settings: required checks, the Konflux bypass,
   "Allow auto-merge". Each one is confirmed before moving on.
9. Offer to branch, commit, and open a PR. Merging it turns automerge on.
10. Say what to expect once it's live.

Each step ends with something the user confirms or decides. Don't generate
the whole config unilaterally: automerge is a trust decision, and trust
comes from the user having chosen what gets automerged. Keep the
conversation to decisions and their consequences. The reasoning behind each
rule is in the comments of the generated config, which the team will read
later, and in long form in `references/why.md`, which you read when the
user asks why something is done a certain way.

## Repo facts

The bundled script `scripts/detect.sh` scanned the current repository when
this skill loaded. It is read-only and looks at tracked files only. Steps 1
to 7 read from this report instead of scanning again; do the checks by hand
only where the report is missing or incomplete.

!`"${CLAUDE_SKILL_DIR}/scripts/detect.sh"`

## Step 1: Confirm the repo is Konflux-onboarded

This skill only applies to repos onboarded in Konflux: the MintMaker base
config and the `tekton` block in Step 4 only make sense there. The Konflux
section of the report must show a `.tekton/` folder with YAML files and at
least one marker found: `pipelinesascode.tekton.dev` annotations or
`appstudio.openshift.io` labels. If not, stop and tell the user this skill
doesn't apply, rather than improvising a generic Renovate setup.

## Step 2: Detect what's in the repo

The Ecosystems section of the report lists each Renovate manager detected
and the first files that triggered it. Don't ask the user to enumerate
their own tech stack, and don't rescan. If the report is missing, detect by
hand from tracked files (`git ls-files`), never with a filesystem walk:
`find` picks up `node_modules/`, `target/` and vendored directories.

Helm charts and Terraform appear in the report but have no automerge block
in this skill, so they stay manual; say so, and do the same for anything
else you recognize that MintMaker updates. Wrappers and container base
images also stay manual unless the user asks otherwise: a base image bump
changes the runtime under every test.

Three more facts come from the report:

- **The default branch**, for Step 7's workflow. If the report says
  `unknown`, ask the user; don't assume `main`.
- **How workflows pin actions**: `tag`, `sha+version-comment`, or
  `sha-no-comment` per action, with a count. Step 4 needs it.
- **The distinct actions in use**, for the allow-list in Step 4.

Present the detected list to the user and ask them to confirm or correct
it before moving on. Auto-detection can be wrong (e.g. a `pom.xml` kept
around for a subproject that isn't really built anymore).

## Step 3: Find (or plan) the Renovate config file

The Renovate config section of the report names every config file found
(`renovate.json`, `.jsonc`, `.json5`, their `.github/` and `.renovaterc`
variants, or a `"renovate"` key in `package.json`) with its notable lines.

- **If one exists and is already `.jsonc`/`.json5`**, keep it as-is and add
  comments explaining the new rules, in the style of the bundled blocks.
- **If one exists as strict `.json`**, rename it to `.jsonc` as part of this
  change, and tell the user why first: every rule in the generated config
  carries a comment saying why it exists, and `.jsonc` is the extension for
  JSON with comments. Renovate reads comments in plain `.json` too, but its
  maintainers recommend `.jsonc` so editors, linters, and schema validators
  don't flag them as errors. Grep the repo for any other place that names
  the file (CI workflows that path-filter on it or pass it as an argument,
  docs, AGENTS.md/README) and update those references too: a rename that
  breaks a validator workflow is worse than no rename at all.
- **If none exists**, ask the user where they'd like it (default
  suggestion: `renovate.jsonc` at the repo root, the first location Renovate
  looks at and the one MintMaker's docs use).

Read whatever's already there before proposing changes. Existing custom
rules the user cares about (org-specific ignores, custom schedules,
non-automerge things) should be preserved, not silently dropped in favor of
a from-scratch file.

Two things an existing config may have that must go, with the reason given
to the user (details in `references/why.md`):

- An `"extends"` entry pointing at
  `github>konflux-ci/mintmaker//config/renovate/renovate.json`. MintMaker
  already applies that file as the global config of every onboarded repo,
  and its docs say not to copy it. The header comment in Step 4 replaces it.
- A `"baseBranchPatterns"` value. MintMaker sets it per Konflux component;
  a repo-level value repeats it or points at the wrong branch.

If the config extends a shared preset from another repo, read the preset
and report what it sets, in particular any `minimumReleaseAge` shorter than
MintMaker's, which would weaken the delay without anything in this repo
showing it.

## Step 4: Propose the automerge shape

Assemble the config from the two blocks below. Never fetch an example
config from another repository: these blocks are the reference.

The skeleton: header comment, the optional `extends` block for action
pinning, the `tekton` block, and a `{{PACKAGE_RULES}}` placeholder.

```jsonc
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  // This file only holds this repository's overrides.
  // MintMaker runs Renovate with its own global config and merges this file
  // on top of it, so every setting missing here is inherited from MintMaker:
  // the enabled managers, the minimumReleaseAge that holds back fresh releases,
  // the vulnerability alerts whose fix PRs skip that delay, the tekton and gomod
  // manager blocks, branch naming, PR limits, the Saturday schedule of the
  // tekton manager...
  // How the merge works:
  // - A setting written here replaces the inherited value.
  // - packageRules are added to the inherited rules, not replaced.
  // - A manager block such as "tekton": {...} merges key by key with the
  //   inherited block, so "tekton.automerge" below keeps MintMaker's own
  //   tekton packageRules.
  // - enabledManagers is the exception: setting it here replaces the whole
  //   inherited list, so this file never sets it.
  // Every packageRule below is limited to patch and minor updates: major bumps
  // always wait for a human. None sets minimumReleaseAge: the inherited delay
  // already holds back fresh releases, the usual shape of a compromised one.
  // Do not copy the global config here or add it to "extends": MintMaker's
  // deployment can pin a specific commit of it, and a copy silently drifts.
  // All automerge rules live in this file rather than in a shared preset:
  // the file is small, it rarely changes, and what merges unattended is
  // this repository's decision.
  // Global config: https://github.com/konflux-ci/mintmaker/blob/main/config/renovate/renovate.json
  // MintMaker docs: https://konflux-ci.dev/docs/mintmaker/user/
  "extends": [
    // Pins every GitHub Action to a commit SHA, so the github-actions rule below
    // can tell a version bump from a moved tag. Remove this block if the repo
    // already pins every action by SHA or chose not to pin.
    "helpers:pinGitHubActionDigests"
  ],
  "tekton": {
    // Konflux pipeline updates in .tekton/, the only folder this manager reads:
    // task bumps from the Konflux catalog, task replacements, and the pipeline
    // migrations MintMaker runs with them. The PR's own Konflux build is the test
    // of the change, so its check must be required on the base branch.
    "automerge": true,
    // Overrides MintMaker's Saturday schedule for pipeline updates. Remove this
    // line to keep the weekly batch.
    "schedule": ["at any time"]
  },
  "packageRules": [
    {{PACKAGE_RULES}}
  ]
}
```

The rule blocks: one commented block per Renovate manager, with variants
where a choice exists. Copy the blocks for the detected ecosystems into the
placeholder, keep their comments, fill the names marked `<...>`, and copy
exactly one variant where several are offered. Rules apply in order and a
later rule overrides an earlier one, so a carve-out goes after the rule it
narrows.

```jsonc
[
  // ---------------------------------------------------------------- github-actions
  {
    "matchManagers": ["github-actions"],
    // Excludes digest-only updates, so a hijacked tag re-pointed to a malicious commit
    // with no version delta never gets automerged. Only meaningful when actions are
    // pinned by SHA with a version comment.
    "matchUpdateTypes": ["patch", "minor"],
    // Actions run arbitrary code in CI, so each one is vetted by name.
    // Actions vetted for automerge. Add new ones deliberately.
    "matchDepNames": ["<action-in-use>", "<action-in-use>"],
    "automerge": true
  },

  // ---------------------------------------------------------------- maven
  {
    "matchManagers": ["maven"],
    "matchUpdateTypes": ["patch", "minor"],
    "automerge": true
  },
  {
    // Carve-out for a framework whose upgrades follow an LTS track, so a human picks
    // the target version instead of Renovate jumping to the newest minor.
    // Example: Quarkus, see https://quarkus.io/releases/. Replace or delete.
    "matchManagers": ["maven"],
    "matchPackageNames": ["io.quarkus*"],
    "automerge": false
  },
  {
    // Maven wrapper bumps (.mvn/wrapper/maven-wrapper.properties, mvnw) change the
    // build tool itself and need manual review.
    "matchManagers": ["maven-wrapper"],
    "automerge": false
  },

  // ---------------------------------------------------------------- gradle
  {
    "matchManagers": ["gradle"],
    "matchUpdateTypes": ["patch", "minor"],
    "automerge": true
  },
  {
    // Gradle wrapper bumps change the build tool itself and need manual review.
    "matchManagers": ["gradle-wrapper"],
    "automerge": false
  },

  // ---------------------------------------------------------------- gomod
  {
    "matchManagers": ["gomod"],
    "matchUpdateTypes": ["patch", "minor"],
    // MintMaker also enables updates of indirect dependencies, so they are covered too.
    "automerge": true
  },
  {
    // Optional: keep indirect dependency bumps on manual review. Delete if the
    // user is fine automerging them.
    "matchManagers": ["gomod"],
    "matchDepTypes": ["indirect"],
    "automerge": false
  },

  // ---------------------------------------------------------------- npm (pick one width)
  // Width 3, an allow-list, is the "any manager" block at the end with "npm" as
  // the manager.
  {
    // Width 1: every patch and minor bump. Relies on MintMaker's release-age delay
    // as the defense against a compromised release.
    "matchManagers": ["npm"],
    "matchUpdateTypes": ["patch", "minor"],
    "automerge": true
  },
  {
    // Width 2: development dependencies only. The runtime dependency list never
    // changes unattended, but build and test tooling does, and it runs in CI with
    // whatever the job can reach and produces the shipped artifact.
    "matchManagers": ["npm"],
    "matchDepTypes": ["devDependencies"],
    "matchUpdateTypes": ["patch", "minor"],
    "automerge": true
  },

  // ---------------------------------------------------------------- python
  {
    // Keep only the managers detected in the repo.
    "matchManagers": ["pip_requirements", "pip_setup", "pipenv", "poetry", "pep621"],
    "matchUpdateTypes": ["patch", "minor"],
    "automerge": true
  },

  // ---------------------------------------------------------------- cargo
  {
    "matchManagers": ["cargo"],
    "matchUpdateTypes": ["patch", "minor"],
    "automerge": true
  },

  // ---------------------------------------------------------------- bundler
  {
    "matchManagers": ["bundler"],
    "matchUpdateTypes": ["patch", "minor"],
    "automerge": true
  },

  // ---------------------------------------------------------------- any manager: allow-list width
  {
    // For a library ecosystem where the team wants an allow-list instead of every
    // patch and minor bump. Replace <manager> with the Renovate manager slug.
    "matchManagers": ["<manager>"],
    "matchPackageNames": ["<package>", "<package>"],
    "matchUpdateTypes": ["patch", "minor"],
    "automerge": true
  }
]
```

Everything MintMaker's global config already sets stays out of the file. If
the user asks for a key the blocks don't have, check the global config first
(`https://raw.githubusercontent.com/konflux-ci/mintmaker/main/config/renovate/renovate.json`):
a duplicate is redundant at best and drifts out of sync at worst.

Every comment in these blocks is a talking point. When you propose a block,
say what its comment says in a sentence or two, and ask the question it
leaves open: the schedule line of the `tekton` block, the `extends` block,
the Go indirect-dependency block, the Quarkus carve-out. If the repo already
has a header comment, merge the two rather than stacking them. The long
form of every point is in `references/why.md`, for when the user asks.

A few points have no comment to carry them. Say these too:

- **Vulnerability fixes skip the delay.** MintMaker enables Renovate's
  vulnerability alerts, built from the repository's GitHub security alerts,
  and a fix PR carries no release-age wait: a patch or minor fix in an
  automerged ecosystem merges as soon as CI passes, and a fix that needs a
  major bump stays manual. The config writes nothing for it. Say it once, so
  the user knows the delay has this exception.
- **The delay's one limit.** MintMaker sets `minimumReleaseAgeBehaviour` to
  `timestamp-optional`, so a release whose registry reports no publish date
  is not delayed.
- **The actions allow-list comes from Step 2.** Propose it from the actions
  found; don't make the user type names from memory. If Step 2 found
  tag-pinned actions, propose keeping the `helpers:pinGitHubActionDigests`
  block: Renovate then opens one PR per action to replace the tag with its
  SHA plus a version comment, of update type `pinDigest`, so those PRs stay
  manual. If the user declines, remove the block and say plainly that the
  allow-list then guards version bumps only, not moved tags. An action
  marked `sha-no-comment` gets no PRs at all, since Renovate cannot tell
  which version a bare SHA is; the fix is a `# vX.Y.Z` comment. Entries
  marked `reusable-workflow` are workflows called with `uses:`, not actions;
  leave them out of the allow-list.
- **Library ecosystems: ask how wide automerge goes**, per ecosystem, among
  three widths: every patch and minor bump; development dependencies only,
  where the manager distinguishes them (npm does); or an allow-list, the
  strongest and the most maintenance. The npm blocks carry the tradeoff of
  the first two, and the "any manager" block is the third.

For each detected ecosystem, ask: *"any packages here that should stay on
manual review instead of automerge?"* The typical case is a framework whose
upgrades follow an LTS track, so a human picks the target version; the
Maven block carries a Quarkus example to replace or delete. Look for
analogous concerns per ecosystem (Django, Spring Boot, a pinned Node LTS)
but ask rather than guess: this is the user's own upgrade policy.

If npm (or Yarn/pnpm, which the same manager covers) is detected, ask one
more thing: one PR per bump (Renovate's default) or one grouped PR, done by
adding a `groupName` to the chosen width block so the group holds only
updates that automerge. A grouped PR only automerges once every update in
it passes CI, so one broken bump blocks the batch, whereas independent PRs
let the unaffected ones through. Node projects accumulate many small bumps,
which is why this comes up for npm.

## Step 5: Check for Dependabot overlap

Repos often run both bots. Once Renovate automerges an ecosystem Dependabot
also covers, the two race to open a PR for the same bump, which is
confusing (two PRs, possibly conflicting, for one version).

The Dependabot section of the report lists each entry of
`.github/dependabot.yml` and whether its `directory:` exists. A stale entry
pointing at a moved or deleted directory covers nothing, since Dependabot
silently finds no files there. Flag it as dead independently of the overlap
question; the user may not know.

Compare the Dependabot ecosystems against the ones you just proposed for
Renovate automerge, and ask the user how to resolve the overlap:

- If every Dependabot entry is now covered by Renovate, offer to remove
  `dependabot.yml` entirely. Say what that removes: Dependabot version
  updates only. The Dependabot alerts setting, under the repo's Settings,
  Advanced Security, must stay on: Renovate's vulnerability fix PRs are
  built from those alerts.
- If some entries aren't covered (an ecosystem Renovate doesn't touch, or a
  directory Renovate isn't scanning), offer to narrow `dependabot.yml` down
  to just those, rather than an all-or-nothing choice.

Don't decide unilaterally: this changes which bot owns which dependency for
the whole repo. If you remove or narrow the file, grep for any doc
(AGENTS.md, README, dependency guidelines) that describes what Dependabot
covers and update it, as with the rename in Step 3.

## Step 6: Summarize the decisions, then write the config

Before writing anything, show the user the whole trust decision in one
place: a table with one row per detected ecosystem, one for the Konflux
pipeline, one for vulnerability fixes, and one for everything found that
gets no rule.

| Ecosystem | Automerges | Stays manual | Why |
|---|---|---|---|
| Maven | patch and minor bumps | majors, `io.quarkus*`, the Maven wrapper | Quarkus follows the LTS track |
| GitHub Actions | patch and minor bumps of `actions/checkout`, `actions/setup-java` | majors, digest-only updates, every other action | allow-list, SHA-pinned |
| Konflux pipeline | task bumps, replacements and migrations, any day | nothing | the Konflux PR build tests them, required in Step 8 |
| Vulnerability fixes | patch and minor fixes in the ecosystems above, without the release-age delay | fixes that need a major bump | inherited from MintMaker and Renovate's defaults |
| Container images | nothing | everything | no automerge pattern in this skill |

Below the table, list the Dependabot decision from Step 5 and the GitHub
settings Step 8 will ask for: which checks to require, the Konflux bypass,
"Allow auto-merge". Wait for the user to confirm before writing.

Then build the file (or edit the existing one) and show the user the diff
before considering this step done. If migrating an existing config, call
out anything you removed or restructured and why; don't let a rewrite
quietly drop a rule the user still wants.

The validator workflow of Step 7 checks syntax and schema only: a
misspelled package name in `matchPackageNames` or an action name in
`matchDepNames` passes and silently matches nothing. Compare every name in
the rules against the files and workflows found in Step 2 yourself, and say
so to the user.

## Step 7: Add the CI validator workflow if it's missing

A bad edit to the Renovate config (a typo, a JSONC comment in the wrong
place) otherwise doesn't surface until MintMaker itself chokes on it; there
is no local build step that would catch it. The report's
`validator_workflow` line names an existing one, if any. If it's missing,
add one from this base:

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

Fill in:

- `{{BASE_BRANCH}}`: the default branch recorded in Step 2.
- `{{CONFIG_FILENAME}}`: the config file's actual name from Step 3.
- `{{CHECKOUT_ACTION}}`: `actions/checkout` pinned the way the repo's other
  workflows pin it, per the report from Step 2 (by tag, or by SHA with a
  version comment), so the new workflow doesn't stick out.
- `{{VALIDATOR_ACTION_REF}}`: the action has no version tags, so pin it to
  the current commit of its `main` branch with a `# main` comment, the way
  MintMaker does: `gh api repos/konflux-ci/renovate-config-validator-action/commits/main --jq .sha`.
  Renovate will bump the SHA from there.

Keep the comment at the top and say it to the user: this workflow must never
be a required status check, because it only runs when the config file
changes and GitHub keeps a skipped required check "Pending" forever.

## Step 8: GitHub branch protection

Renovate merges through GitHub's auto-merge, which waits for the checks
marked required and nothing else: without a required check, GitHub can
merge a Renovate PR before its tests have started, while they run, or after
they failed. The required status check is what makes automerge wait for CI.

This step comes before the PR on purpose. None of these settings does
anything until automerge is live, so they go in first, and the PR of Step 9
then merges with the gate already in place. Tell the user that order.

Two names depend on the Konflux instance the repo is on: the GitHub App to
add to the bypass list, and the prefix of its status checks. Read both from
an existing MintMaker PR instead of assuming them:

    gh pr list --state all --limit 1 --search "head:konflux/mintmaker" \
      --json author,statusCheckRollup \
      --jq '.[0] | {app: .author.login, checks: [.statusCheckRollup[]? | (.name // .context)] | unique}'

`app` is the bot login, `app/red-hat-konflux` on one instance and a longer
name on others; in GitHub's bypass search the App appears under its display
name. `checks` is every check that ran on that PR, the Konflux pipeline one
included. If the command finds no PR, MintMaker has not opened one on this
repo yet: say so, and use the names below as placeholders.

Read `references/github-branch-protection.md` and walk the user through its
three parts, one at a time, each confirmed before the next:

1. **Required status checks.** Propose candidates from the checks listed by
   the command above and from `.github/workflows/`; which to require is the
   user's call per repo. The Konflux PR pipeline check, named like
   `Red Hat Konflux / <component>-on-pull-request`, is always a candidate:
   it is the only check that runs the updated pipeline of a `tekton` PR, so
   without it the `tekton` block automerges untested. The reference says
   which checks not to require, and why.
2. **The Konflux bypass**, letting the app found above skip the
   required-approval rule and nothing else, in "For pull requests only"
   mode. The reference has the ruleset mechanics.
3. **"Allow auto-merge" on the repository.** Speed, not safety: without it
   Renovate merges the PR itself on a later MintMaker run, hours later.

Do not change any of these settings yourself via `gh api`, even with
confirmation: repo-wide ruleset changes belong in a human's hands. If an
item cannot be done now (an org-level ruleset to change, missing admin
rights), record it: Step 9 puts it in the PR body as a reason not to merge
yet.

## Step 9: Offer to branch, commit, and open a PR

Once the file is ready and Step 8 is done, offer the usual git workflow: new
branch, commit, push, `gh pr create`. Confirm with the user before pushing
or opening the PR, as with any git operation that leaves the machine.

Merging this PR is what turns automerge on. Say so before opening it, and
put the Step 8 items in the PR body as a checklist, ticked as the user
confirmed them, so a reviewer sees the state of the gate:

    Automerge starts when this PR merges. Settings on the base branch:
    - [x] Required status checks include the CI checks agreed in the setup,
          the Konflux PR pipeline check among them
    - [x] The Konflux app bypasses the pull-request approval rule only
    - [x] "Allow auto-merge" is on in the repository settings

An item left unticked is a reason not to merge yet; say so in the body.

Once the PR is open, wait for the validator workflow and report its result
(`gh pr checks --watch`). A failure there is a syntax or schema error in the
config; fix it and push again before moving on.

## Step 10: Say what to expect

Close by telling the user how the first automerges will look, so a PR that
sits open for a while reads as the system working, not as a failure:

- MintMaker runs every 4 hours. A PR opens on one run; the merge happens on
  a later run, once CI passed and the branch is up to date with the base
  branch. Expect hours between the two, not minutes.
- A patch or minor release younger than MintMaker's release-age delay gets
  no PR until it is old enough, so the PR for a fresh release appears at
  least 3 days after publication, with a passing `renovate/stability-days`
  check. There is no view of the updates being held: MintMaker disables
  Renovate's dependency dashboard.
- A vulnerability fix PR opens and merges without the release-age wait,
  when it is a patch or minor bump in an automerged ecosystem. Those are
  the merges worth a look afterwards.
- Merges happen one PR at a time: each merge makes the other Renovate
  branches out of date, and they get rebased and merged on later runs.
- The PR body carries the line "Automerge: Enabled" when the rules match.
  If it's missing, the config didn't match that update, which is the first
  thing to check.
- The first PR from the Konflux app on a `konflux/mintmaker/...` branch
  that merges with passing checks and no human approval confirms the
  bypass works. Until then, the bypass is unverified.
- Majors, carve-outs, wrappers, and ecosystems without a rule still show up
  as ordinary PRs waiting for a human. That's the intended scope.

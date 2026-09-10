---
name: setup
description: Turns on Renovate automerge for low-risk dependency updates in a Konflux-onboarded repository, one decision at a time, and documents the GitHub branch-protection changes it needs. Run it from the repository with /mintmaker-automerge:setup.
disable-model-invocation: true
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

Each step ends with something the user confirms or decides. Don't skip ahead
and generate the whole config unilaterally: automerge is a trust decision,
and trust comes from the user having chosen what gets automerged.

The reasoning behind each rule lives in two places: the comments of the
generated config, which the team will read later, and
`references/why.md`, which you read when the user asks why something is
done a certain way. Keep the conversation itself to decisions and their
consequences.

## Repo facts

The bundled script `scripts/detect.sh` scanned the current repository when
this skill loaded. It is read-only and looks at tracked files only. Steps 1
to 7 read from this report instead of scanning again; do the checks by hand
only where the report is missing or incomplete.

!`bash "${CLAUDE_SKILL_DIR}/scripts/detect.sh"`

## Step 1: Confirm the repo is Konflux-onboarded

This skill only applies to repos that are onboarded in Konflux, because the
MintMaker base config (and the `tekton` automerge block in Step 4) only
makes sense there.

The Konflux section of the report must show a `.tekton/` folder with YAML
files and at least one marker found: `pipelinesascode.tekton.dev`
annotations or `appstudio.openshift.io` labels. If not, stop and tell the
user this skill doesn't apply. Don't improvise a generic Renovate setup: the
whole config shape is Konflux-specific.

## Step 2: Detect what's in the repo

The Ecosystems section of the report lists each Renovate manager detected
and the first files that triggered it. Don't ask the user to enumerate
their own tech stack, and don't rescan. The markers behind each line are
in `references/ecosystems.md`; read it only if the report is missing or
looks incomplete for this repo.

Helm charts and Terraform appear in the report but have no automerge block
in this skill, so they stay manual; say so. Do the same for anything else
you recognize that MintMaker updates. Wrappers and container base images
also stay manual unless the user asks otherwise: a wrapper bump changes
the build tool itself, and a base image bump changes the runtime under
every test.

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
  change. Renovate parses JSONC comments in plain `.json` files already, but
  its maintainers recommend the `.jsonc` extension to avoid editor
  confusion. Grep the repo for any other place that names the file (CI
  workflows that path-filter on it or pass it as an argument, docs,
  AGENTS.md/README) and update those references too — a rename that breaks
  a validator workflow is worse than no rename at all.
- **If none exists**, ask the user where they'd like it (default
  suggestion: `renovate.jsonc` at the repo root, the first location Renovate
  looks at and the one MintMaker's docs use).

Every rule in the generated file carries a comment saying why it exists.
Keep the comments of the bundled blocks, and write new ones in the same
style for anything repo-specific.

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

Assemble the config from two files bundled with the skill. Never fetch an
example config from another repository: the assets are the reference.

- `assets/renovate.jsonc.template`: the skeleton. Header comment, the
  optional `extends` block for action pinning, the `tekton` block, and a
  `{{PACKAGE_RULES}}` placeholder.
- `assets/package-rules.jsonc`: one commented rule block per manager, with
  variants where a choice exists. Copy the blocks for the detected
  ecosystems into the placeholder, keep their comments, fill the `<...>`
  names, and copy exactly one variant where several are offered.

Everything MintMaker's global config already sets stays out of the file;
the template is built that way. If the user asks for a key the template
doesn't have, check the global config first
(`https://raw.githubusercontent.com/konflux-ci/mintmaker/main/config/renovate/renovate.json`):
a duplicate is redundant at best and drifts out of sync at worst.

What to say and ask, per point. Keep each to a few sentences; the long form
is in `references/why.md` for when the user asks.

- **The header comment is required, in every generated or migrated file.**
  It names what is inherited and links to where the values live; it never
  restates a value. If the repo already has a header comment, merge the two
  rather than stacking them.
- **All local, no shared preset.** Say the two approaches exist, and why
  this file stays whole: it is small, it rarely changes, and automerge is
  this repo's trust decision.
- **The `tekton` block is always included.** Every Konflux repo has
  pipeline definitions in `.tekton/`, and that folder is all the manager
  reads. Say what automerges: every update the manager produces, which
  means catalog task bumps, task replacements, and MintMaker's pipeline
  migrations. The only test of such a change is the PR's own Konflux
  build, so Step 8 makes that check required. Ask about the schedule:
  `"at any time"` makes pipeline updates arrive within hours; dropping the
  line keeps MintMaker's Saturday batch.
- **No `minimumReleaseAge`.** MintMaker's delay applies on its own, 3 days
  at the time of writing, and it acts before any PR exists: Renovate skips
  a release younger than the delay until it is old enough, then opens the
  PR. So a fresh release shows up late rather than sitting open, and the
  delay covers manual updates as much as automerged ones. Tell the user its
  one limit: MintMaker sets `minimumReleaseAgeBehaviour` to
  `timestamp-optional`, so a release whose registry reports no publish
  date is not delayed.
- **Vulnerability fixes skip the delay.** MintMaker enables Renovate's
  vulnerability alerts, built from the repository's GitHub security alerts.
  A fix PR for an advisory carries no release-age wait, so a patch or minor
  fix in an automerged ecosystem merges as soon as CI passes. The plugin
  keeps that behavior and writes nothing for it. Say it once, so the user
  knows the delay has this exception, and that a fix which needs a major
  bump stays manual.
- **GitHub Actions get an allow-list.** Actions run arbitrary code in CI, so
  each one is vetted by name. Propose the list from the actions found in
  Step 2; don't make the user type names from memory.
- **The allow-list only protects SHA-pinned actions.** With
  `uses: owner/action@<sha> # v1.2.3`, a moved tag shows up as a `digest`
  update, which the patch/minor filter keeps out of automerge. With
  `uses: owner/action@v1`, CI runs whatever the tag points at and Renovate
  has nothing to open. If Step 2 found tag-pinned actions, propose keeping
  the `helpers:pinGitHubActionDigests` block: Renovate then opens one PR per
  action to replace the tag with its SHA plus a version comment. Those pin
  PRs have the `pinDigest` update type, so they stay manual. If the user
  declines, remove the block and say plainly that the allow-list then guards
  version bumps only, not moved tags. Two more cases from the report: an
  action marked `sha-no-comment` gets no PRs at all, since Renovate cannot
  tell which version a bare SHA is; the fix is to add the `# vX.Y.Z`
  comment. Entries marked `reusable-workflow` are workflows called with
  `uses:`, not actions; leave them out of the allow-list.
- **Library ecosystems: ask how wide automerge goes.** For Maven, Gradle,
  Go, npm, Python, Rust and Ruby, present the three widths and let the user
  pick per ecosystem:
  1. Every patch and minor bump. It relies on MintMaker's release-age delay,
     since supply-chain compromises usually ship as a patch release and are
     pulled within days.
  2. Development dependencies only, where the manager distinguishes them
     (npm does). The runtime dependency list never changes unattended, but
     build and test tooling does. It runs in CI on those PRs, with whatever
     the job can reach, and a bundler or compiler among it produces the
     shipped artifact.
  3. An allow-list, like the actions rule. Strongest, and the most
     maintenance.
  For Go, say that MintMaker enables updates of indirect dependencies too,
  so width 1 automerges them; the optional block keeps them manual.
- **Wrappers stay manual.** The Maven and Gradle wrapper blocks change the
  build tool itself; keep their `automerge: false` rules when detected.
- **Major version bumps are always excluded** (`matchUpdateTypes: ["patch",
  "minor"]`), regardless of ecosystem.

For each detected ecosystem, ask the user: *"any packages here that should
stay on manual review instead of automerge?"* The typical case is a
framework whose upgrades follow an LTS track, so a human picks the target
version rather than Renovate jumping to the newest minor; the Maven block
carries a Quarkus example to replace or delete. Look for analogous concerns
per ecosystem (e.g. Django, Spring Boot, a pinned Node LTS) but don't
assume; ask rather than guess, since this is a judgment call about the
user's own upgrade policy.

If npm (or, by extension, Yarn/pnpm) is detected, ask one more thing:
whether each dependency bump gets its own PR (Renovate's default) or one
grouped PR, a `groupName` added to the chosen width block so the group
holds only updates that automerge. A grouped PR only automerges once every
update in the group passes CI, so one broken bump blocks the whole batch,
whereas independent PRs let the unaffected ones through. Node projects tend
to accumulate many small bumps, which is why this comes up for npm.

## Step 5: Check for Dependabot overlap

Before writing the config, check for `.github/dependabot.yml`. Repos often
run both bots. Once Renovate automerges an ecosystem Dependabot also
covers, two bots race to open a PR for the same bump, which is confusing
(two PRs, possibly conflicting, for one version).

The Dependabot section of the report lists each entry and whether its
`directory:` exists. A stale entry pointing at a moved or deleted directory
covers nothing, since Dependabot silently finds no files there. Flag it as
dead independently of the overlap question; the user may not know.

Compare the ecosystems in `dependabot.yml` against the ones you just
proposed for Renovate automerge, and ask the user how to resolve the
overlap:

- If every Dependabot entry is now covered by Renovate, offer to remove
  `dependabot.yml` entirely. Say what that removes: Dependabot version
  updates only. The Dependabot alerts setting, under the repo's Settings,
  Advanced Security, must stay on: Renovate's vulnerability fix PRs, enabled
  by MintMaker's global config, are built from those alerts.
- If some entries aren't covered (e.g. an ecosystem Renovate doesn't touch,
  or a directory Renovate isn't scanning), offer to narrow `dependabot.yml`
  down to just those, rather than an all-or-nothing choice.

Don't decide unilaterally: this changes which bot owns which dependency
for the whole repo. If you remove or narrow the file, grep for any doc
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
out anything you removed or restructured and why — don't let a rewrite
quietly drop a rule the user still wants.

The file is validated in CI, by the workflow from Step 7, once the PR from
Step 9 is open. Know what that validator checks: syntax and schema only.
MintMaker's docs say it "cannot verify that, for example, a file matching
pattern will actually match any files in your repository". A misspelled
package name in `matchPackageNames` or an action name in `matchDepNames`
passes validation and silently matches nothing, so compare every name in
the rules against the files and workflows found in Step 2 yourself, and say
so to the user.

## Step 7: Add the CI validator workflow if it's missing

A bad edit to the Renovate config (a typo, a JSONC comment in the wrong
place) otherwise doesn't surface until MintMaker itself chokes on it —
there's no local build/test step that would catch it. The report's
`validator_workflow` line names an existing one, if any. Some repos already
have this; most won't.

If it's missing, add one using
`assets/renovate-config-validator.yaml.template` as the base. It uses
`konflux-ci/renovate-config-validator-action`, the action MintMaker runs on
its own repository, with `strict: true` so a config that needs migration
fails too. Fill in:

- `{{BASE_BRANCH}}` — the default branch recorded in Step 2.
- `{{CONFIG_FILENAME}}` — the config file's actual name from Step 3.
- `{{CHECKOUT_ACTION}}` — match this repo's existing convention rather than
  picking one yourself. Look at another workflow already in
  `.github/workflows/` for how it references `actions/checkout`: some repos
  pin by tag (`actions/checkout@v7`), others pin by commit SHA with a
  version comment (`actions/checkout@<sha> # v7.0.1`). Copy whichever style
  the repo already uses so this new workflow doesn't stick out as
  inconsistent.
- `{{VALIDATOR_ACTION_REF}}` — the action has no version tags, so pin it to
  the current commit of its `main` branch with a `# main` comment, the way
  MintMaker does: `gh api repos/konflux-ci/renovate-config-validator-action/commits/main --jq .sha`.
  Renovate will bump the SHA from there.

Tell the user never to make this workflow a required status check, and keep
the comment at the top of the template. It only runs when the config file
changes. GitHub keeps a skipped required check "Pending", so on every other
PR, including every dependency PR, merging would be blocked forever.

## Step 8: GitHub branch protection — required checks and the Konflux bypass

Renovate automerges through `platformAutomerge`, on by default: it enables
GitHub's auto-merge on the PR, and GitHub merges as soon as the branch rules
allow. Renovate's own automerge waits for every check to pass, but GitHub's
only waits for the checks marked required. Renovate's docs say that without
that platform-side rule, the platform might merge Renovate PRs even if the
repository's tests have not started, are still in progress, or have failed.
So the required status check is what makes automerge wait for CI.

This step comes before the PR on purpose. None of these settings does
anything until automerge is live, so they can go in first, and the PR of
Step 9 can then merge as soon as it is reviewed, with the gate already in
place. Tell the user that order and why.

Two names in this step depend on the Konflux instance the repo is on: the
GitHub App to add to the bypass list, and the prefix of its status checks.
Read both from an existing MintMaker PR instead of assuming them:

    gh pr list --state all --limit 1 --search "head:konflux/mintmaker" \
      --json author,statusCheckRollup \
      --jq '.[0] | {app: .author.login, checks: [.statusCheckRollup[]? | (.name // .context)] | unique}'

`app` is the bot login, `app/red-hat-konflux` on one instance and a longer
name on others; in GitHub's bypass search the App appears under its display
name. `checks` is every check that ran on that PR, the Konflux pipeline one
included. If the command finds no PR, MintMaker has not opened one on this
repo yet: say so, and use the names below as placeholders.

Read `references/github-branch-protection.md` for the full steps and walk
the user through its three parts:

1. **Required status checks** — the repo's build/test/quality workflows
   should be marked required in the branch's ruleset, so a broken automerge
   PR can't land. Propose candidates from the checks of the last MintMaker
   PR, listed by the command above, and from `.github/workflows/`, but this
   is the user's call per repo. The Konflux PR pipeline check, named like
   `Red Hat Konflux / <component>-on-pull-request`, is always a candidate:
   it is the only check that runs the updated pipeline of a `tekton` PR, so
   without it the `tekton` block automerges untested. Advise against
   requiring checks that are flaky, that fail for reasons outside the PR's
   diff (a CVE-scanning workflow is the classic case), or that do not run
   on every PR: the Renovate config validator from Step 7, and
   `renovate/stability-days`, which the command above lists because it
   exists on Renovate PRs only. The reference explains each case.
2. **The Konflux bypass** — letting the Konflux app found above skip the
   required-approval rule specifically (not required status checks, which
   should still apply to it). Recommend the "For pull requests only" bypass
   mode: Renovate only ever merges through a PR, so the narrower mode loses
   nothing.
3. **"Allow auto-merge" on the repo** — Settings → General → Pull Requests.
   Without it GitHub's auto-merge is unavailable and Renovate falls back to
   merging the PR itself on a later MintMaker run, which comes every 4
   hours. This changes how fast PRs merge, not whether CI gates them.

Do not change any of these settings yourself via `gh api`, even with
confirmation. This skill only documents the steps for the user to apply in
the GitHub UI: repo-wide ruleset changes belong in a human's hands.

Ask the user to confirm each of the three items once it is done. If one
cannot be done now (an org-level ruleset to change, missing admin rights),
record it: Step 9 puts it in the PR body as a reason not to merge yet.

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

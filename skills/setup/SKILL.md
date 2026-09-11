---
name: setup
description: Turns on Renovate automerge for low-risk dependency updates in a Konflux-onboarded repository, one decision at a time, and documents the GitHub branch-protection changes it needs. Run it from the repository with /mintmaker-automerge:setup.
disable-model-invocation: true
model: sonnet
allowed-tools:
  - Bash(${CLAUDE_SKILL_DIR}/scripts/detect.sh)
---

# Renovate automerge setup

A guided conversation in ten short steps that ends with a reviewed Renovate
config on a branch, an open PR, and the GitHub settings in place. Automerge
is a trust decision, so the user makes every consequential choice. Your job
is to make each choice small, well framed, and quick to answer, and to teach
just enough along the way.

## How the conversation feels

The user is in a terminal. Claude Code renders Markdown tables, bold, code,
and emoji, and the AskUserQuestion tool draws a selection menu. Use both.

- **One screen per step.** A header `### ▶️ Step N/10 <title>`, then a
  table or a few bullets with what was found, at most one 💡 note, then the
  question. Stay under about twelve lines before the question. The full
  reasoning lives in the comments of the generated config and in
  `references/why.md`; the conversation is for decisions and their
  consequences.
- **Every decision is an AskUserQuestion.** Recommended option first,
  with "(Recommended)" inside its label, as in `Rename to renovate.jsonc
  (Recommended)`: the mark in the description does not show. Each
  option's description states its consequence in one line. Use `multiSelect` for lists such as actions and checks. When a step
  has several independent questions, put them in one AskUserQuestion call,
  up to four, so the user answers a screen rather than a drip. Never ask a
  question that has one option: the tool rejects it, and a step with
  nothing to decide closes with a ✅ line instead.
- **The screen is written before the menu, every time.** After a menu
  answer comes back, the reply has two parts in this order: first the next
  step's screen as ordinary assistant text, then the AskUserQuestion call.
  Claude Code renders that text in full above the menu; what it folds into
  a one-line summary is thinking, not text. A reply that goes from one menu
  answer straight to the next menu call shows the user nothing. Reading
  files or running commands a step needs comes before the screen, never
  between the screen and the menu.
- **Teach in 💡 notes.** Every 💡 note in this file is shown where it
  stands, one or two sentences each, never a paragraph: they are how the
  user learns what Renovate and MintMaker do while deciding. When the
  user asks why, read `references/why.md` and answer from it in a few
  lines.
- **Few emojis, each with a meaning:** ✅ confirmed, 🟢 automerges,
  🛑 stays manual, ⚠️ needs attention, 💡 a note, ▶️ in front of every
  step header, and 🤖 once, in the welcome title. Nothing else, and never
  in prose.
- **A skipped step still shows.** When the scan makes a step moot, print
  its header and one line saying why, then the next step's full screen
  in the same message, so the count stays honest. Skipping a step never
  skips the screen of the step after it: its menu comes only once its
  screen is printed.
- **Recap once.** The Step 8 table is the one full recap. Elsewhere a
  single ✅ line closes a step and the next header follows.
- **No transitions.** The next header is the transition. Never announce
  what the next step will ask or why it comes now; if that matters, it
  belongs under the header, not before it.
- **Never generate the whole config unilaterally.** Trust comes from the
  user having chosen what gets automerged.
- **Reach GitHub however works here.** The report's Tooling section says
  whether `gh` is logged in. It is the easiest route when it is, and never
  a requirement: the GitHub REST API over `curl`, with a `GITHUB_TOKEN`
  or `GH_TOKEN` from the environment when one is set, reads and creates
  the same things; `raw.githubusercontent.com` serves public files;
  `git` pushes branches and resolves refs; and when nothing else works, a
  link the user opens in the browser, with the text to paste, still gets
  the job done. Pick the route yourself, say which one you used in a few
  words, and never ask the user to install or log into anything.

## Repo facts

The bundled script `scripts/detect.sh` scanned the current repository when
this skill loaded. It is read-only and looks at tracked files only. Steps 1
to 8 read from this report instead of scanning again; do the checks by hand
only where the report is missing or incomplete. Its last sections hold the
Step 1 and 2 screens, the candidates Step 3 turns into options, and the
tables Steps 4 and 5 open with, ready to print.

!`"${CLAUDE_SKILL_DIR}/scripts/detect.sh"`

## Welcome screen

Print this verbatim, and nothing else before the question:

```
### 🤖 MintMaker automerge setup

This plugin turns on automerge for the dependency updates you decide are low-risk, gated by your CI checks and by MintMaker's release-age delay. Everything else keeps waiting for a human. Fewer PRs needing you, not zero.

How this works:
- Ten short steps, about ten minutes, a dozen quick decisions.
- The config is written only after you approve the summary.
- The PR is opened only after you approve it.
- No GitHub setting is ever changed by this skill.
```

No question here. The Step 1 screen follows in the same message, so the
first menu the user meets is the one confirming the detected ecosystems.

## Step 1: Detected ecosystems

This skill only applies to repos onboarded in Konflux: the MintMaker base
config and the `tekton` block of the generated config only make sense
there. The report ends with a "Screens" section the script rendered from
its own findings: the Konflux check line and the ecosystems table, or the
stop message when the check fails. Print it verbatim, tables included,
right after the welcome screen in the same message, before the menu.
Composing the screen yourself, or summing it up in a sentence, is the one
thing to avoid: the user sees only what is printed. When the check fails,
print the stop message and end the conversation there rather than
improvising a generic Renovate setup.

The table lists each ecosystem found with the files behind it. What
automerges is not on it: that is decided in Steps 3 to 6 and shown in the
Step 8 summary. Don't ask the user to enumerate their own stack and don't
rescan; if the report is missing entirely, detect by hand from
`git ls-files`, never with `find`, which walks `node_modules/`, `target/`
and vendored directories, and lay the result out the same way.

Ask, header "Ecosystems": Looks right (Recommended) / Needs a correction,
where the user types the fix as the free-text answer. Auto-detection can
be wrong, for instance a `pom.xml` kept around for a subproject nobody
builds anymore. If the default branch is `unknown`, add a **Default
branch** question rather than assuming `main`.

## Step 2: Renovate config file

The report names every config file found, with its notable lines and its
full content, and its last sections hold the table for this step: points
of attention only, what gets removed, what is redundant, which presets
were read, or a single ✅ line when there is nothing of the kind. Rules
that simply stay are one line under it, not rows. No need to read the
file again. Existing custom rules the user cares about are preserved, not
dropped in favor of a from-scratch file.

Three cases, each one screen:

- **A `.jsonc` or `.json5` file exists.** Print the table verbatim, close
  with one ✅ line saying the file stays where it is, and go on to Step 3
  in the same message: there is no decision to ask for here, and a menu
  with a single option is rejected by the tool. Its two ⚠️ rows are the things that must go: an `extends` of
  `github>konflux-ci/mintmaker//config/renovate/renovate.json`, since
  MintMaker already applies that file globally and its docs say not to
  copy it, and `baseBranchPatterns`, which MintMaker sets per component.
  When a row names a shared preset from another repo, its content is in
  the report too, fetched at load; report what it sets under the table,
  in particular any `minimumReleaseAge` shorter than MintMaker's. Only
  when the report says it could not fetch it, read it before the screen
  by whatever route reaches GitHub here, `gh api`, the REST API over
  `curl`, or the raw file URL.
- **A strict `.json` file exists.** Same table printed verbatim, then
  this note, then a question, header "Rename", with the labels
  `Rename to renovate.jsonc (Recommended)`, described as being for the
  comments, and `Keep .json`, described as the comments then showing as
  errors in some editors.

  💡 Every rule the skill writes carries a comment saying why it exists.
  Renovate reads comments in plain `.json` too, but the `.jsonc`
  extension is what tells editors, linters and schema validators that
  comments are expected there, so they stop flagging them as errors.

  On rename, grep the repo for other places
  that name the file (workflows that path-filter on it, README, AGENTS.md)
  and update them: a rename that breaks a validator workflow is worse than
  none.
- **No config.** Question, header "Location": `renovate.jsonc` at the root
  (Recommended), the first place Renovate looks and the one MintMaker's
  docs use / `.github/renovate.jsonc`.

💡 MintMaker runs Renovate with its own global config and merges
your file on top, so the file only holds this repo's overrides.

## Step 3: Libraries

For the library ecosystems found (Maven, Gradle, Go, npm, Python, Cargo,
Bundler), one screen: a line proposing the rule for the ecosystems found,
worded as a proposal since nothing is decided yet, the note, then two
questions in one call. The manual-review candidates of the report do not
get printed as a list here: they become the first option of the second
question. Majors that may automerge for named packages are asked in
Step 6, not here: this screen is about the rule and what it must never
touch.

```
### ▶️ Step 3/10 Libraries

Proposed rule for <the library ecosystems found, e.g. Go modules and npm>: patch and minor bumps merge on their own once CI passes, majors wait for a human. Narrow or widen it below.
```

💡 Every scope gets the same two protections, MintMaker's release-age
delay and your required checks. A wider scope only puts more updates
behind them unattended; an allow-list adds a human decision per package,
at the cost of maintaining the list.

First, header "Scope": Every patch and minor bump (Recommended) /
Development dependencies only, where the manager knows the difference,
npm does / Only packages I'll name / Decide per ecosystem. The last option
leads to one question per ecosystem with the first three scopes. When an
allow-list is chosen, ask for the package names in a follow-up.

Second, header "Never automerge", question "Any packages that should
never be automerged, whatever the scope?", multiSelect: one option per
manual-review candidate of the report, marked (Recommended) and naming
why in the description, such as an LTS track, folded into a single
option when there are several / Other packages, I'll name them / None,
marked (Recommended) when the report has no candidate. A package on this
list still gets PRs; they wait for a human whatever the update type.
When "I'll name them" was picked, ask for the names in a follow-up.

## Step 4: GitHub Actions

When the scan found no workflow, print the header and one line, `Skipped:
no GitHub workflows in this repo.`, and go on to Step 5 in the same
message. Otherwise open with the actions table from the report's last
sections, printed verbatim, one row per action with its pin style, then
two questions in one call.

First, header "Pin actions", only when the scan found tag-pinned actions:
Pin every action to a SHA (Recommended), Renovate opens one manual PR per
action to replace the tag with its SHA and a version comment / Don't pin,
the allow-list then guards version bumps only, not moved tags. Second,
header "Allow-list", multiSelect with three options built from the
table's "Maintained by" column: Actions maintained by GitHub
(Recommended), the `actions/*` and `github/*` ones, named in the
description / Third-party actions, the rest, named in the description
with their owners / I'll type which ones to allow. Ticking both groups
allows every action found; the typed answer replaces the groups. Leave
out entries marked `reusable-workflow`: they are workflows called with
`uses:`, not actions. An action marked `sha-no-comment` gets no PRs at all, since Renovate
cannot tell which version a bare SHA is; say so and name the fix, a
`# vX.Y.Z` comment.

💡 Actions run arbitrary code in CI with whatever the workflow token
reaches, so each one is vetted by name, and only a SHA-pinned action lets
Renovate tell a version bump from a moved tag.

## Step 5: Base images and wrappers

When the scan found neither a container file nor a Maven or Gradle
wrapper, print the header and one line, `Skipped: no container file or
build-tool wrapper in this repo.`, and go on to Step 6 in the same
message. Otherwise open with the base images table from the report's last
sections, printed verbatim, one row per `FROM` image with its pin style,
then up to three questions in one call, each only when relevant.

Header "Base images", when a container file was found: Automerge digest,
patch and minor bumps (Recommended), the Konflux PR build builds the image
and the tests run on it, majors such as a new RHEL or JDK line stay manual
/ Keep them manual. Header "Pin base images", only when the scan shows a
base image without a digest: Pin to `tag@sha256` (Recommended), Renovate
opens one manual pin PR, after which rebuilds of the same tag arrive as
digest PRs / Keep tags only, rebuilds then go unnoticed. Header
"Wrappers", when a wrapper was found: Keep manual (Recommended), updates
are rare and a bad one breaks every developer's local build, not just CI
/ Automerge patch and minor, CI builds with the new wrapper on every PR.

💡 The Konflux PR build builds the image of a base image PR and runs the
tests on it, so requiring that check in Step 9 is what tests the change.

When the table flags `latest` tags, say it in one line before the
questions: a `latest` tag carries no version, so Renovate has nothing to
bump there; with the digest pinned, rebuilds of `latest` arrive as digest
PRs, which is the only base image update those files can get. The pin
question then matters more than the automerge one, and the automerge
option's description says "digest updates" rather than "patch and minor".

## Step 6: Konflux pipeline and extras

Up to four questions in one call, the first two always, the others only
when relevant. Header "Pipeline": Konflux pipeline updates any day
(Recommended), within hours of a catalog bump / Keep MintMaker's Saturday
batch. When the report flags path-filtered PR pipelines, add a third
option, Keep pipeline updates manual, and say in the question why: a
path-filtered pipeline cannot be a required check, so a `tekton` PR for
it would merge before its build reports. Header "Majors", question "Any packages whose major bumps may
automerge too?": No package, majors wait for a human (Recommended) /
Yes, for packages I'll name. Propose no candidates: which majors are safe
unattended is project knowledge, a test framework with good coverage or
a tool used only in CI, and guessing would push the scope wider than
asked; when the user names packages, ask in the same follow-up why their
majors are safe to merge, since that reason becomes the comment of the
rule and CI is the only gate on those merges. Header "Go indirect", when
`go.mod` was found: Automerge indirect dependencies too (Recommended) /
Keep them manual. Header "npm PRs", when `package.json` was found: One PR
per bump (Recommended), a broken bump blocks only itself / One grouped
PR, which merges only when every bump in it passes.

💡 The Konflux PR build runs the updated pipeline of a `tekton` PR, so
requiring that check in Step 9 is what tests the change.

Two facts have no question and no comment to carry them. Say them once,
as 💡 notes, at the end of this step:

- Vulnerability fix PRs skip the release-age delay: a patch or minor fix
  in an automerged ecosystem merges as soon as CI passes. A fix that needs
  a major bump stays manual.
- A release whose registry reports no publish date is not delayed, since
  MintMaker sets `minimumReleaseAgeBehaviour` to `timestamp-optional`.

Close the step with one line: `✅ Rules chosen. Summary in Step 8.`

## Step 7: Other updaters

When the report says `dependabot.yml: none` and
`base_image_workflows: none`, print the header and one line, `Skipped: no
other updater in this repo.`, and go on to Step 8 in the same message.
Otherwise, once
Renovate automerges an ecosystem another updater also covers, the two
race to open a PR for the same bump.

The report's "Other updaters" line names workflows that mention base
images, typically a home-grown base-image auto-update workflow. When the
user chose to automerge base images in Step 5, show the workflow and ask
header "Base image workflow": Remove it, Renovate covers this now (Recommended)
/ Keep it, two updaters on the same FROM line. Then the Dependabot part.

Show one table from the report's Dependabot section, one row per entry:
ecosystem, directory, and a status: ⚠️ overlaps Renovate, ✅ not covered
by Renovate, or ⚠️ directory missing. A stale entry pointing at a deleted
directory covers nothing, since Dependabot silently finds no files there;
flag it whatever the overlap says, the user may not know.

Then ask header "Dependabot": when every entry overlaps, Remove
`dependabot.yml` (Recommended) / Keep it, two PRs per bump; when some
entries don't overlap, Narrow it to the entries Renovate doesn't cover
(Recommended) / Remove it entirely / Keep it. Say next to the Remove
option that this removes Dependabot version updates only: the
Dependabot alerts setting under Settings, Advanced Security must stay on,
because Renovate's vulnerability fix PRs are built from those alerts. If
you remove or narrow the file, grep for any doc that describes what
Dependabot covers and update it.

💡 Dependabot alerts and Dependabot version updates are two features;
only the second one is replaced here.

## The config blocks

Assemble the config in Step 8 from the two blocks below, driven by the
answers of Steps 3 to 6. Never fetch an example config from another
repository: these blocks are the reference.

### The skeleton

Header comment, the optional `extends` block for action pinning, the
`tekton` block, and a `{{PACKAGE_RULES}}` placeholder. Drop the
`extends` block when the user declined pinning or every action is already
SHA-pinned; drop the `schedule` line when they kept the Saturday batch.

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
  // The packageRules below are limited to patch and minor updates by default:
  // a major bump waits for a human unless a rule names its package. None sets
  // minimumReleaseAge: the inherited delay already holds back fresh releases,
  // the usual shape of a compromised one.
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

### The rule blocks

One commented block per Renovate manager, with variants where a choice
exists. Copy the blocks for the detected ecosystems into the placeholder,
keep their comments, fill the names marked `<...>`, and copy exactly one
variant where several are offered. Rules apply in order and a later rule
overrides an earlier one, so a manual-review rule or a majors rule goes
after the ecosystem rule it narrows or widens. Everything MintMaker's
global config already sets stays out of the file; if the user asks for a
key the blocks don't have, check the global config first, since a
duplicate drifts out of sync.

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
    // Manual review for a framework whose upgrades follow an LTS track, so a human picks
    // the target version instead of Renovate jumping to the newest minor.
    // Example: Quarkus, see https://quarkus.io/releases/. Replace or delete.
    "matchManagers": ["maven"],
    "matchPackageNames": ["io.quarkus*"],
    "automerge": false
  },
  {
    // Maven wrapper bumps (.mvn/wrapper/maven-wrapper.properties, mvnw) change the
    // build tool for every developer, not just CI, so they wait for a human.
    // Variant when the team opted in: matchUpdateTypes ["patch", "minor"], automerge true.
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
    // Gradle wrapper bumps change the build tool for every developer, not just CI,
    // so they wait for a human. Variant when the team opted in: matchUpdateTypes
    // ["patch", "minor"], automerge true.
    "matchManagers": ["gradle-wrapper"],
    "automerge": false
  },

  // ---------------------------------------------------------------- dockerfile (base images)
  {
    // Base image bumps: the Konflux PR build builds the image and the tests run on
    // it, so its check must be required. Digest updates are rebuilds of the same
    // tag, the security-patch stream; patch and minor follow the registry's
    // versioning. A new RHEL or JDK line is a major and waits for a human.
    "matchManagers": ["dockerfile"],
    "matchUpdateTypes": ["digest", "patch", "minor"],
    "automerge": true
  },
  {
    // Optional: pin every FROM line to tag@sha256 so rebuilds of the same tag show
    // up as digest PRs. Renovate opens one manual pin PR first. Delete if the
    // images are already pinned or the team chose tags only.
    "matchManagers": ["dockerfile"],
    "pinDigests": true
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
  // the manager. A grouped PR adds "groupName": "npm automerge" to the chosen block.
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

  // ---------------------------------------------------------------- any manager: majors too
  {
    // Major bumps of these packages automerge too: <the user's reason>.
    // CI is the only gate on them, so the tests must cover their use.
    "matchManagers": ["<manager>"],
    "matchPackageNames": ["<package>", "<package>"],
    "matchUpdateTypes": ["major"],
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

## Step 8: Summary, then write

Before writing anything, show the whole trust decision in one table: one
row per detected ecosystem, one for the Konflux pipeline, one for
vulnerability fixes, and one row per ecosystem found that gets no rule.
This screen is never skipped and never shortened, whatever came before
it, and the "Write it" menu is not asked until it has been printed: the
user approves what they see in that table, nothing else.
Below it, one line with the Step 7 decision, when there was one, then
one line saying what the answer does: it writes files in the working
tree, nothing more. Nothing is committed or pushed before Step 10.

```
### ▶️ Step 8/10 Summary, then write to disk

| Ecosystem | 🟢 Automerges | 🛑 Stays manual | Why |
|---|---|---|---|
| Maven | patch, minor; majors of `org.assertj:*` | other majors, `io.quarkus*`, wrapper | Quarkus follows an LTS track; AssertJ is test-only |
| GitHub Actions | patch, minor of `actions/checkout`, `actions/setup-java` | majors, digest-only, every other action | allow-list, SHA-pinned |
| Konflux pipeline | task bumps, migrations, any day | – | the Konflux PR build tests them |
| Vulnerability fixes | patch, minor, without the release-age delay | fixes needing a major | inherited from MintMaker |
| Base images | digest, patch, minor of `ubi9/openjdk-21` | majors, a new RHEL or JDK line | the Konflux PR build tests the image |
| Maven wrapper | – | everything | kept manual, every developer builds with it |

Dependabot: `dependabot.yml` removed, alerts stay on.

Writing means editing files in your working tree. Nothing is committed or pushed until Step 10.
```

Ask, header "Write it", labels `Write the files to disk (Recommended)`,
described as local edits only, no commit, no push / `Change something`,
with the free text saying what. Then build the file, or edit the existing
one, and show the diff. When migrating an existing config, list what you
removed or restructured and why, so a rewrite never quietly drops a rule
the user still wants.

The validator workflow below checks syntax and schema only: a misspelled
package or action name passes and silently matches nothing. Compare every
name in the rules against the files and workflows of the scan yourself,
and say `✅ Written, every name checked against the repo.`

Then the validator workflow, in the same step. 
A bad edit to the Renovate config otherwise surfaces only when MintMaker
chokes on it; there is no local build step. The report's
`validator_workflow` line names an existing one. When it exists, say so in
one line. When missing, add this workflow, show the file, and close the
step with one line: no question, since there is nothing to decide.

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

Fill in `{{BASE_BRANCH}}` from Step 1, `{{CONFIG_FILENAME}}` from Step 2,
`{{CHECKOUT_ACTION}}` pinned the way the repo's other workflows pin it so
the new file doesn't stick out, and `{{VALIDATOR_ACTION_REF}}` with the
current commit of the action's `main` branch, since it has no version
tags: the report's `validator_action_main_sha` line has it, and when that
says unknown, resolve it by any route that reaches GitHub, `git ls-remote`
on the action's repository being the simplest.

💡 A required check that doesn't run on every PR stays "Pending"
forever and blocks the merge, which is why this workflow must never be
required. Step 9 comes back to it.

## Step 9: GitHub settings

GitHub's auto-merge and Renovate's own merge both wait for the checks
marked required and for nothing else, so this step is the gate. It comes
before the PR on purpose: none of these settings does anything until
automerge is live, so they go in first and the PR of Step 10 merges with
the gate already in place. This is the one step that takes several
turns: the step header and the primer are printed once, then the two
settings follow as sections, each with a bold title, one 💡 note at
most, and its own menu. No counters in titles, no second step header.
The skill never changes a setting itself, even with confirmation:
ruleset changes belong in a human's hands.
`references/github-branch-protection.md` has the long form for "why?"
questions; do not paraphrase it into the screens.

Everything on these screens comes from the report and this file, so they
read the same without GitHub access. Reaching GitHub adds one thing:
confirmation of the app login from an existing MintMaker PR, for the
bypass section. Try it before that section, by whatever route works
here, and drop it silently when none does. With `gh`:

    gh pr list --state all --limit 1 --search "head:konflux/mintmaker" \
      --json author,statusCheckRollup \
      --jq '.[0] | {app: .author.login, checks: [.statusCheckRollup[]? | (.name // .context)] | unique}'

Over the REST API, list `/repos/<github_repo>/pulls?state=all&per_page=100`,
keep the newest whose `head.ref` starts with `konflux/mintmaker/`, take
its author's login and its check runs. `app` is the bot login,
`app/red-hat-konflux` on one instance and a longer name on others; in
GitHub's bypass search the App appears under its display name. When
nothing is found, the report's derived names stand, flagged as "verify on
the first MintMaker PR".

**The primer.** Printed verbatim under the step header, then the first
section follows in the same message:

```
### ▶️ Step 9/10 GitHub settings

Automerge is only as safe as the branch protection behind it. On GitHub that lives in rulesets (Settings › Rules › Rulesets, per repository or for a whole organization) or, on older repositories, in branch protection rules (Settings › Branches). Both do the same job; rulesets are the current form.

This step goes through two settings:
1. Require status checks to pass, the rule that makes GitHub wait for CI. Critical: without it, a Renovate PR merges the moment its rules match, whatever CI says later. Nothing else in this setup can catch a bad merge.
2. Require a pull request before merging with approvals, only if your branch has that rule. It is a project choice, not a requirement of this setup; when it exists, the Konflux app needs to bypass it, and nothing else.

💡 Rules protect a branch, not the repository: look at the ruleset that targets your base branch.
```

**Required status checks.** Guidance, then a confirmation. The skill
suggests no list for this repository: which checks to require is the
user's decision. Print this verbatim:

```
**Required status checks**
Where: Settings › Rules › Rulesets › the ruleset for your base branch › Require status checks to pass. On branch protection rules: Settings › Branches › the rule for the branch › Require status checks to pass.

Require what proves the PR's own change is good, typically:
- the build, a job like `Build`, `mvn verify` or `go build`
- the test suite, `Test` or `Unit tests`, when it is a separate job
- the Konflux PR pipeline, `Red Hat Konflux / <component>-on-pull-request`, which builds the image and, for a pipeline update, is the only check that runs the updated pipeline

Never require:
- a check that does not run on every PR, such as the Renovate config validator or `renovate/stability-days`: GitHub keeps it "Pending" forever and the PR never merges
- a check that goes red for reasons unrelated to the PR, such as a CVE or vulnerability scan: one new advisory blocks every PR until someone unrelated fixes it, and people learn to override the gate

The picker only offers checks GitHub has seen recently; a missing name shows up after the next PR that runs it.

💡 Required but unreliable is worse than not required: a gate people bypass protects nothing.
```

Menu, header "Checks", two labels: `I read it, understood it, and will
set the required checks before automerge goes live (Recommended)` /
`I'm not sure, help me understand`. On the second answer, explain from
`references/github-branch-protection.md` in a few lines, answer what the
user asks, and the report's "Konflux names" and "Workflow jobs" sections
may serve as illustration of what this repository's checks are called,
never as a list to set. Then ask the same question again.

**The Konflux app bypass.** After the checks answer, in a new message
without the step header. It applies only to a branch that requires an
approval, and says so first. The organization angle comes before the
per-repository clicks, every time: an organization ruleset can grant the
bypass once for every repository on Konflux, and a repository already
covered by one has nothing to do here. The app name is the display name
of the login found above, `Red Hat Konflux` by default.

```
**The Konflux app bypass**
Only if the base branch requires a pull request with approvals: that rule blocks the app like anyone else, so it needs to bypass that rule and nothing else. A branch without an approval rule needs nothing here; automerge works without one.

Organization first: if an organization ruleset already lets `Red Hat Konflux` bypass the pull request rule, nothing to do. If many repositories in the organization are on Konflux, one such ruleset from an organization admin, targeting those repositories, beats repeating this in every one of them.

Per repository, on rulesets: Settings › Rules › Rulesets › the ruleset holding "Require a pull request before merging" › Bypass list › Add bypass › `Red Hat Konflux` › "For pull requests only". A bypass covers the whole ruleset, so if that ruleset also holds other rules, the required checks for instance, move the pull request rule to a ruleset of its own first.
On branch protection rules: Settings › Branches › the rule for `main` › "Require a pull request before merging" › "Allow specified actors to bypass required pull requests" › add the app.

💡 The bypass removes the human approval only. The app still has to pass every required check, and "For pull requests only" keeps it from pushing to the branch directly.
```

Menu, header "Bypass", two labels: `I read it, understood it, and will
set the bypass if my branch needs one (Recommended)` / `I'm not sure,
help me understand`. On the second answer, explain from
`references/github-branch-protection.md` in a few lines, the ruleset
splitting and the organization ruleset in particular, answer what the
user asks, and ask the same question again.

The PR body of Step 10 records both confirmations as given; the skill
does not verify the settings, the user's word is the state.

## Step 10: Pull request, then what to expect

Merging this PR is what turns automerge on. Say so in one line, then ask
header "Ship it": Branch, commit, push and open the PR (Recommended) /
Commit on a branch, I'll push myself / Stop here, keep the changes
uncommitted. Nothing leaves the machine without that answer. Open the PR
by whatever route reaches GitHub here: `gh pr create`, or `POST
/repos/<github_repo>/pulls` over the REST API with a token, or, when
neither works, push the branch and give the user the link
`https://github.com/<github_repo>/pull/new/<branch>` with the title and
body below it to paste.

The PR body carries the Step 9 items as a checklist, ticked as the user
confirmed them, so a reviewer sees the state of the gate:

    Automerge starts when this PR merges. Settings on the base branch,
    as confirmed during the setup:
    - [x] Required status checks are set, so no PR merges before CI passes
    - [x] The Konflux app bypasses the pull-request approval rule only,
          or the branch has no approval rule

Both boxes are ticked by the user's confirmations in Step 9; say in the
body that they are the reviewer's cue to double-check before merging.

The body ends with the attribution line, verbatim, so a reviewer knows
where the config came from and where its reasoning is documented:

    Set up with the [MintMaker Automerge](https://github.com/gwenneg/mintmaker-automerge) plugin for Claude Code.
Once the PR is open, watch the validator workflow when a route allows it,
`gh pr checks --watch` or the check-runs endpoint of the REST API, and
report the result in one line; when the user opened the PR from a link,
tell them to watch that check on the PR page instead. A failure there is
a syntax or schema error in the config: fix it and push again.


Then, in the same message, close with this table, so a PR that sits open
for a while reads as the system working, not as a failure, and a one-line
farewell with the PR link and nothing after it.

```
Once it is live:

| When | What you'll see |
|---|---|
| Every 4 hours | MintMaker runs. A PR opens on one run and merges on a later one, once CI passed and the branch is up to date. Hours, not minutes. Turning on Settings › General › Allow auto-merge lets GitHub merge as soon as the checks pass instead. |
| 3+ days after a release | The PR for it appears, `renovate/stability-days` already green. Held updates are invisible: the dependency dashboard is off. |
| Right away | A vulnerability fix PR, no delay. Worth a look afterwards. |
| One at a time | Each merge makes the other Renovate branches stale; they rebase and merge on later runs. |
| In every PR body | `Automerge: Enabled` when the rules matched. Missing means the config didn't match that update: first thing to check. |
| First unattended merge | A Konflux-app PR merged with green checks and no approval confirms the bypass. Until then it's unverified. |
| Still waiting for you | Majors except the packages you named, the manual-review list, wrappers unless you opted in, ecosystems without a rule. That is the intended scope. |
```

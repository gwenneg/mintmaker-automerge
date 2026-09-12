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
- **The header is never skipped.** Every step, 1 to 10, prints its
  header as text before anything else of that step, and a step's menu is
  never called in a message that has not printed that step's header
  first. The header is what tells the user where they are; a menu that
  appears without one reads as the tool asking out of nowhere. This
  holds when a step is skipped, when it has nothing to show but its
  questions, and when the previous step ended with a closing line.
- **Every decision is an AskUserQuestion.** Recommended option first,
  with "(Recommended)" inside its label, as in `Rename to renovate.jsonc
  (Recommended)`: the mark in the description does not show, and
  exactly one option per question carries it, in a multi-select too. Each
  option's description states its consequence in one line. Use `multiSelect` for lists such as actions and checks. When a step
  has several independent questions, put them in one AskUserQuestion call,
  up to four, so the user answers a screen rather than a drip. Never ask a
  question that has one option: the tool rejects it, and a step with
  nothing to decide closes with one plain line instead.
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
- **Few emojis, each with a meaning:** ⚠️ needs attention, ✅ its
  opposite as a table status only, 🟢 automerges, 🛑 stays manual, 💡 a
  note, ▶️ in front of every step header, and 🤖 once, in the welcome
  title. Nothing else, never in prose, and none on a line that opens or
  closes a step.
- **A skipped step still shows.** When the scan makes a step moot, print
  its header and one line saying why, then the next step's full screen
  in the same message, so the count stays honest. Skipping a step never
  skips the screen of the step after it: its menu comes only once its
  screen is printed.
- **Recap once.** The Step 8 table is the one full recap. A step closes
  with a plain line only where this file spells one out, because it
  carries a fact the user needs; otherwise the next header follows the
  answer directly.
- **No transitions.** The next header is the transition. The first line
  of the message after an answer is that header: no acknowledgement of
  the answer ("Ecosystems confirmed."), no announcement of what comes
  next ("Moving to the Renovate config file."), no reason why it comes
  now. If any of that matters, it belongs under the header, not before
  it.
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
### 🤖 MintMaker Automerge Setup

This plugin turns on automerge for the dependency updates you decide are low-risk, gated by your CI checks and by MintMaker's release-age delay. Everything else still needs a reviewer, human or AI, so your attention goes to the updates that deserve it.

How this works:
- Ten short steps, a few quick decisions along the way, fifteen minutes end to end.
- The config is written only after you approve the summary, in Step 8.
- GitHub settings are explained click by click, in Step 9, but never changed by this skill: you apply them yourself.
- The PR is opened only after you approve it, in Step 10.
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

The report names every config file found, with its full content and the
other files that name it, and its last sections hold the table for this step: points
of attention only, what gets removed, what is redundant, which presets
were read, or a single plain line when there is nothing of the kind. Rules
that simply stay are one line under it, not rows. No need to read the
file again. Existing custom rules the user cares about are preserved, not
dropped in favor of a from-scratch file.

Three cases, each one screen:

- **A `.jsonc` or `.json5` file exists.** Print the table verbatim, close
  with one line saying the file stays where it is, and go on to Step 3
  in the same message: there is no decision to ask for here, and a menu
  with a single option is rejected by the tool. Every ⚠️ row is something
  Step 8 removes: an `extends` of
  `github>konflux-ci/mintmaker//config/renovate/renovate.json`, since
  MintMaker already applies that file globally and its docs say not to
  copy it; `baseBranchPatterns`, which MintMaker sets per component;
  `minimumReleaseAge`, which MintMaker sets globally; and
  `enabledManagers`, which would replace MintMaker's whole manager list,
  unless the user says that was intended.
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

  💡 Every rule gets a comment saying why it exists. Renovate reads
  comments in `.json` too, but only `.jsonc` tells editors and validators
  they belong there.

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
worded as a proposal since nothing is decided yet, the note, then three
questions in one call: the rule, what it must never touch, and what it
may reach beyond. The manual-review candidates of the report do not get
printed as a list here: they become the first option of the second
question.

```
### ▶️ Step 3/10 Libraries

Proposed rule for <the library ecosystems found, e.g. Go modules and npm>: patch and minor bumps merge on their own once CI passes, majors stay on manual review. Narrow or widen it below.
```

💡 Every scope gets the same two protections, MintMaker's release-age
delay and your required checks. A wider scope only puts more updates
behind them unattended; an allow-list adds a decision per package,
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
list still gets PRs; they stay on manual review whatever the update type.
When "I'll name them" was picked, ask for the names in a follow-up.

Third, header "Majors", question "Any packages whose major bumps may
automerge too?": No package, majors stay on manual review (Recommended) /
Yes, for packages I'll name. Propose no candidates: which majors are safe
unattended is project knowledge, a test framework with good coverage or
a tool used only in CI, and guessing would push the scope wider than
asked; when the user names packages, ask in the same follow-up why their
majors are safe to merge, since that reason becomes the comment of the
rule and CI is the only gate on those merges.

## Step 4: GitHub Actions

When the scan found no workflow, print the header and one line, `Skipped:
no GitHub workflows in this repo.`, and go on to Step 5 in the same
message. Otherwise open with the actions table from the report's last
sections, printed verbatim, one row per action with its pin style, then
three questions in one call.

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
`# vX.Y.Z` comment. Third, header "Majors", question "Any actions whose
major bumps may automerge too?": No action, majors stay on manual review
(Recommended), a major of an action often changes its inputs or the
Node runtime it needs / Yes, for actions I'll name. Propose no
candidates. The named actions must be on the allow-list, since a major
of an action nobody vetted has no business merging alone; ask in the
same follow-up why their majors are safe, for the comment of the rule.

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

The screen first, then the menu. Under the header, one line per row of
the report's Konflux pipeline section: the PR pipelines found in
`.tekton/`, and whether any is path-filtered. Then the note, then the
questions. Print the header and the note verbatim:

```
### ▶️ Step 6/10 Konflux pipeline and extras

Konflux pipelines found: <one line per PR pipeline, from the report, with "path-filtered" where the report says so>

💡 The Konflux PR build runs the updated pipeline of a `tekton` PR, so requiring that check in Step 9 is what tests the change.
```

Up to three questions in one call, the first always, the others only
when relevant. Header "Pipeline": Konflux pipeline updates any day
(Recommended), within hours of a catalog bump / Keep MintMaker's Saturday
batch. When the report flags path-filtered PR pipelines, add a third
option, Keep pipeline updates manual, and say in the question why: a
path-filtered pipeline cannot be a required check, so a `tekton` PR for
it would merge before its build reports. Header "Go indirect", when
`go.mod` was found: Automerge indirect dependencies too (Recommended) /
Keep them manual. Header "npm PRs", when `package.json` was found: One PR
per bump (Recommended), a broken bump blocks only itself / One grouped
PR, which merges only when every bump in it passes.

Two facts have no question and no comment to carry them. Say them once,
as 💡 notes, at the end of this step:

- Vulnerability fix PRs skip the release-age delay: a patch or minor fix
  in an automerged ecosystem merges as soon as CI passes. A fix that needs
  a major bump stays manual.
- A release whose registry reports no publish date is not delayed, since
  MintMaker sets `minimumReleaseAgeBehaviour` to `timestamp-optional`.

Close the step with one line: `Rules chosen. Summary in Step 8.`

## Step 7: Other updaters

When the report says `dependabot.yml: none` and
`base_image_workflows: none`, print the header and one line, `Skipped: no
other updater in this repo.`, and go on to Step 8 in the same message.
Otherwise, once Renovate automerges an ecosystem another updater also
covers, the two race to open a PR for the same bump.

**The screen comes whole before any question.** Under the header, one
table with every other updater found, one row per item, then the 💡
note, then one AskUserQuestion carrying every question this step has.
No menu appears until the whole table has been printed, and the two
questions below go in that single call, not one after the other.

The table has three columns: updater, what it covers, status. The rows:

- One row per workflow in the report's `base_image_workflows` line,
  typically a home-grown base-image auto-update workflow, with the
  workflow path and the `FROM` lines it touches. Status: ⚠️ overlaps
  Renovate when the user chose to automerge base images in Step 5,
  otherwise "not covered by Renovate" without a mark.
- One row per entry listed under the report's `dependabot.yml: found`
  line, with ecosystem and directory. Status: ⚠️ overlaps Renovate, ✅ not covered by
  Renovate, or ⚠️ directory missing. A stale entry pointing at a deleted
  directory covers nothing, since Dependabot silently finds no files
  there; flag it whatever the overlap says, the user may not know.

💡 Dependabot alerts and Dependabot version updates are two features;
only the second one is replaced here.

Then the questions, in one AskUserQuestion call, each only when its rows
exist:

- Header "Base image workflow", only when a workflow row overlaps: Remove
  it, Renovate covers this now (Recommended) / Keep it, two updaters on
  the same FROM line.
- Header "Dependabot", only when `dependabot.yml` exists: when every entry
  overlaps, Remove `dependabot.yml` (Recommended) / Keep it, two PRs per
  bump; when some entries don't overlap, Narrow it to the entries
  Renovate doesn't cover (Recommended) / Remove it entirely / Keep it.
  Say next to the Remove option that this removes Dependabot version
  updates only: the Dependabot alerts setting under Settings, Advanced
  Security must stay on, because Renovate's vulnerability fix PRs are
  built from those alerts.

This step only records the answers. The removal or narrowing itself, and
the update of any doc that describes what Dependabot or the workflow
covers, happen in Step 8 after the "Write it" answer, never here.

## The config blocks

Assemble the config in Step 8 from the two blocks below, driven by the
answers of Steps 3 to 6. Never fetch an example config from another
repository: these blocks are the reference.

### The skeleton

Header comment, the optional `extends` block for action pinning, the
`tekton` block, and a `{{PACKAGE_RULES}}` placeholder. Drop the
`extends` block when the user declined pinning or every action is already
SHA-pinned; drop the `schedule` line and its comment when they kept the
Saturday batch. The comments are part of the file the user keeps: copy
them as they are, never add instructions meant for you, and never
restate what the header already says.

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

### The rule blocks

One block per Renovate manager, with variants where a choice exists.
Copy the blocks for the detected ecosystems into the placeholder, fill
the names marked `<...>`, and copy exactly one variant where several are
offered. Rules apply in order and a later rule overrides an earlier one,
so a manual-review rule or a majors rule goes after the ecosystem rule
it narrows or widens. Everything MintMaker's global config already sets
stays out of the file; if the user asks for a key the blocks don't have,
check the global config first, since a duplicate drifts out of sync.

Each ecosystem opens with a separator line that states its decision, the
same facts as its row of the Step 8 table: what merges on its own, then
what stays manual. That line is the comment of the plain patch-and-minor
rule, which carries none of its own. A rule that narrows or widens the
policy carries one or two lines saying why, and nothing else: no
"optional", no "delete if", no restating of the policy.

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

  // --- maven: patch and minor; majors, io.quarkus* and the wrapper stay manual
  {
    "matchManagers": ["maven"],
    "matchUpdateTypes": ["patch", "minor"],
    "automerge": true
  },
  {
    // Quarkus follows an LTS track: a reviewer picks the target version. https://quarkus.io/releases/
    "matchManagers": ["maven"],
    "matchPackageNames": ["io.quarkus*"],
    "automerge": false
  },
  {
    // The wrapper is every developer's build tool, not just CI's.
    "matchManagers": ["maven-wrapper"],
    "automerge": false
  },

  // --- gradle: patch and minor; majors and the wrapper stay manual
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

  // --- gomod: patch and minor, indirect dependencies included; majors stay manual
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

  // --- npm: patch and minor; majors stay manual
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

- Wrappers, when the user opted in: the wrapper rule becomes
  `"matchUpdateTypes": ["patch", "minor"], "automerge": true`, with the
  comment `// CI builds with the new wrapper on every PR.`, and the
  separator line says the wrapper merges.
- Manual-review packages: one rule per candidate kept or package named,
  under its own manager and after that manager's rule, with the reason
  as its comment, as in the Quarkus example: Spring Boot under `gradle`
  or `maven`, Angular under `npm`, Django under the python managers.
  Candidates folded into one menu option still get one rule each; none
  when the user chose none.
- Base images: drop the `pinDigests` rule when the images are already
  pinned or the user kept tags only; drop the automerge rule when they
  kept base images manual, and the separator line then says so.
- Go: drop the indirect rule when the user automerges indirect
  dependencies; the separator line says whether they are included.
- npm: copy exactly one of the two rules; the allow-list width is the
  "allow-list width" block with `npm` as the manager. A grouped PR adds
  `"groupName": "npm automerge"` to the chosen rule, with the comment
  `// One PR for every npm bump; it merges only when all of them pass.`
- Python: keep only the managers the report detected.
- Majors: one block per manager; for GitHub Actions use `matchDepNames`
  instead of `matchPackageNames`. The user's reason from the follow-up
  is the comment.

## Step 8: Summary

**Nothing touches the working tree before the "Write it" answer.** Up
to that answer the skill has only read files and asked questions, and
`git status` looks exactly as it did when the skill started. No Write,
no Edit, no `git rm` or `git mv`, no doc update, no removal decided in
Step 7, and no name check that needs the file to exist. The menu labels
below are fixed: a menu that says the files are already written means
the order was wrong, not that the labels need adapting.

Show the whole trust decision in one table: one row per detected
ecosystem, one for the Konflux pipeline, one for vulnerability fixes,
and one row per ecosystem found that gets no rule. This screen is never
skipped and never shortened, whatever came before it, and the "Write it"
menu is not asked until it has been printed: the user approves what they
see in that table, nothing else. Below it, one line with the Step 7
decision, when there was one, then one line saying what the answer does:
it writes files in the working tree, nothing more. Nothing is committed
or pushed before Step 10.

```
### ▶️ Step 8/10 Summary

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
with the free text saying what.

After the "Write the files" answer, and only then, the write phase, in
this order:

1. Build the config file, or edit the existing one, rename it when Step 2
   said so, drop every ⚠️ row of the Step 2 table, and show the diff.
   When migrating an existing config, list what you removed or
   restructured and why, so a rewrite never quietly drops a rule the
   user still wants.
2. Apply the Step 7 decisions: remove or narrow `dependabot.yml`, remove
   the base-image workflow, and update any doc that describes what they
   covered. Files those tools wrote, such as a digest tracking file, go
   with the workflow that wrote them; say so in one line.
3. Check the names. The validator workflow below checks syntax and
   schema only: a misspelled package or action name passes and silently
   matches nothing. Compare every name in the rules against the files
   and workflows of the scan yourself, and say `Written, every name
   checked against the repo.`
4. The validator workflow, below.

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

The write phase ends there, with no question: no "does this look
right", no confirmation of the files, and no question about the pull
request, which is Step 10's. The next message opens with the Step 9
header and the required-checks screen below, and the Checks menu comes
only once that screen is printed.

## Step 9: GitHub settings

Required checks are the gate: GitHub's auto-merge and Renovate's own
merge wait for them and for nothing else. The step comes before the PR
so the gate is in place when the PR of Step 10 merges. It takes two
turns: the first message holds the step header and the required-checks
screen with its menu; the bypass screen with its menu follows in a new
message once the first is answered. Neither screen mentions the other,
and there is no second step header. The skill never changes a setting
itself, even with confirmation: ruleset changes belong in a human's
hands. `references/github-branch-protection.md` has the long form for
"why?" questions; do not paraphrase it into the screens.

Both screens come from the report and this file: no GitHub access, no
tool call between them. The app is always `Red Hat Konflux`, the GitHub
App owned by `redhat-appstudio`, and that name is hardcoded in the
bypass screen.

**Required status checks.** Printed verbatim, header included. The
skill suggests no list for this repository: which checks to require is
the user's decision.

```
### ▶️ Step 9/10 GitHub settings

Automerge is only as safe as the branch protection behind it. On GitHub that lives in rulesets (Settings › Rules › Rulesets) or, on older repositories, in branch protection rules (Settings › Branches). Same job, rulesets are the current form. Look at the one that targets your base branch.

**Required status checks**

GitHub's auto-merge and Renovate's own merge wait for the checks marked required, and for nothing else. Without them, a Renovate PR merges as soon as its rules match, whatever CI says later.

Where: the ruleset for your base branch › Require status checks to pass. On branch protection rules: the rule for the branch › Require status checks to pass.

Require what proves the PR's own change is good, typically:
- the build, a job like `Build`, `mvn verify` or `go build`
- the test suite, when it is a separate job
- the Konflux PR pipeline, `Red Hat Konflux / <component>-on-pull-request`: it builds the image, and for a pipeline update it is the only check that runs the updated pipeline

Never require:
- a check that does not run on every PR, such as the Renovate config validator or `renovate/stability-days`: GitHub keeps it "Pending" forever and the PR never merges
- a check that goes red for reasons unrelated to the PR, such as a vulnerability scan: one new advisory blocks every PR until someone fixes it, and people learn to override the gate

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

**The Konflux app bypass.** In a new message after the checks answer,
without the step header. Printed verbatim.

```
**The Konflux app bypass**

Only if the base branch requires a pull request with approvals. That rule blocks the app like anyone else, so the app needs to bypass it, and nothing else. No approval rule, nothing to do: automerge works without one.

Organization first: if an organization ruleset already lets `Red Hat Konflux` bypass the pull request rule, nothing to do here either. With many Konflux repositories in the organization, one such ruleset from an organization admin beats repeating this in each of them.

Per repository, on rulesets: Settings › Rules › Rulesets › the ruleset holding "Require a pull request before merging" › Bypass list › Add bypass › `Red Hat Konflux`, the GitHub App owned by `redhat-appstudio` › "For pull requests only". A bypass covers the whole ruleset, so if that ruleset also holds the required checks, move the pull request rule to a ruleset of its own first.
On branch protection rules: Settings › Branches › the rule for the branch › "Require a pull request before merging" › "Allow specified actors to bypass required pull requests" › add the app.

💡 The bypass removes the approval only. The app still has to pass every required check, and "For pull requests only" keeps it from pushing to the branch directly.
```

Menu, header "Bypass", two labels: `I read it, understood it, and will
set the bypass if my branch needs one (Recommended)` / `I'm not sure,
help me understand`. On the second answer, explain from
`references/github-branch-protection.md` in a few lines, the ruleset
splitting and the organization ruleset in particular, answer what the
user asks, and ask the same question again.

The PR body of Step 10 records both answers for what they are,
acknowledgements: the skill does not verify the settings, and the body
says so.

## Step 10: Pull request, then what to expect

The step header first, `### ▶️ Step 10/10 Pull request`, then one line,
`Merging this PR is what turns automerge on.`, then the menu, header
"Ship it": Branch, commit, push and open the PR (Recommended) / Commit
on a branch, I'll push myself / Stop here, keep the changes uncommitted.
Nothing leaves the machine without that answer. Open the PR
by whatever route reaches GitHub here: `gh pr create`, or `POST
/repos/<github_repo>/pulls` over the REST API with a token, or, when
neither works, push the branch and give the user the link
`https://github.com/<github_repo>/pull/new/<branch>` with the title and
body below it to paste.

The PR body carries the two Step 9 settings as a checklist. A tick
means the user read the guidance, understood it, and took on setting it,
nothing more, and the body says so, so a reviewer checks the gate
instead of trusting it:

    Automerge starts when this PR merges. The plugin changes no GitHub
    setting: the branch protection behind automerge is applied by hand.
    During the setup, the author acknowledged both settings below, what
    each one does and that it is theirs to apply on the base branch:
    - [x] Required status checks, so no PR merges before CI passes:
          read, understood, to be set before this PR merges
    - [x] Konflux app bypass of the approval rule only, "For pull
          requests only": read, understood, to be set if the base
          branch requires approvals

    The ticks record that acknowledgement, not a verified state.
    Reviewer: check both settings on the base branch before merging.

A box stays unticked if the user ended Step 9 without the "I read it,
understood it" answer, and the body then names what is still open.

The body ends with the attribution line, verbatim, so a reviewer knows
where the config came from and where its reasoning is documented:

    Set up with the [MintMaker Automerge](https://github.com/gwenneg/mintmaker-automerge) plugin for Claude Code.

**The closing message.** Once the PR is open, the skill is done with
GitHub: no check watch, no status poll, no background task, no reading
of the PR's checks. The skill ends with one message, in this order, and
the table in it is never skipped or shortened: it is what makes a PR
that sits open for a while read as the system working, not as a
failure.

1. The PR link on its own line.
2. One line: the validator workflow reports on the PR page, and a
   failure there is a syntax or schema error in the config to fix and
   push again.
3. The table below, printed verbatim.
4. A one-line farewell, and nothing after it: no reminder of Step 9, no
   offer to keep watching, no summary of what was done.

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

# MintMaker Automerge

**Stop clicking merge on dependency bumps that never needed your judgment.**

MintMaker Automerge is a [Claude Code](https://claude.com/claude-code)
plugin for repositories onboarded in [Konflux](https://konflux-ci.dev/). It
walks you through turning on Renovate automerge for the updates that can be
judged by config alone, one decision at a time, and documents the GitHub
branch-protection changes automerge needs to be safe. Run it from the
repository:

```
/mintmaker-automerge:setup
```

The updates you decide are low-risk merge on their own once CI passes,
after MintMaker's release-age delay. Everything else, and every ecosystem
you leave out, stays on manual review, exactly as today.

> [!IMPORTANT]
> This plugin only makes sense for repositories whose dependency updates
> come from [MintMaker](https://github.com/konflux-ci/mintmaker), the
> Renovate service of Konflux. It stops on any other repository.

## Why MintMaker Automerge

- **Every consequential choice is yours.** The skill detects your
  ecosystems and proposes an allow-list, then asks: how wide automerge goes
  per ecosystem, which packages stay manual, which CI checks gate the merge.
  Nothing is decided silently, and a summary table shows the whole trust
  decision before a byte is written.
- **Config-driven, not judgment-driven.** Narrow, explicit rules are what
  make it acceptable to remove the human from the loop. No reviewer, human
  or AI, has to catch a bad release in the moment.
- **Built on MintMaker's release-age delay.** MintMaker's
  [global config](https://github.com/konflux-ci/mintmaker/blob/main/config/renovate/renovate.json)
  holds back a fresh release before opening a PR, for the window in which
  compromised releases are usually caught and pulled. The plugin inherits
  that delay rather than restating it, so it never drifts.
- **GitHub Actions are allow-listed by name.** Actions run arbitrary code
  in CI, so each one is vetted individually, and only version bumps of
  SHA-pinned actions qualify. A moved tag never merges on its own.
- **Branch protection is treated as the gate, not as paperwork.** The
  plugin explains the repository setting that lets GitHub do the merging
  on the required checks alone, which status checks to require, how to
  let the Konflux app skip an approval rule and nothing else when the
  branch has one, and asks you to confirm the settings are in place
  before it opens the PR.
- **One readable file, no shared preset.** The generated config is small,
  commented where a decision was made, and complete on its own. What merges unattended
  in a repository stays that repository's decision.

## Quick start

You need [Claude Code](https://claude.com/claude-code) and a
Konflux-onboarded repository, one with a `.tekton/` folder. A fork
clone works too: the GitHub settings and the PR target the upstream, and
the branch is pushed to the fork. A `gh` login
is handy, not required: with it Step 10 shows what the repository has
today and the skill opens the PR itself, without it Claude reaches GitHub
another way, the REST API with a token if one is set, or a link you open
to create the PR yourself. Install from
the [claude-ichiba](https://github.com/gwenneg/claude-ichiba) marketplace:

```
/plugin marketplace add gwenneg/claude-ichiba
/plugin install mintmaker-automerge@claude-ichiba
/reload-plugins
```

Then, from the repository you want to set up:

```
/mintmaker-automerge:setup
```

The skill opens with a scan of the repository. Every decision is a menu
with a recommended option, each step fits on one screen with a one-line note on
what Renovate and MintMaker do there, and a summary table shows the whole
trust decision before a byte is written. Expect a few quick decisions along the way and fifteen minutes end to end. At the
end you have a reviewed config file on a branch, an open PR, and the
GitHub settings in place.

The skill pins Sonnet for its run, whatever model the session uses,
because the current Fable model writes nothing between two menus and so
hides every step screen. If your organization's model allowlist excludes
Sonnet, the session model is used instead.

Claude Code only auto-updates plugins from its official marketplace.
Enable auto-update for claude-ichiba in the `/plugin` panel, or refresh it
yourself with `/plugin marketplace update claude-ichiba` and
`/reload-plugins`.

## What it does

1. **Shows the detected ecosystems.** A read-only script checks Konflux onboarding
   first: no `.tekton/` folder with Konflux markers, no setup. Then it
   lists the ecosystems (Maven, Gradle, Go, npm, Python, Rust, Ruby,
   container images, pre-commit, GitHub Actions), the default branch, the
   base images and how they are pinned, how workflows pin their actions,
   and frameworks worth keeping on manual review. You confirm or correct
   the list.
2. **Finds the Renovate config**, or asks where to create it. Existing
   custom rules are preserved. Two things an existing file may carry are
   removed with the reason: an `extends` of MintMaker's global config, and
   `baseBranchPatterns`, both applied by MintMaker itself.
3. **Sets the library rule.** How wide automerge goes for library
   ecosystems, which packages must never be automerged whatever the
   scope, which packages may have their majors automerged too, and
   whether indirect Go dependencies are included.
4. **Vets GitHub Actions.** Whether to pin actions to commit SHAs,
   which actions may automerge, and whether any of them may have its
   majors automerged too.
5. **Decides on base images.** Base image bumps tested by the Konflux
   build, and digest pinning.
6. **Decides on build toolchains.** The Maven and Gradle wrappers, the
   Go `toolchain` line and npm's `packageManager` are every developer's
   tools, not just CI's: kept manual unless you opt in.
7. **Sets the merge days.** Any day, or Monday to Thursday for a team
   that keeps Fridays and weekends quiet, or days you type; and whether
   pipeline updates follow those days or MintMaker's Saturday batch.
8. **Checks for overlap with other updaters.** Two bots on one ecosystem
   means two PRs for one bump. You choose whether a home-grown base-image
   workflow retires once Renovate covers base images, and whether to
   remove, narrow, or keep `dependabot.yml`. Stale Dependabot entries
   pointing at deleted directories are flagged on the way.
9. **Shows the summary table**, waits for your go, writes the config to
   your working tree, nothing committed or pushed yet, and shows the
   diff. Every name in the rules is compared with what the repo
   actually uses, because the validator cannot do that. Then it adds a CI
   workflow that validates the config on every change, with MintMaker's
   own validator action, unless the repo already has one.
10. **Walks you through the three GitHub settings**, one screen, each
   setting with a direct link to its page, where to look once there, and
   what the repository has today when `gh` is logged in: "Allow auto-merge", so
   GitHub does the merging and waits for the required checks alone; the
   required status checks, the gate, which you choose yourself after
   the guidance; and, only when the branch requires an approval, the
   Konflux app bypass of that rule and of nothing else. Each setting
   opens with a verdict, a green check when it is already in place, in
   which case its how-to is left out, or a warning naming what to change.
   They take the Admin role on the repository, and the screen says which
   role you have. You apply them in the GitHub UI and
   confirm once that you read them.
11. **Opens the PR**, with your confirmation before anything leaves your
    machine. The PR body records that you read and understood the three
    settings above and took on applying them, so a reviewer checks them
    before merging rather than trusting the plugin. Merging it turns
    automerge on. It closes with what to expect once it is live.

## The decisions you make

| Question | Options | Default suggestion |
|---|---|---|
| How wide does automerge go for library ecosystems? | Every patch and minor bump. Development dependencies only, where the manager distinguishes them. An allow-list of packages. Or decide per ecosystem. | Every patch and minor bump |
| Any packages that should never be automerged? | Packages that stay on manual review whatever the scope, such as a framework on an LTS track | The known candidates found in the repo: Quarkus, Spring Boot, Django and Angular today |
| Any packages whose major bumps may automerge too? | Packages you name, with your reason recorded in the config, such as a test library with good coverage | None; no candidates are proposed |
| Any actions whose major bumps may automerge too? | Allow-listed actions you name, with your reason recorded in the config | None; a major of an action often changes its inputs or runtime |
| Pin GitHub Actions to commit SHAs? | Yes: Renovate opens one PR per action to replace the tag with its SHA. No: the allow-list guards version bumps only | Yes when tag-pinned actions are found |
| Which actions are allowed to automerge? | The actions maintained by GitHub, the third-party ones, both, or a list you type | The GitHub-maintained ones |
| Automerge indirect Go dependencies? | Yes or keep them manual | Asked when `go.mod` is found |
| On which days may updates open and merge? | Any day, Monday to Thursday, or days you type; vulnerability fixes arrive any day either way | Any day |
| Pipeline updates on the same days, or on MintMaker's Saturday batch? | The merge days, or inherit the schedule | Asked |
| Automerge base image bumps? | Digest, patch and minor bumps of the `FROM` images, tested by the Konflux PR build. Majors stay manual | Yes, asked when a container file is found |
| Pin base images to digests? | Yes: one pin PR, then rebuilds of a tag arrive as digest PRs. No: tags only | Yes when an unpinned `FROM` line is found |
| Automerge build toolchain bumps? | Patch and minor bumps of the Maven or Gradle wrapper, the Go `toolchain` line and npm's `packageManager`, or keep them manual | Keep manual: rare updates, and a bad one breaks every local build |
| What happens to `dependabot.yml`? | Remove, narrow to what Renovate does not cover, or keep | Depends on the overlap found |
| The three GitHub settings | "Allow auto-merge", the required status checks, typically the build, the tests and the Konflux PR pipeline check, never a scanner or a check that skips some PRs, and the Konflux app bypass of the approval rule only | Your call, after the guidance; one acknowledgement that you read them and will apply them |

What never automerges, whatever you answer: digest-only updates of
GitHub Actions, Helm charts, Terraform, and any ecosystem without a rule.
Major version bumps stay on manual review too, except for the packages you
name.

## What you get

A `renovate.jsonc` that reads like this, with your ecosystems and your
names in it:

```jsonc
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  // This file only holds this repository's overrides. MintMaker runs
  // Renovate with its own global config and merges this file on top of it,
  // so the release-age delay, the vulnerability alerts, the enabled
  // managers and the tekton manager setup are inherited, not restated.
  // Global config: https://github.com/konflux-ci/mintmaker/blob/main/config/renovate/renovate.json
  "extends": [
    // Pins every GitHub Action to a commit SHA, so the rule below can tell
    // a version bump from a moved tag.
    "helpers:pinGitHubActionDigests"
  ],
  "tekton": {
    // Konflux pipeline updates in .tekton/. The PR's own Konflux build is
    // the test of the change, so its check must be required.
    "automerge": true,
    "schedule": ["at any time"]
  },
  "packageRules": [
    {
      "matchManagers": ["github-actions"],
      // Excludes digest-only updates, so a hijacked tag re-pointed to a
      // malicious commit with no version delta never gets automerged.
      "matchUpdateTypes": ["patch", "minor"],
      // Actions vetted for automerge. Add new ones deliberately.
      "matchDepNames": ["actions/checkout", "actions/setup-java"],
      "automerge": true
    },
    {
      "matchManagers": ["maven"],
      "matchUpdateTypes": ["patch", "minor"],
      "automerge": true
    },
    {
      // Quarkus follows an LTS track, so a reviewer picks the target version. https://quarkus.io/releases/
      "matchManagers": ["maven"],
      "matchPackageNames": ["io.quarkus*"],
      "automerge": false
    },
    {
      "matchManagers": ["maven-wrapper"],
      "automerge": false
    }
  ]
}
```

Alongside it: a `.github/workflows/renovate-config-validator.yml` that
runs MintMaker's validator whenever the config changes, and a PR whose
body records your acknowledgement of the branch-protection settings.

## How the safety adds up

Automerge is only as safe as the weakest of these, so the plugin sets or
explains every one of them.

| Layer | What it does | Who provides it |
|---|---|---|
| Release-age delay | No PR for a fresh release until MintMaker's delay has passed. Covers every update that has a publish date, automerged or not. | MintMaker's global config, inherited |
| Update-type filter | `patch` and `minor` qualify by default, plus `digest` for base images. Majors stay manual unless you name the package; action digests, pins and lock-file maintenance always do. | The generated rules |
| Allow-list for GitHub Actions | Each action is vetted by name, and only SHA-pinned actions can automerge safely. | The generated rules, plus SHA pinning |
| Manual-review list | Packages you name stay manual whatever the update type. | Your answers |
| Allow auto-merge | Lets Renovate hand the merge to GitHub, which waits for the required checks alone. Off, Renovate merges the PR itself on a later run and waits for every check on it, required or not, so one failing scan holds every automerge. | You, in the repository settings |
| Required status checks | GitHub's auto-merge waits for required checks only: a check that is not required can still be running, or failing, when the PR merges. | You, in the branch ruleset |
| Scoped bypass | The Konflux app skips the approval rule only, in "For pull requests only" mode. It still has to pass required checks. | You, in the branch ruleset |

Two exceptions to know. Vulnerability fix PRs skip the release-age delay,
so a patch or minor fix in an automerged ecosystem merges as soon as CI
passes. And the delay only applies to releases that have a publish date,
because MintMaker sets `minimumReleaseAgeBehaviour` to
`timestamp-optional`: Renovate only learns image publish dates from Docker
Hub, so a base image from `registry.access.redhat.com` or `quay.io`, and
the Konflux task bundles, get no delay at all.

What the plugin never does: change a GitHub setting through the API, push
or open a PR without your confirmation, fetch example configs from other
repositories, or set `minimumReleaseAge` in your file.

## Once it is live

- MintMaker runs every 4 hours. A PR opens on one run with GitHub's
  auto-merge armed, and GitHub merges it the moment the required checks
  pass. Without "Allow auto-merge", Renovate merges it itself on a later
  run, and only once every check on the PR is green.
- A fresh release shows up once the release-age delay has passed, with a
  passing `renovate/stability-days` check. Nothing lists the updates being
  held, since MintMaker disables Renovate's dependency dashboard.
- The PR body says `Automerge: Enabled` when the rules matched. When it
  is missing, the config did not match that update.
- The first PR from the Konflux app that merges with passing checks and no
  human approval confirms the bypass works.
- Majors of every package you did not name, the manual-review list,
  build toolchains unless you opted in, lock-file maintenance and ecosystems
  without a rule still arrive as ordinary PRs. That is the intended scope.

## Troubleshooting

| Symptom | Cause | What to do |
|---|---|---|
| `Automerge: Enabled` is missing from a PR that should qualify | The rules did not match the update: wrong package or action name, or an update type outside `patch` and `minor` | Compare the name in the rule with the one in the PR title. The validator does not catch a name that matches nothing. |
| A qualifying PR sits open with green required checks | "Allow auto-merge" is off, so Renovate merges the PR itself and waits for every check on it: a failing check that is not required, a vulnerability scan for instance, holds it | Turn on Settings › General › Allow auto-merge. The PR is armed on its next rebase and merges once the required checks pass. |
| A qualifying PR sits open with all checks green | The merge happens on a later MintMaker run, up to 4 hours after the checks passed, when "Allow auto-merge" is off | Wait for the next run, or turn on "Allow auto-merge" so GitHub merges as soon as the checks pass. |
| A PR merged with no approval | That is the bypass working as designed | Check that the bypass is scoped to the approval rule and set to "For pull requests only" |
| Human PRs are stuck on a pending required check | A required check that does not run on every PR, such as the config validator workflow or `renovate/stability-days` | Remove it from the required checks. Only require checks that run on every PR. |
| The validator workflow fails on the PR | A syntax or schema error in the config | Fix the file and push again. The workflow log names the line. |
| The check names in Step 10 don't match the PR | MintMaker has not opened a PR on this repository yet, so the names are derived from `.tekton/` | Verify the check names on the first MintMaker PR. The app to add to the bypass is always `Red Hat Konflux`, the GitHub App owned by `redhat-appstudio`. |

## Development

Run `claude plugin validate . --strict` before pushing. Commit messages
follow [Conventional Commits](https://www.conventionalcommits.org/): the
release workflow, shared with the rest of the marketplace, derives the next
version from them, and merging the standing release PR publishes to the
marketplace.

The plugin is one skill, `skills/setup/`: `SKILL.md` drives the
conversation, sets its style (one screen per step, every decision a menu,
a short note per step) and carries the config skeleton,
the per-ecosystem rule blocks, and the validator workflow inline,
`scripts/detect.sh` gathers the repository facts, its `cand` lines being
the packages proposed for manual review, each with its reason and link,
and `references/` holds the long-form reasoning and the GitHub steps.

## License

[Apache-2.0](LICENSE).

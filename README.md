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
you leave out, keeps waiting for a human, exactly as today.

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
- **Built on MintMaker's release-age delay.** MintMaker holds back any
  release younger than 3 days before opening a PR, which is the window in
  which compromised releases are usually caught and pulled. The plugin
  inherits that delay rather than restating it, so it never drifts.
- **GitHub Actions are allow-listed by name.** Actions run arbitrary code
  in CI, so each one is vetted individually, and only version bumps of
  SHA-pinned actions qualify. A moved tag never merges on its own.
- **Branch protection is treated as the gate, not as paperwork.** The
  plugin explains which status checks to require, how to let the Konflux
  app skip an approval rule and nothing else when the branch has one, and
  asks you to confirm the settings are in place before it opens the PR.
- **One readable file, no shared preset.** The generated config is small,
  commented line by line, and complete on its own. What merges unattended
  in a repository stays that repository's decision.

## Quick start

You need [Claude Code](https://claude.com/claude-code) and a
Konflux-onboarded repository, one with a `.tekton/` folder. A `gh` login
is handy, not required: with it the skill opens the PR itself, without it
Claude reaches GitHub another way, the REST API with a token if one is set,
or a link you open to create the PR yourself. Install from
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
trust decision before a byte is written. Expect about ten minutes and a dozen quick decisions. At the
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
   ecosystems, and which packages must never be automerged whatever the
   scope.
4. **Vets GitHub Actions.** Whether to pin actions to commit SHAs, and
   which actions may automerge.
5. **Decides on base images and build-tool wrappers.** Base image bumps
   tested by the Konflux build, digest pinning, and whether wrapper bumps
   merge on their own.
6. **Covers the Konflux pipeline and the extras.** Pipeline updates any
   day or on MintMaker's Saturday batch, packages whose majors may
   automerge too, indirect Go dependencies, grouped npm PRs.
7. **Checks for overlap with other updaters.** Two bots on one ecosystem
   means two PRs for one bump. You choose whether a home-grown base-image
   workflow retires once Renovate covers base images, and whether to
   remove, narrow, or keep `dependabot.yml`. Stale Dependabot entries
   pointing at deleted directories are flagged on the way.
8. **Shows the summary table**, waits for your go, writes the config to
   your working tree, nothing committed or pushed yet, and shows the
   diff. Every name in the rules is compared with what the repo
   actually uses, because the validator cannot do that. Then it adds a CI
   workflow that validates the config on every change, with MintMaker's
   own validator action, unless the repo already has one.
9. **Walks you through the branch protection**, with a short primer on
   rulesets, then one section per setting with the exact clicks: the
   required status checks, the gate that makes automerge safe, which you
   choose yourself after the guidance and confirm you will set; and, only
   when the branch requires an
   approval, the Konflux app bypass of that rule, per repository or once
   for the organization through an organization ruleset. You apply them
   in the GitHub UI and confirm each one.
10. **Opens the PR**, with your confirmation before anything leaves your
    machine. The PR body lists the settings above as a checklist. Merging
    it turns automerge on. It closes with what to expect once it is live.

## The decisions you make

| Question | Options | Default suggestion |
|---|---|---|
| How wide does automerge go for library ecosystems? | Every patch and minor bump. Development dependencies only, where the manager distinguishes them. An allow-list of packages. Or decide per ecosystem. | Every patch and minor bump |
| Any packages that should never be automerged? | Packages that stay on manual review whatever the scope, such as a framework on an LTS track | Frameworks found in the repo, such as Quarkus, Spring Boot, Django, Angular |
| Any packages whose major bumps may automerge too? | Packages you name, with your reason recorded in the config, such as a test library with good coverage | None; no candidates are proposed |
| Pin GitHub Actions to commit SHAs? | Yes: Renovate opens one PR per action to replace the tag with its SHA. No: the allow-list guards version bumps only | Yes when tag-pinned actions are found |
| Which actions are allowed to automerge? | The actions maintained by GitHub, the third-party ones, both, or a list you type | The GitHub-maintained ones |
| Automerge indirect Go dependencies? | Yes or keep them manual | Asked when `go.mod` is found |
| One PR per npm bump, or one grouped PR? | Independent PRs, or a group that only merges when every bump in it passes | Asked when `package.json` is found |
| Pipeline updates any day, or on MintMaker's Saturday batch? | `at any time`, or inherit the schedule | Asked |
| Automerge base image bumps? | Digest, patch and minor bumps of the `FROM` images, tested by the Konflux PR build. Majors stay manual | Yes, asked when a container file is found |
| Pin base images to digests? | Yes: one pin PR, then rebuilds of a tag arrive as digest PRs. No: tags only | Yes when an unpinned `FROM` line is found |
| Automerge build-tool wrapper bumps? | Patch and minor bumps of the Maven or Gradle wrapper, or keep them manual | Keep manual: rare updates, and a bad one breaks every local build |
| What happens to `dependabot.yml`? | Remove, narrow to what Renovate does not cover, or keep | Depends on the overlap found |
| Which status checks are required? | Your call, after the guidance: typically the build, the tests, the Konflux PR pipeline check, never a scanner or a check that skips some PRs | None proposed; you confirm you understood and will set them |

What never automerges, whatever you answer: digest-only updates of
GitHub Actions, Helm charts, Terraform, and any ecosystem without a rule.
Major version bumps wait for a human too, except for the packages you
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
      // Quarkus follows an LTS track, so a human picks the target version.
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
body records the branch-protection checklist.

## How the safety adds up

Automerge is only as safe as the weakest of these, so the plugin sets or
explains every one of them.

| Layer | What it does | Who provides it |
|---|---|---|
| Release-age delay | No PR for a release younger than 3 days. Covers every update, automerged or not. | MintMaker's global config, inherited |
| Update-type filter | `patch` and `minor` qualify by default, plus `digest` for base images. Majors stay manual unless you name the package; action digests, pins and lock-file maintenance always do. | The generated rules |
| Allow-list for GitHub Actions | Each action is vetted by name, and only SHA-pinned actions can automerge safely. | The generated rules, plus SHA pinning |
| Manual-review list | Packages you name stay manual whatever the update type. | Your answers |
| Required status checks | GitHub's auto-merge waits for required checks only. Without them, a PR can merge before CI even starts. | You, in the branch ruleset |
| Scoped bypass | The Konflux app skips the approval rule only, in "For pull requests only" mode. It still has to pass required checks. | You, in the branch ruleset |

Two exceptions to know. Vulnerability fix PRs skip the release-age delay,
so a patch or minor fix in an automerged ecosystem merges as soon as CI
passes. And the delay treats a release without a publish date as old
enough, because MintMaker sets `minimumReleaseAgeBehaviour` to
`timestamp-optional`.

What the plugin never does: change a GitHub setting through the API, push
or open a PR without your confirmation, fetch example configs from other
repositories, or set `minimumReleaseAge` in your file.

## Once it is live

- MintMaker runs every 4 hours. A PR opens on one run and merges on a
  later one, once CI passed and the branch is up to date. Hours, not
  minutes.
- A fresh release shows up at least 3 days after publication, with a
  passing `renovate/stability-days` check. Nothing lists the updates being
  held, since MintMaker disables Renovate's dependency dashboard.
- The PR body says `Automerge: Enabled` when the rules matched. When it
  is missing, the config did not match that update.
- The first PR from the Konflux app that merges with passing checks and no
  human approval confirms the bypass works.
- Majors of every package you did not name, the manual-review list,
  wrappers unless you opted in, lock-file maintenance and ecosystems
  without a rule still arrive as ordinary PRs. That is the intended scope.

## Troubleshooting

| Symptom | Cause | What to do |
|---|---|---|
| `Automerge: Enabled` is missing from a PR that should qualify | The rules did not match the update: wrong package or action name, or an update type outside `patch` and `minor` | Compare the name in the rule with the one in the PR title. The validator does not catch a name that matches nothing. |
| A qualifying PR sits open with green checks | The merge happens on a later MintMaker run, or "Allow auto-merge" is off and Renovate merges it itself | Wait for the next 4-hour run. Turn on "Allow auto-merge" for faster merges. |
| A PR merged with no approval | That is the bypass working as designed | Check that the bypass is scoped to the approval rule and set to "For pull requests only" |
| Human PRs are stuck on a pending required check | A required check that does not run on every PR, such as the config validator workflow or `renovate/stability-days` | Remove it from the required checks. Only require checks that run on every PR. |
| The validator workflow fails on the PR | A syntax or schema error in the config | Fix the file and push again. The workflow log names the line. |
| The skill finds no MintMaker PR to read the app name from | MintMaker has not opened a PR on this repository yet | The skill uses `app/red-hat-konflux` and the usual check names as placeholders. Verify them on the first MintMaker PR. |

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
`scripts/detect.sh` gathers the repository facts, and `references/` holds
the long-form reasoning and the GitHub steps.

## License

[Apache-2.0](LICENSE).

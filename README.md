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

Patch and minor bumps of the ecosystems you choose merge on their own once
CI passes. Major bumps, packages you carve out, build-tool wrappers, and
every ecosystem you leave out keep waiting for a human, exactly as today.

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
  app skip the approval rule and nothing else, and asks you to confirm the
  settings are in place before it opens the PR.
- **One readable file, no shared preset.** The generated config is small,
  commented line by line, and complete on its own. What merges unattended
  in a repository stays that repository's decision.

## Quick start

You need [Claude Code](https://claude.com/claude-code), a `gh` login, and a
Konflux-onboarded repository, one with a `.tekton/` folder. Install from
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

The skill opens with the plan and the questions it will ask, so you know
what is coming. Expect ten short steps and about as many decisions. At the
end you have a reviewed config file on a branch, an open PR, and the
GitHub settings in place.

Claude Code only auto-updates plugins from its official marketplace.
Enable auto-update for claude-ichiba in the `/plugin` panel, or refresh it
yourself with `/plugin marketplace update claude-ichiba` and
`/reload-plugins`.

## What it does

1. **Checks Konflux onboarding.** A read-only script lists tracked files
   and greps a few of them. No `.tekton/` folder with Konflux markers, no
   setup.
2. **Detects the repository.** Ecosystems (Maven, Gradle, Go, npm, Python,
   Rust, Ruby, container images, pre-commit, GitHub Actions), how workflows
   pin their actions, the default branch. You confirm or correct the list.
3. **Finds the Renovate config**, or asks where to create it. Existing
   custom rules are preserved. Two things an existing file may carry are
   removed with the reason: an `extends` of MintMaker's global config, and
   `baseBranchPatterns`, both applied by MintMaker itself.
4. **Proposes the automerge rules**, ecosystem by ecosystem, and asks the
   questions listed in the next section.
5. **Checks for Dependabot overlap.** Two bots on one ecosystem means two
   PRs for one bump. You choose to remove, narrow, or keep `dependabot.yml`.
   Stale entries pointing at deleted directories are flagged on the way.
6. **Shows the summary table**, waits for your go, writes the config, and
   shows the diff. Every name in the rules is compared with what the repo
   actually uses, because the validator cannot do that.
7. **Adds a CI workflow** that validates the config on every change, with
   MintMaker's own validator action, unless the repo already has one.
8. **Walks you through the GitHub settings**: required status checks, the
   Konflux app bypass, "Allow auto-merge". You apply them in the GitHub UI
   and confirm each one.
9. **Opens the PR**, with your confirmation before anything leaves your
   machine. The PR body lists the settings above as a checklist. Merging
   it turns automerge on.
10. **Tells you what to expect** once it is live.

## The decisions you make

| Question | Options | Default suggestion |
|---|---|---|
| How wide does automerge go, per library ecosystem? | Every patch and minor bump. Development dependencies only, where the manager distinguishes them. An allow-list of packages. | Asked per ecosystem, no default |
| Which packages stay on manual review? | Any package whose upgrades follow a policy Renovate cannot know, such as a framework on an LTS track | Quarkus is the running example for Maven |
| Pin GitHub Actions to commit SHAs? | Yes: Renovate opens one PR per action to replace the tag with its SHA. No: the allow-list guards version bumps only | Yes when tag-pinned actions are found |
| Which actions are allowed to automerge? | Any subset of the actions found in the workflows | The list found, for you to prune |
| Automerge indirect Go dependencies? | Yes or keep them manual | Asked when `go.mod` is found |
| One PR per npm bump, or one grouped PR? | Independent PRs, or a group that only merges when every bump in it passes | Asked when `package.json` is found |
| Pipeline updates any day, or on MintMaker's Saturday batch? | `at any time`, or inherit the schedule | Asked |
| What happens to `dependabot.yml`? | Remove, narrow to what Renovate does not cover, or keep | Depends on the overlap found |
| Which status checks are required? | Your build and test workflows, the Konflux PR pipeline check | Candidates read from the last MintMaker PR |

What never automerges, whatever you answer: major version bumps, Maven and
Gradle wrapper bumps, container base images, digest-only updates of GitHub
Actions, Helm charts, Terraform, and any ecosystem without a rule.

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
| Update-type filter | Only `patch` and `minor` qualify. Majors, digests, pins and lock-file maintenance stay manual. | The generated rules |
| Allow-list for GitHub Actions | Each action is vetted by name, and only SHA-pinned actions can automerge safely. | The generated rules, plus SHA pinning |
| Carve-outs | Packages you name stay manual whatever the update type. | Your answers |
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
- Majors, carve-outs, wrappers, lock-file maintenance and ecosystems
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
conversation and carries the config skeleton, the per-ecosystem rule
blocks, and the validator workflow inline, `scripts/detect.sh` gathers the
repository facts, and `references/` holds the long-form reasoning and the
GitHub steps.

## License

[Apache-2.0](LICENSE).

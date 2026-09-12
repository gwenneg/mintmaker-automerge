# Walkthrough evals

`claude plugin eval` runs a single prompt in a headless session that has no
`AskUserQuestion` tool, so it cannot get past the first menu of the setup
skill. These evals drive the skill through the
[Agent SDK](https://code.claude.com/docs/en/agent-sdk/user-input) instead:
every menu reaches the `canUseTool` callback, and a scripted user answers
it. The skill runs exactly as it does for a person, same model, same tools,
same detect script; only the person is replaced.

Each directory under `fixtures/` is a small Konflux-onboarded repository
with an `expect.json` next to it. The driver copies the fixture to a temp
directory, commits it, runs `/mintmaker-automerge:setup` there, picks the
`(Recommended)` option of every menu, answers `Stop here` at Step 10 so
nothing is committed or pushed, then checks:

- the welcome screen comes first, the ten step headers come in order, and
  every menu is preceded by the screen of its step, with no transition line
  after an answer;
- the menus come in the expected sequence, with the expected questions
  grouped per call;
- nothing is written before the "Write it" answer, and the summary table
  is printed before it;
- the expected files were written or removed, the config parses as JSONC,
  contains the expected rules, and carries no leftover placeholder;
- the validator workflow was added, and the tree is left uncommitted.

| Fixture | Exercises |
|---|---|
| `java` | Maven with Quarkus (manual-review candidate), Maven wrapper, tag-only base images, tag-pinned actions, no Renovate config, Dependabot overlap removed in Step 7 |
| `go` | Go modules with indirect deps, digest-pinned base images, SHA-pinned actions, strict `renovate.json` migrated and renamed, MintMaker `extends` and `baseBranchPatterns` dropped, custom rule preserved |
| `python` | pyproject and requirements with Django, no container file or wrapper (Step 5 skipped), path-filtered PR pipeline, existing `renovate.jsonc` kept in place, unknown default branch |
| `not-konflux` | No `.tekton/`: the skill prints the stop message and asks nothing |
| `gradle-npm` | Gradle with Spring Boot and a wrapper, npm with Angular, a `latest` base image, a reusable workflow and a bare-SHA action, a validator workflow already present, config placed under `.github/`, scope decided per ecosystem through follow-up menus, wrapper automerge opted in, grouped npm PRs, "Commit on a branch" at Step 10 |
| `rust-preset` | Cargo, no GitHub workflows (Step 4 skipped), `.github/renovate.json5` with a shared preset fetched from GitHub, `minimumReleaseAge` and `enabledManagers` removed, typed answers naming a never-automerge package and packages whose majors may merge with their reason, base images kept manual, Saturday batch kept |
| `ruby-updaters` | Bundler and Terraform, `renovate.json` kept strict on request, actions left unpinned with the full allow-list, a base-image bump workflow removed, Dependabot narrowed with a stale entry flagged, "help me understand" on the checks question answered once |

The answers each fixture gives, and the checks on the result, are in its
`expect.json`; the format is documented at the top of `run.mjs`.

## Run

```
cd evals
npm ci
node run.mjs            # all fixtures, in parallel
node run.mjs go --keep  # one fixture, keep its temp repo for a look
```

The CLI the SDK spawns needs a credential: your `claude` login, or
`CLAUDE_CODE_OAUTH_TOKEN` from `claude setup-token`, or `ANTHROPIC_API_KEY`.
A full run of one fixture is about twenty turns on Sonnet. Transcripts,
logs, and the generated configs land in `results/<timestamp>-<pid>/`.
Set `PLUGIN_DIR` to another checkout of the plugin to run the fixtures
against it, for an A/B between two versions.

The model is not deterministic, so a failure is a transcript to read, not
always a bug: the `.log` file shows what was printed and answered at each
step, and the `.jsonl` file has every message.

## CI

`.github/workflows/evals.yml` runs the fixtures on GitHub Actions, on a
manual trigger, with an optional list of fixtures, using the
`CLAUDE_CODE_OAUTH_TOKEN` repository secret minted by `claude setup-token`.
The job skips itself when the secret is absent. The transcripts are
uploaded as a workflow artifact. The model is not deterministic, so the
trigger stays manual until a few runs come out green; then a
`pull_request` trigger on `skills/**` and `evals/**` makes sense, keeping
in mind that fork pull requests get no secret and skip the job.

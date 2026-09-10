# Ecosystem markers

`scripts/detect.sh` reports each Renovate manager it found from these
markers. Read this file only when the report is missing or looks incomplete
for the repo, and do the detection by hand from tracked files, never with a
filesystem walk: `find` picks up `node_modules/`, `target/` and vendored
directories.

| Ecosystem | Renovate manager | Detect via |
|---|---|---|
| Maven | `maven` | `pom.xml` |
| Maven wrapper | `maven-wrapper` | `.mvn/wrapper/`, `mvnw` |
| Gradle | `gradle` | `build.gradle`, `build.gradle.kts` |
| Gradle wrapper | `gradle-wrapper` | `gradle/wrapper/gradle-wrapper.properties` |
| Go modules | `gomod` | `go.mod` |
| npm/Node.js | `npm` | `package.json` |
| Python (requirements) | `pip_requirements` | `requirements*.txt` |
| Python (setup.py) | `pip_setup` | `setup.py` |
| Python (Pipenv) | `pipenv` | `Pipfile` |
| Python (Poetry) | `poetry` | `pyproject.toml` with a `[tool.poetry]` section |
| Python (PEP 621) | `pep621` | `pyproject.toml` without `[tool.poetry]` |
| Rust | `cargo` | `Cargo.toml` |
| Ruby | `bundler` | `Gemfile` |
| Container images | `dockerfile` | `Dockerfile`, `Containerfile`, variants such as `Dockerfile.ci` |
| pre-commit hooks | `pre-commit` | `.pre-commit-config.yaml` |
| GitHub Actions | `github-actions` | `.github/workflows/*.yml` and `*.yaml`, plus `action.yml` files under `.github/actions/` |
| Helm charts | `helmv3` | `Chart.yaml` |
| Terraform | `terraform` | `*.tf` |

`pyproject.toml` needs its contents checked, not just its existence, to
pick `poetry` vs `pep621` correctly: a repo can have `pyproject.toml` for
either tool, and they are different managers.

Yarn and pnpm get no row of their own: Renovate's `npm` manager covers
`package-lock.json`, `yarn.lock` and `pnpm-lock.yaml` under the single
`npm` slug, so `package.json` is enough whatever the lockfile.

MintMaker enables more managers than this table; the full list is the
`enabledManagers` array of its global config. Helm and Terraform are in the
table so the report names them, but the skill has no automerge block for
them.

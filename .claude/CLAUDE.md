# Working in this repository

## Commits

- Every commit is signed. The `main` branch requires signatures, so an unsigned commit cannot be merged. Signing is on in the git config; never turn it off with `--no-gpg-sign` or `-c commit.gpgsign=false`, and if signing fails, stop and report it rather than commit unsigned.
- Before pushing, check the signature of every new commit and fix an `N` by amending or rebasing:

  ```
  git log --format='%h %G? %s' origin/main..HEAD
  ```

  `G` is a good signature. Anything else means the commit needs signing again.
- Messages follow Conventional Commits: the release workflow derives the version from them.
- Branch from `main` for every change and open a pull request; nothing is pushed to `main` directly, and history stays linear.

## Before a pull request

- `claude plugin validate . --strict` passes.
- The walkthrough evals in `evals/` are the acceptance test for skill changes: run them, or trigger `evals.yml` on the branch, and read the transcript of any red fixture before touching the skill again.

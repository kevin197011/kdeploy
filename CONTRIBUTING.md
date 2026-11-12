# Contributing

Thanks for considering a contribution.

## Setup

```bash
git clone git@github.com:kevin197011/kdeploy.git
cd kdeploy
bundle install
bundle exec rspec
bundle exec rubocop
```

Optional multi-host lab:

```bash
cd docker/lab
docker compose up -d --build
docker compose --profile test up --build runner
```

## Pull requests

1. Use a feature branch.
2. Keep diffs focused; follow existing style (`frozen_string_literal`, RuboCop).
3. Add or update RSpec for behavior changes.
4. Use [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, …).
5. Do **not** run `rake push` / `push.rb` unless you are a maintainer releasing — the default Rake task is `spec`.
   Maintainer `rake push` requires a **clean** worktree, runs RuboCop `-A` + RSpec, patch-bumps `version.rb` (+ syncs `Gemfile.lock`), commits those tracked changes, then `pull --rebase` / `push`.

## Scope

Please keep changes aligned with [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md) non-goals
(no agent, no Chef-style convergence engine, no Web UI).

## Ruby / Bundler notes

On Homebrew Ruby 4.x, `bundle exec` may print noisy `Gem::Platform::* already initialized` warnings; they are bundler/Ruby noise and do not fail the build. CI uses Ruby 3.1–3.3.

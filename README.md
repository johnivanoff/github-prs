# GitHub Checks

Check open pull requests across multiple GitHub repos from the terminal.

## Requirements

- Ruby
- Bundler (`gem install bundler`)
- A GitHub personal access token with `repo` scope

## Setup

1. Install dependencies:

   ```bash
   bundle install
   ```

2. Copy `.env.example` to `.env` and add your GitHub token:

   ```
   GITHUB_TOKEN=your_token_here
   ```

   This token is used for GitHub API requests for both PR and Dependabot checks.

3. Copy `repos.yml.example` to `repos.yml` and add the repos you want to track, or run `sync` to populate it automatically.

   `sync` fetches every repo your account can access and rewrites `repos.yml` with the current list.

   Important: `.env` and `repos.yml` are local-only files. Do not commit them to a public repository.

## Token Safety

- Keep your GitHub token in `.env` only on your local machine; never commit it to Git or share it in screenshots, issues, or logs.
- Use the minimum token scope needed for the task. This project requires the `repo` scope for GitHub API access.
- Rotate the token regularly, revoke old tokens, and replace it immediately if it is exposed or suspected to be compromised.

## Usage

```bash
bundle exec ruby main.rb prs        # check open PRs for all repos in repos.yml
bundle exec ruby main.rb dependabot # check open Dependabot alerts for repos in repos.yml
bundle exec ruby main.rb sync       # fetch all accessible repos and update repos.yml
bundle exec ruby main.rb validate   # validate repos.yml structure and entries
bundle exec ruby main.rb validate --json
bundle exec ruby main.rb schedule --interval 300
bundle exec ruby main.rb            # show help
```

If a repo does not have Dependabot enabled, or the GitHub token cannot access it, the command will report that instead of failing outright.

## Configuration

Create a local `repos.yml` from the example file and add the repos you want to track:

```yaml
repos:
  - owner: example-user
    repo: demo-app
  - owner: some-org
    repo: another-demo-repo
```

You can edit this file manually or use `sync` to regenerate it from your GitHub account. The file is expected to contain a YAML list under the `repos` key.

For public repos, keep this file local and populated only with example repos or repos you are comfortable exposing.

## Repository Hygiene

If this project is hosted on GitHub, use the repository settings below to reduce risk:

- Protect the `main` branch and require a pull request before merges.
- Require at least one approving review before merging changes.
- Disable direct pushes to protected branches unless explicitly needed.
- Restrict GitHub Actions permissions to the minimum required.
- Avoid storing credentials in repo secrets unless absolutely necessary; prefer local environment variables for developer machines.
- Keep CI focused on validation, dependency checks, and security scans only.

## Local Development and Release

### Run locally

1. Install Ruby dependencies:

   ```bash
   bundle install
   ```

2. Create a local `.env` from `.env.example` and add your token.
3. Create a local `repos.yml` from `repos.yml.example` and add the repos you want to inspect.
4. Run a command:

   ```bash
   bundle exec ruby main.rb prs
   bundle exec ruby main.rb dependabot
   bundle exec ruby main.rb sync
   ```

### Publish safely

1. Make sure `.env` and `repos.yml` are not tracked by Git.
2. Keep only example or non-sensitive data in the public repo.
3. Review the repo for tokens, private usernames, or internal project names before pushing.
4. Protect the default branch and require review before merging.
5. Publish the repo only after the local secret files and private repo metadata have been removed.

This keeps the project usable for contributors while preventing accidental credential or repo leakage in a public repository.

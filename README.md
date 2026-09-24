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

## Usage

```bash
bundle exec ruby main.rb prs        # check open PRs for all repos in repos.yml
bundle exec ruby main.rb dependabot # check open Dependabot alerts for repos in repos.yml
bundle exec ruby main.rb sync       # fetch all accessible repos and update repos.yml
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

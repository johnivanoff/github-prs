require 'net/http'
require 'json'
require 'uri'
require 'yaml'
require 'dotenv'
Dotenv.load(File.join(__dir__, '.env'))

def abort_on_bad_credentials(data)
  abort 'GitHub API error: Bad credentials' if data.is_a?(Hash) && data['message'] == 'Bad credentials'
end

def fetch_repo_info(owner, repo)
  uri = URI("https://api.github.com/repos/#{owner}/#{repo}")
  req = Net::HTTP::Get.new(uri)
  req['Accept']     = 'application/vnd.github+json'
  req['User-Agent'] = 'ruby-github-client'
  req['Authorization'] = "Bearer #{ENV['GITHUB_TOKEN']}" if ENV['GITHUB_TOKEN']

  res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }
  data = JSON.parse(res.body)
  abort_on_bad_credentials(data)
  data
end

def fetch_open_prs(owner, repo)
  uri = URI("https://api.github.com/repos/#{owner}/#{repo}/pulls?state=open")
  req = Net::HTTP::Get.new(uri)
  req['Accept']     = 'application/vnd.github+json'
  req['User-Agent'] = 'ruby-github-client'
  req['Authorization'] = "Bearer #{ENV['GITHUB_TOKEN']}" if ENV['GITHUB_TOKEN']

  res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }
  data = JSON.parse(res.body)
  abort_on_bad_credentials(data)
  data
end

def fetch_all_repos
  repos = []
  page  = 1

  loop do
    uri = URI("https://api.github.com/user/repos?per_page=100&page=#{page}&sort=full_name")
    req = Net::HTTP::Get.new(uri)
    req['Accept']        = 'application/vnd.github+json'
    req['User-Agent']    = 'ruby-github-client'
    req['Authorization'] = "Bearer #{ENV['GITHUB_TOKEN']}"

    res  = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }
    data = JSON.parse(res.body)

    abort "GitHub API error: #{data['message']}" if data.is_a?(Hash) && data['message']
    break if data.empty?

    repos.concat(data)
    page += 1
  end

  repos
end

def load_repos_config
  path = File.join(__dir__, 'repos.yml')
  unless File.exist?(path)
    abort "repos.yml not found. Run `bundle exec ruby main.rb sync` to generate it."
  end

  raw = File.read(path)
  if raw.match?(/!ruby\b|!python\b|!!ruby|!!python/)
    abort 'repos.yml contains disallowed YAML tags. Use plain YAML only.'
  end

  config = YAML.safe_load(raw, aliases: false) || {}
  unless config.is_a?(Hash) && config['repos'].is_a?(Array)
    abort 'repos.yml must contain a top-level "repos" array.'
  end

  config['repos'].each do |entry|
    unless entry.is_a?(Hash) && entry['owner'] && entry['repo']
      abort 'Each repo entry must include "owner" and "repo" strings.'
    end
  end

  config
end

def cmd_prs
  config = load_repos_config

  config['repos'].each do |entry|
    owner = entry['owner']
    repo  = entry['repo']

    info     = fetch_repo_info(owner, repo)
    archived = info['archived'] ? ' [ARCHIVED]' : ''
    # puts "=== #{owner}/#{repo}#{archived} ==="
    prs = fetch_open_prs(owner, repo)

    if prs.is_a?(Hash) && prs['message']
      puts "=== #{owner}/#{repo}#{archived} ==="
      puts "  Error: #{prs['message']}"
    elsif prs.empty?
      # puts '  No open PRs found.'
    else
     puts "=== #{owner}/#{repo}#{archived} ==="
      prs.each do |pr|
        puts "  ##{pr['number']} - #{pr['title']}"
        puts "    Author : #{pr['user']['login']}"
        puts "    Branch : #{pr['head']['ref']} -> #{pr['base']['ref']}"
        puts "    URL    : #{pr['html_url']}"
        puts
      end
    end
    # puts
  end
end

def fetch_dependabot_alerts(owner, repo)
  uri = URI("https://api.github.com/repos/#{owner}/#{repo}/dependabot/alerts?state=open&per_page=100")
  req = Net::HTTP::Get.new(uri)
  req['Accept']        = 'application/vnd.github+json'
  req['User-Agent']    = 'ruby-github-client'
  req['Authorization'] = "Bearer #{ENV['GITHUB_TOKEN']}" if ENV['GITHUB_TOKEN']

  res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }
  data = JSON.parse(res.body)
  abort_on_bad_credentials(data)
  { code: res.code, body: data }
end

def cmd_dependabot
  config = load_repos_config
  grouped = {
    errors: Hash.new { |errors, message| errors[message] = [] },
    not_enabled: [],
    no_open_alerts: []
  }

  config['repos'].each do |entry|
    owner = entry['owner']
    repo  = entry['repo']
    repo_name = "#{owner}/#{repo}"

    result = fetch_dependabot_alerts(owner, repo)
    alerts = result[:body]

    if alerts.is_a?(Hash) && alerts['message']
      if result[:code] == '404' || alerts['message'].downcase.include?('not enabled')
        grouped[:not_enabled] << repo_name
      else
        grouped[:errors][alerts['message']] << repo_name
      end
    elsif alerts.empty?
      grouped[:no_open_alerts] << repo_name
    else
      puts "=== #{repo_name} ==="
      alerts.each do |alert|
        pkg      = alert.dig('dependency', 'package', 'name')
        severity = alert.dig('security_vulnerability', 'severity') || 'unknown'
        summary  = alert.dig('security_advisory', 'summary') || 'N/A'
        puts "  [#{severity.upcase}] #{pkg} - #{summary}"
        puts "    URL: #{alert['html_url']}"
        puts
      end
      puts
    end
  end

  unless grouped[:errors].empty?
    puts '=== Errors ==='
    grouped[:errors].each do |message, repos|
      puts "  #{message}"
      repos.each { |repo| puts "    #{repo}" }
    end
    puts
  end

  {
    'Dependabot not enabled' => grouped[:not_enabled],
    'No open Dependabot alerts' => grouped[:no_open_alerts]
  }.each do |heading, repos|
    next if repos.empty?

    puts "=== #{heading} ==="
    repos.each { |repo| puts "  #{repo}" }
    puts
  end
end

def cmd_sync
  abort 'GITHUB_TOKEN is not set. Add it to your .env file.' unless ENV['GITHUB_TOKEN']

  puts 'Fetching repos you have access to...'
  repos = fetch_all_repos
  puts "Found #{repos.size} repos. Writing to repos.yml...\n\n"

  yaml_data = {
    'repos' => repos.map do |r|
      owner, repo = r['full_name'].split('/')
      puts "  #{r['full_name']}#{r['private'] ? ' (private)' : ''}"
      { 'owner' => owner, 'repo' => repo }
    end
  }

  File.write(File.join(__dir__, 'repos.yml'), YAML.dump(yaml_data))
  puts "\nrepos.yml updated."
end

command = ARGV[0]

case command
when 'prs'
  cmd_prs
when 'sync'
  cmd_sync
when 'dependabot'
  cmd_dependabot
else
  puts "Usage: bundle exec ruby main.rb <command>"
  puts ""
  puts "Commands:"
  puts "  prs        Check open PRs for repos in repos.yml"
  puts "  dependabot Check open Dependabot alerts for repos in repos.yml"
  puts "  sync       Fetch all accessible repos and update repos.yml"
  exit 1
end

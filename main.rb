require 'net/http'
require 'json'
require 'uri'
require 'yaml'
require 'dotenv/load'

def fetch_open_prs(owner, repo)
  uri = URI("https://api.github.com/repos/#{owner}/#{repo}/pulls?state=open")
  req = Net::HTTP::Get.new(uri)
  req['Accept']     = 'application/vnd.github+json'
  req['User-Agent'] = 'ruby-github-client'
  req['Authorization'] = "Bearer #{ENV['GITHUB_TOKEN']}" if ENV['GITHUB_TOKEN']

  res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }
  JSON.parse(res.body)
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

def cmd_prs
  config = YAML.load_file('repos.yml')

  config['repos'].each do |entry|
    owner = entry['owner']
    repo  = entry['repo']

    puts "=== #{owner}/#{repo} ==="
    prs = fetch_open_prs(owner, repo)

    if prs.is_a?(Hash) && prs['message']
      puts "  Error: #{prs['message']}"
    elsif prs.empty?
      puts '  No open PRs found.'
    else
      prs.each do |pr|
        puts "  ##{pr['number']} - #{pr['title']}"
        puts "    Author : #{pr['user']['login']}"
        puts "    Branch : #{pr['head']['ref']} -> #{pr['base']['ref']}"
        puts "    URL    : #{pr['html_url']}"
        puts
      end
    end
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

  File.write('repos.yml', YAML.dump(yaml_data))
  puts "\nrepos.yml updated."
end

command = ARGV[0]

case command
when 'prs'
  cmd_prs
when 'sync'
  cmd_sync
else
  puts "Usage: bundle exec ruby main.rb <command>"
  puts ""
  puts "Commands:"
  puts "  prs   Check open PRs for repos in repos.yml"
  puts "  sync  Fetch all accessible repos and update repos.yml"
  exit 1
end

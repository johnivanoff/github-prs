require 'net/http'
require 'json'
require 'uri'
require 'yaml'
require 'dotenv/load'

config = YAML.load_file('repos.yml')
repos  = config['repos']

def fetch_open_prs(owner, repo)
  uri = URI("https://api.github.com/repos/#{owner}/#{repo}/pulls?state=open")
  req = Net::HTTP::Get.new(uri)
  req['Accept']     = 'application/vnd.github+json'
  req['User-Agent'] = 'ruby-github-client'
  req['Authorization'] = "Bearer #{ENV['GITHUB_TOKEN']}" if ENV['GITHUB_TOKEN']

  res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }
  JSON.parse(res.body)
end

repos.each do |entry|
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

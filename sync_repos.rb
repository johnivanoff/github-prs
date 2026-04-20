require 'net/http'
require 'json'
require 'uri'
require 'yaml'
require 'dotenv/load'

abort 'GITHUB_TOKEN is not set. Add it to your .env file.' unless ENV['GITHUB_TOKEN']

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

    if data.is_a?(Hash) && data['message']
      abort "GitHub API error: #{data['message']}"
    end

    break if data.empty?

    repos.concat(data)
    page += 1
  end

  repos
end

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

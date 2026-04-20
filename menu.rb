puts "What would you like to do?"
puts "  1. Update repos list (sync_repos.rb)"
puts "  2. Check open PRs (open_prs.rb)"
print "\nEnter 1 or 2: "

choice = gets.chomp

case choice
when '1'
  puts "\nRunning sync_repos.rb...\n\n"
  load File.join(__dir__, 'sync_repos.rb')
when '2'
  puts "\nRunning open_prs.rb...\n\n"
  load File.join(__dir__, 'open_prs.rb')
else
  abort "Invalid choice: #{choice}"
end

require_relative 'test_helper'

class MainTest < Minitest::Test
  def test_load_repos_config_accepts_valid_yaml
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'repos.yml')
      File.write(path, <<~YAML)
        ---
        repos:
          - owner: example-user
            repo: demo-app
          - owner: some-org
            repo: another-demo-repo
      YAML

      assert_equal(
        { 'repos' => [{ 'owner' => 'example-user', 'repo' => 'demo-app' }, { 'owner' => 'some-org', 'repo' => 'another-demo-repo' }] },
        load_repos_config(path)
      )
    end
  end

  def test_load_repos_config_rejects_unsafe_yaml
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'repos.yml')
      File.write(path, "---\n!ruby/object:Kernel {}\n")

      error = assert_raises(SystemExit) do
        load_repos_config(path)
      end

      assert_match(/disallowed YAML tags/, error.message)
    end
  end

  def test_retry_delay_for_rate_limit_uses_reset_header
    response = Object.new
    response.define_singleton_method(:[]) do |key|
      case key
      when 'x-ratelimit-reset'
        (Time.now.to_i + 60).to_s
      when 'x-ratelimit-remaining'
        '0'
      else
        nil
      end
    end

    delay = retry_delay_for(response)
    assert_operator delay, :>=, 1
    assert_operator delay, :<=, 60
  end

  def test_logger_emits_valid_json_event
    stdout = StringIO.new
    old_stdout = $stdout
    $stdout = stdout

    begin
      GitHubChecks.log('dependabot_no_alerts', { 'repo' => 'example/demo' })
    ensure
      $stdout = old_stdout
    end

    json = JSON.parse(stdout.string)
    assert_equal 'dependabot_no_alerts', json['event']
    assert_kind_of String, json['timestamp']
    assert_equal 'example/demo', json['payload']['repo']
  end

  def test_validate_command_reports_valid_config
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'repos.yml')
      File.write(path, <<~YAML)
        ---
        repos:
          - owner: example-user
            repo: demo-app
          - owner: some-org
            repo: another-demo-repo
      YAML

      stdout = StringIO.new
      old_stdout = $stdout
      $stdout = stdout

      begin
        summary = cmd_validate(path, format: 'json')
      ensure
        $stdout = old_stdout
      end

      parsed = JSON.parse(stdout.string)
      assert_equal true, parsed['valid']
      assert_equal 2, parsed['repo_count']
      assert_equal ['example-user/demo-app', 'some-org/another-demo-repo'], parsed['repos']
      assert_equal summary['repo_count'], parsed['repo_count']
    end
  end

  def test_schedule_wrapper_validates_before_running
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'repos.yml')
      File.write(path, <<~YAML)
        ---
        repos:
          - owner: example-user
            repo: demo-app
      YAML

      stdout = StringIO.new
      old_stdout = $stdout
      $stdout = stdout

      begin
        called = 0
        cmd_schedule(path, interval_seconds: 0, max_iterations: 1, runner: lambda do
          called += 1
          puts 'runner-executed'
        end)
      ensure
        $stdout = old_stdout
      end

      assert_equal 1, called
      assert_match(/Configuration is valid\./, stdout.string)
      assert_match(/runner-executed/, stdout.string)
    end
  end
end

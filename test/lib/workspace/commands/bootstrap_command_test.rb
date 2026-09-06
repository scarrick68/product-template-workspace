# frozen_string_literal: true

require_relative "../../../test_helper"

class BootstrapCommandSmokeTest < Minitest::Test
  def test_runs_typed_bootstraps_in_expected_order
    Dir.mktmpdir("workspace-bootstrap") do |root_dir|
      backend_dir = File.join(root_dir, "backend")
      frontend_dir = File.join(root_dir, "frontend")
      dsml_dir = File.join(root_dir, "dsml")

      FileUtils.mkdir_p(File.join(backend_dir, "bin"))
      File.write(File.join(backend_dir, "Gemfile"), "source 'https://rubygems.org'\n")
      File.write(File.join(backend_dir, "package.json"), "{}")
      FileUtils.mkdir_p(File.join(backend_dir, "config"))
      File.write(File.join(backend_dir, "config", "database.yml"), "test: {}\n")
      File.write(File.join(backend_dir, "bin", "rails"), "#!/usr/bin/env ruby\n")
      File.write(File.join(backend_dir, "bin", "bootstrap"), "#!/usr/bin/env bash\n")
      FileUtils.chmod("u+x", File.join(backend_dir, "bin", "rails"))
      FileUtils.chmod("u+x", File.join(backend_dir, "bin", "bootstrap"))
      FileUtils.mkdir_p(File.join(backend_dir, "lib", "tasks"))
      File.write(File.join(backend_dir, "lib", "tasks", "blazer_default_queries.rake"), "task :noop do\nend\n")
      File.write(File.join(backend_dir, "lib", "tasks", "blazer_dashboards.rake"), "task :noop2 do\nend\n")

      FileUtils.mkdir_p(File.join(frontend_dir, "bin"))
      File.write(File.join(frontend_dir, "Gemfile"), "source 'https://rubygems.org'\n")
      File.write(File.join(frontend_dir, "package.json"), "{}")
      File.write(File.join(frontend_dir, "bin", "bootstrap"), "#!/usr/bin/env bash\n")
      FileUtils.chmod("u+x", File.join(frontend_dir, "bin", "bootstrap"))

      FileUtils.mkdir_p(File.join(dsml_dir, "bin"))
      File.write(File.join(dsml_dir, "bin", "bootstrap"), "#!/usr/bin/env bash\n")
      FileUtils.chmod("u+x", File.join(dsml_dir, "bin", "bootstrap"))

      backend_repo = { "purpose" => "backend-api", "name" => "api-template", "path" => backend_dir }
      frontend_repo = { "purpose" => "frontend-web-client", "name" => "web-template", "path" => frontend_dir }
      dsml_repo = { "purpose" => "data-science-ml", "name" => "dsml-template", "path" => dsml_dir }
      repos = [dsml_repo, frontend_repo, backend_repo]

      Workspace.stubs(:repositories).returns(repos)
      Workspace.stubs(:existing_repositories).returns(repos)
      Workspace.stubs(:repo_name).with(backend_repo).returns("api-template")
      Workspace.stubs(:repo_name).with(frontend_repo).returns("web-template")
      Workspace.stubs(:repo_name).with(dsml_repo).returns("dsml-template")
      Workspace.stubs(:repo_path).with(backend_repo, context: kind_of(Workspace::Context)).returns(backend_dir)
      Workspace.stubs(:repo_path).with(frontend_repo, context: kind_of(Workspace::Context)).returns(frontend_dir)
      Workspace.stubs(:repo_path).with(dsml_repo, context: kind_of(Workspace::Context)).returns(dsml_dir)
      Workspace.stubs(:ok)
      Workspace.stubs(:warn)
      Workspace.stubs(:info)
      Workspace.stubs(:fail_with_help)
      Workspace.stubs(:abort_with_help).raises("abort_with_help called unexpectedly")
      Workspace.stubs(:script_path).returns("bin/preinstall_checks")

      order = sequence("typed-bootstrap-order")
      Workspace.expects(:run).with("bin/bootstrap", has_entries(chdir: backend_dir, allow_failure: true)).in_sequence(order).returns(true)
      Workspace.expects(:run).with("bundle install", has_entries(chdir: backend_dir, allow_failure: true)).in_sequence(order).returns(true)
      Workspace.expects(:run).with("npm install", has_entries(chdir: backend_dir, allow_failure: true)).in_sequence(order).returns(true)
      Workspace.expects(:run).with("bundle exec rails db:prepare", has_entries(chdir: backend_dir, allow_failure: true)).in_sequence(order).returns(true)
      Workspace.expects(:run).with(
        "bundle exec rails blazer:default_queries:install blazer:install_dashboards",
        has_entries(chdir: backend_dir, allow_failure: true)
      ).in_sequence(order).returns(true)
      Workspace.expects(:run).with("bin/bootstrap", has_entries(chdir: frontend_dir, allow_failure: true)).in_sequence(order).returns(true)
      Workspace.expects(:run).with("bundle install", has_entries(chdir: frontend_dir, allow_failure: true)).in_sequence(order).returns(true)
      Workspace.expects(:run).with("npm install", has_entries(chdir: frontend_dir, allow_failure: true)).in_sequence(order).returns(true)
      Workspace.expects(:run).with("bin/bootstrap", has_entries(chdir: dsml_dir, allow_failure: true)).in_sequence(order).returns(true)

      command = Workspace::Services::Bootstrap.new(context: Workspace::Context.new(root: root_dir))
      command.stubs(:system).returns(true)

      result = command.call
      assert_equal 0, result
    end
  end

  def test_happy_path_returns_zero
    Dir.mktmpdir("workspace-bootstrap") do |repo_dir|
      File.write(File.join(repo_dir, "Gemfile"), "source 'https://rubygems.org'\n")
      File.write(File.join(repo_dir, "package.json"), "{}")
      FileUtils.mkdir_p(File.join(repo_dir, "config"))
      File.write(File.join(repo_dir, "config", "database.yml"), "test: {}\n")
      FileUtils.mkdir_p(File.join(repo_dir, "bin"))
      File.write(File.join(repo_dir, "bin", "rails"), "#!/usr/bin/env ruby\n")
      FileUtils.chmod("u+x", File.join(repo_dir, "bin", "rails"))

      repos = [{ "name" => "api-template", "path" => repo_dir }]

      Workspace.stubs(:repositories).returns(repos)
      Workspace.stubs(:existing_repositories).returns(repos)
      Workspace.stubs(:repo_name).with(repos.first).returns("api-template")
      Workspace.stubs(:repo_path).returns(repo_dir)
      Workspace.stubs(:run).returns(true)
      Workspace.stubs(:ok)
      Workspace.stubs(:warn)
      Workspace.stubs(:fail_with_help)
      Workspace.stubs(:abort_with_help).raises("abort_with_help called unexpectedly")
      Workspace.stubs(:script_path).returns("bin/preinstall_checks")

      command = Workspace::Services::Bootstrap.new(context: Workspace::Context.new(root: repo_dir))
      command.stubs(:system).returns(true)

      result = command.call
      assert_equal 0, result
    end
  end

  def test_runs_repo_local_bootstrap_script_when_present
    Dir.mktmpdir("workspace-bootstrap") do |repo_dir|
      FileUtils.mkdir_p(File.join(repo_dir, "bin"))
      bootstrap_script = File.join(repo_dir, "bin", "bootstrap")
      File.write(bootstrap_script, "#!/usr/bin/env bash\n")
      FileUtils.chmod("u+x", bootstrap_script)

      repos = [{ "name" => "dsml-template", "path" => repo_dir }]

      Workspace.stubs(:repositories).returns(repos)
      Workspace.stubs(:existing_repositories).returns(repos)
      Workspace.stubs(:repo_name).with(repos.first).returns("dsml-template")
      Workspace.stubs(:repo_path).returns(repo_dir)
      Workspace.stubs(:ok)
      Workspace.stubs(:warn)
      Workspace.stubs(:fail_with_help)
      Workspace.stubs(:abort_with_help).raises("abort_with_help called unexpectedly")
      Workspace.stubs(:script_path).returns("bin/preinstall_checks")

      Workspace.expects(:run).with(
        "bin/bootstrap",
        has_entries(
          chdir: repo_dir,
          allow_failure: true,
          summary: "Repository bootstrap failed for dsml-template."
        )
      ).returns(true)

      command = Workspace::Services::Bootstrap.new(context: Workspace::Context.new(root: repo_dir))
      command.stubs(:system).returns(true)

      result = command.call
      assert_equal 0, result
    end
  end

  def test_runs_backend_specific_flow_for_backend_purpose_repo
    Dir.mktmpdir("workspace-bootstrap") do |repo_dir|
      File.write(File.join(repo_dir, "Gemfile"), "source 'https://rubygems.org'\n")
      File.write(File.join(repo_dir, "package.json"), "{}")
      FileUtils.mkdir_p(File.join(repo_dir, "config"))
      File.write(File.join(repo_dir, "config", "database.yml"), "test: {}\n")
      FileUtils.mkdir_p(File.join(repo_dir, "bin"))
      File.write(File.join(repo_dir, "bin", "rails"), "#!/usr/bin/env ruby\n")
      File.write(File.join(repo_dir, "bin", "bootstrap"), "#!/usr/bin/env bash\n")
      FileUtils.chmod("u+x", File.join(repo_dir, "bin", "rails"))
      FileUtils.chmod("u+x", File.join(repo_dir, "bin", "bootstrap"))
      FileUtils.mkdir_p(File.join(repo_dir, "lib", "tasks"))
      File.write(File.join(repo_dir, "lib", "tasks", "blazer_default_queries.rake"), "task :noop do\nend\n")
      File.write(File.join(repo_dir, "lib", "tasks", "blazer_dashboards.rake"), "task :noop2 do\nend\n")

      repos = [{ "purpose" => "backend-api", "name" => "api-template", "path" => repo_dir }]

      Workspace.stubs(:repositories).returns(repos)
      Workspace.stubs(:existing_repositories).returns(repos)
      Workspace.stubs(:repo_name).with(repos.first).returns("api-template")
      Workspace.stubs(:repo_path).returns(repo_dir)
      Workspace.stubs(:ok)
      Workspace.stubs(:warn)
      Workspace.stubs(:info)
      Workspace.stubs(:fail_with_help)
      Workspace.stubs(:abort_with_help).raises("abort_with_help called unexpectedly")
      Workspace.stubs(:script_path).returns("bin/preinstall_checks")

      Workspace.expects(:run).with("bin/bootstrap", has_entries(chdir: repo_dir, allow_failure: true)).returns(true)
      Workspace.expects(:run).with("bundle install", has_entries(chdir: repo_dir, allow_failure: true)).returns(true)
      Workspace.expects(:run).with("npm install", has_entries(chdir: repo_dir, allow_failure: true)).returns(true)
      Workspace.expects(:run).with("bundle exec rails db:prepare", has_entries(chdir: repo_dir, allow_failure: true)).returns(true)
      Workspace.expects(:run).with(
        "bundle exec rails blazer:default_queries:install blazer:install_dashboards",
        has_entries(chdir: repo_dir, allow_failure: true)
      ).returns(true)

      command = Workspace::Services::Bootstrap.new(context: Workspace::Context.new(root: repo_dir))
      command.stubs(:system).returns(true)

      result = command.call
      assert_equal 0, result
    end
  end

  def test_runs_frontend_specific_flow_for_frontend_purpose_repo
    Dir.mktmpdir("workspace-bootstrap") do |repo_dir|
      File.write(File.join(repo_dir, "Gemfile"), "source 'https://rubygems.org'\n")
      File.write(File.join(repo_dir, "package.json"), "{}")
      FileUtils.mkdir_p(File.join(repo_dir, "bin"))
      File.write(File.join(repo_dir, "bin", "bootstrap"), "#!/usr/bin/env bash\n")
      FileUtils.chmod("u+x", File.join(repo_dir, "bin", "bootstrap"))

      repos = [{ "purpose" => "frontend-web-client", "name" => "web-template", "path" => repo_dir }]

      Workspace.stubs(:repositories).returns(repos)
      Workspace.stubs(:existing_repositories).returns(repos)
      Workspace.stubs(:repo_name).with(repos.first).returns("web-template")
      Workspace.stubs(:repo_path).returns(repo_dir)
      Workspace.stubs(:ok)
      Workspace.stubs(:warn)
      Workspace.stubs(:fail_with_help)
      Workspace.stubs(:abort_with_help).raises("abort_with_help called unexpectedly")
      Workspace.stubs(:script_path).returns("bin/preinstall_checks")

      Workspace.expects(:run).with("bin/bootstrap", has_entries(chdir: repo_dir, allow_failure: true)).returns(true)
      Workspace.expects(:run).with("bundle install", has_entries(chdir: repo_dir, allow_failure: true)).returns(true)
      Workspace.expects(:run).with("npm install", has_entries(chdir: repo_dir, allow_failure: true)).returns(true)

      command = Workspace::Services::Bootstrap.new(context: Workspace::Context.new(root: repo_dir))
      command.stubs(:system).returns(true)

      result = command.call
      assert_equal 0, result
    end
  end

  def test_runs_dsml_specific_flow_for_dsml_purpose_repo
    Dir.mktmpdir("workspace-bootstrap") do |repo_dir|
      FileUtils.mkdir_p(File.join(repo_dir, "bin"))
      File.write(File.join(repo_dir, "bin", "bootstrap"), "#!/usr/bin/env bash\n")
      FileUtils.chmod("u+x", File.join(repo_dir, "bin", "bootstrap"))

      repos = [{ "purpose" => "data-science-ml", "name" => "dsml-template", "path" => repo_dir }]

      Workspace.stubs(:repositories).returns(repos)
      Workspace.stubs(:existing_repositories).returns(repos)
      Workspace.stubs(:repo_name).with(repos.first).returns("dsml-template")
      Workspace.stubs(:repo_path).returns(repo_dir)
      Workspace.stubs(:ok)
      Workspace.stubs(:warn)
      Workspace.stubs(:fail_with_help)
      Workspace.stubs(:abort_with_help).raises("abort_with_help called unexpectedly")
      Workspace.stubs(:script_path).returns("bin/preinstall_checks")

      Workspace.expects(:run).with("bin/bootstrap", has_entries(chdir: repo_dir, allow_failure: true)).returns(true)

      command = Workspace::Services::Bootstrap.new(context: Workspace::Context.new(root: repo_dir))
      command.stubs(:system).returns(true)

      result = command.call
      assert_equal 0, result
    end
  end
end

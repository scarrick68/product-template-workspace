# frozen_string_literal: true

require "open3"
require "tmpdir"

require_relative "../../../../test_helper"
require_relative "../../../../../lib/workspace/services/git/changes_committer"

class GitChangesCommitterTest < Minitest::Test
  def test_available_is_false_outside_git_repo
    Dir.mktmpdir("changes-committer") do |root|
      committer = Workspace::Services::Git::ChangesCommitter.new(context: Workspace::Context.new(root: root))

      assert_equal false, committer.available?
    end
  end

  def test_mark_and_commit_since_commit_only_paths_changed_after_marker
    Dir.mktmpdir("changes-committer") do |root|
      write_file(root, "tracked-before.txt", "before\n")
      write_file(root, "tracked-new.txt", "old\n")
      initialize_git_repo(root)

      write_file(root, "tracked-before.txt", "dirty before marker\n")

      committer = Workspace::Services::Git::ChangesCommitter.new(context: Workspace::Context.new(root: root))
      marker = committer.mark

      write_file(root, "tracked-new.txt", "changed after marker\n")
      write_file(root, "new-after-marker.txt", "new file\n")

      committed = committer.commit_since(marker, message: "[SYSTEM][TEST] Commit marker delta")
      assert_equal true, committed

      committed_paths = git_stdout(root, "show", "--pretty=", "--name-only", "HEAD").split("\n")
      assert_includes committed_paths, "tracked-new.txt"
      assert_includes committed_paths, "new-after-marker.txt"
      refute_includes committed_paths, "tracked-before.txt"

      status = git_stdout(root, "status", "--short")
      assert_includes status, "tracked-before.txt"
    end
  end

  def test_commit_since_returns_false_when_no_new_changes_since_marker
    Dir.mktmpdir("changes-committer") do |root|
      write_file(root, "file.txt", "content\n")
      initialize_git_repo(root)

      committer = Workspace::Services::Git::ChangesCommitter.new(context: Workspace::Context.new(root: root))
      marker = committer.mark

      committed = committer.commit_since(marker, message: "[SYSTEM][TEST] No-op")
      assert_equal false, committed
    end
  end

  def test_ensure_clean_raises_when_repo_has_changes
    Dir.mktmpdir("changes-committer") do |root|
      write_file(root, "file.txt", "content\n")
      initialize_git_repo(root)
      write_file(root, "file.txt", "changed\n")

      committer = Workspace::Services::Git::ChangesCommitter.new(context: Workspace::Context.new(root: root))

      error = assert_raises(Workspace::Services::Git::ChangesCommitter::OperationError) do
        committer.ensure_clean!
      end

      assert_match(/Git working tree must be clean/, error.message)
    end
  end

  private

  def initialize_git_repo(root)
    run_git(root, "init")
    run_git(root, "config", "user.name", "Local Test User")
    run_git(root, "config", "user.email", "local-test@example.com")
    run_git(root, "add", ".")
    run_git(root, "commit", "-m", "Initial commit")
  end

  def write_file(root, path, content)
    absolute = File.join(root, path)
    FileUtils.mkdir_p(File.dirname(absolute))
    File.write(absolute, content)
  end

  def run_git(root, *args)
    git_stdout(root, *args)
  end

  def git_stdout(root, *args)
    output, status = Open3.capture2e("git", *args, chdir: root)
    raise "git #{args.join(' ')} failed: #{output}" unless status.success?

    output.strip
  end
end
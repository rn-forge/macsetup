# typed: strict
# frozen_string_literal: true

# Strategy for downloading a file through a remote host with internet access.
#
# The remote host performs the download and the completed file is copied back to
# the local cache, so local network policy does not block `brew upgrade`.
class RemoteRelayCurlDownloadStrategy < CurlDownloadStrategy
  private

  sig { override.params(url: String, timeout: T.nilable(T.any(Float, Integer))).returns(URLMetadata) }
  def resolve_url_basename_time_file_size(url, timeout: nil)
    [url, parse_basename(url), nil, nil, nil, false]
  end

  sig {
    override.params(url: String, resolved_url: String, timeout: T.nilable(T.any(Float, Integer)))
            .returns(T.nilable(SystemCommand::Result))
  }
  def _fetch(url:, resolved_url:, timeout:)
    remote_host = ENV.fetch("HOMEBREW_REMOTE_RELAY_HOST")
    remote_dir = "/tmp/homebrew_REMOTE_RELAY"
    remote_location = "#{remote_dir}/#{temporary_path.basename}"

    ## commands
    download_command = [
      "mkdir -p #{Shellwords.escape(remote_dir)}",
      "&&",
      "curl",
      "-L",
      "--fail",
      "--header 'Authorization: #{HOMEBREW_GITHUB_PACKAGES_AUTH}'",
      "--output #{Shellwords.escape(remote_location)}",
      Shellwords.escape(resolved_url),
    ].join(" ")
    cleanup_command="rm -f #{remote_location}"

    ## debug commands
    if ENV["HOMEBREW_REMOTE_RELAY_DEBUG"].present?
      $stderr.puts "Warning: using homebrew REMOTE_RELAY => #{remote_host}
download: #{download_command}
transfer: scp #{remote_location} #{temporary_path}
cleanup: #{cleanup_command}"
    end

    ## execute commands
    command!("ssh", args: ["#{remote_host}", download_command], timeout:)
    command!("scp", args: ["#{remote_host}:#{remote_location}", temporary_path.to_s], timeout:)
  ensure
    silent_command("ssh", args: ["#{remote_host}", cleanup_command])
  end
end

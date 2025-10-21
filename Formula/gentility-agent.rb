class GentilityAgent < Formula
  desc "Gentility AI remote access daemon"
  homepage "https://gentility.ai"
  version "1.1.9"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/gentility-ai/agent/releases/download/v#{version}/gentility-agent-#{version}-darwin-arm64.tar.gz"
      sha256 "873ac2afdffa30452e58fd4a75adfc5b9ecae3cd79567c4dfa03f0a5b10ebd06"
    end

    on_intel do
      url "https://github.com/gentility-ai/agent/releases/download/v#{version}/gentility-agent-#{version}-darwin-amd64.tar.gz"
      sha256 "0019dfc4b32d63c1392aa264aed2253c1e0c2fb09216f8e2cc269bbfb8bb49b5"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/gentility-ai/agent/releases/download/v#{version}/gentility-agent-#{version}-linux-arm64"
      sha256 "0019dfc4b32d63c1392aa264aed2253c1e0c2fb09216f8e2cc269bbfb8bb49b5"
    end

    on_intel do
      url "https://github.com/gentility-ai/agent/releases/download/v#{version}/gentility-agent-#{version}-linux-amd64"
      sha256 "32541f913db1b3095d584fbbbee3c054f517943a6c4dfe01c40340e4ffaad42e"
    end
  end

  # No standalone resource - will be defined dynamically in install method if needed

  depends_on "bdw-gc" => :optional
  depends_on "crystal" => [:build, :optional]
  depends_on "libevent" => :optional
  depends_on "openssl@3"
  depends_on "pcre2" => :optional

  def install
    # Check if we downloaded a prebuilt binary or need to build from source
    if buildpath.glob("gentility-agent-*").any?
      # Prebuilt binary was downloaded (from tar.gz)
      binary = buildpath.glob("gentility-agent-*").first
      bin.install binary => "gentility"

      # Install config example if it was included in the archive
      etc.install "gentility.yaml.example" if File.exist?("gentility.yaml.example")
    else
      # Build from source (fallback)
      # Download source tarball dynamically (version method works here in instance context)
      source_url = "https://github.com/gentility-ai/agent/archive/refs/tags/v#{version}.tar.gz"

      # Create a resource on the fly
      resource("source") do
        url source_url
      end

      resource("source").stage do
        # GitHub tarball extracts to agent-VERSION directory
        Dir.chdir("agent-#{version}") do
          # Install Crystal dependencies
          system "shards", "install", "--production"

          # Set up OpenSSL paths for macOS
          ENV["PKG_CONFIG_PATH"] = "#{Formula["openssl@3"].opt_lib}/pkgconfig"

          # Build the binary with proper linking
          system "crystal", "build", "src/agent.cr",
                 "--release", "--no-debug", "-o", "gentility",
                 "--link-flags", "-L#{Formula["openssl@3"].opt_lib}"

          # Install the binary
          bin.install "gentility"

          # Install configuration example
          etc.install "gentility.yaml.example" if File.exist?("gentility.yaml.example")
        end
      end
    end
  end

  def caveats
    <<~EOS
      Quick Setup:
        gentility auth

      This will log you in and associate this machine with your account.

      Then start as a service:
        brew services start gentility-agent

      Or run manually:
        gentility run

      For help: gentility help
    EOS
  end

  service do
    run [opt_bin/"gentility", "run"]
    environment_variables GENTILITY_CONFIG: etc/"gentility.yaml"
    run_type :immediate
    keep_alive true
    log_path var/"log/gentility-agent/stdout.log"
    error_log_path var/"log/gentility-agent/stderr.log"
  end

  test do
    # Test that the binary was installed and shows help
    assert_match "Gentility", shell_output("#{bin}/gentility help")
  end
end

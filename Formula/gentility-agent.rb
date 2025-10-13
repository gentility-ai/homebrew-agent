class GentilityAgent < Formula
  desc "Gentility AI remote access daemon"
  homepage "https://gentility.ai"
  version "1.1.6"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/gentility-ai/agent/releases/download/v#{version}/gentility-agent-#{version}-darwin-arm64"
      sha256 "f6876f7f4af13bdfad3e2a6f28983051f26f295f0df667730f0235792e35e54e"
    end

    on_intel do
      url "https://github.com/gentility-ai/agent/releases/download/v#{version}/gentility-agent-#{version}-darwin-amd64"
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
      sha256 "d3cb8d60ecab37358c61a45b3215b49c016c2c47c555d70a435151c10736650e"
    end
  end

  # Fallback to source for platforms without prebuilt binaries
  resource "source" do
    url "https://github.com/gentility-ai/agent.git",
        tag: "v#{version}"
  end

  depends_on "bdw-gc" => :optional
  depends_on "crystal" => [:build, :optional]
  depends_on "libevent" => :optional
  depends_on "openssl@3"
  depends_on "pcre2" => :optional

  def install
    # Check if we downloaded a prebuilt binary or need to build from source
    if buildpath.glob("gentility-agent-*").any?
      # Prebuilt binary was downloaded
      binary = buildpath.glob("gentility-agent-*").first
      bin.install binary => "gentility"

      # Download source to get config example
      resource("source").stage do
        etc.install "gentility.yaml.example" if File.exist?("gentility.yaml.example")
      end
    else
      # Build from source (fallback)
      resource("source").stage(buildpath)

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

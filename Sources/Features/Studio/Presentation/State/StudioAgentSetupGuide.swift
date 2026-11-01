import Foundation

/// One copyable line in the agent setup guide.
struct StudioAgentSetupCommand: Equatable, Sendable, Identifiable {
  let id: String
  let label: String
  let text: String
}

/// One numbered step in the agent setup guide.
struct StudioAgentSetupStep: Equatable, Sendable, Identifiable {
  let id: String
  let title: String
  let detail: String
  let commands: [StudioAgentSetupCommand]
}

/// Read-only steps for wiring PersonaKit into coding agents. Studio shows these for the
/// user to run; it writes nothing itself. Command strings mirror `README.md`,
/// `Docs/mcp.md`, and `personakit enforce install --help`.
enum StudioAgentSetupGuide {
  static let releasesURL = URL(string: "https://github.com/ajself/PersonaKit/releases/latest")!

  static let steps: [StudioAgentSetupStep] = [
    StudioAgentSetupStep(
      id: "cli",
      title: "Install the CLI",
      detail:
        "Download and open the signed PersonaKit.pkg from GitHub Releases. It installs the CLI at /usr/local/bin/personakit.",
      commands: [
        StudioAgentSetupCommand(id: "cli-releases", label: "GitHub Releases", text: releasesURL.absoluteString)
      ]
    ),
    StudioAgentSetupStep(
      id: "mcp",
      title: "Add the MCP server",
      detail: "Register the read-only PersonaKit MCP server with your agent.",
      commands: [
        StudioAgentSetupCommand(
          id: "mcp-claude",
          label: "Claude Code",
          text: #"claude mcp add personakit --scope user -- "$(which personakit)" mcp"#
        ),
        StudioAgentSetupCommand(
          id: "mcp-opencode",
          label: "OpenCode (merge into opencode.json)",
          text: """
            {
              "$schema": "https://opencode.ai/config.json",
              "mcp": {
                "personakit": {
                  "command": ["/usr/local/bin/personakit", "mcp"],
                  "enabled": true,
                  "type": "local"
                }
              }
            }
            """
        ),
      ]
    ),
    StudioAgentSetupStep(
      id: "opencode-plugin",
      title: "Install the OpenCode plugin",
      detail: "OpenCode only. Run this from a PersonaKit checkout at the release tag that matches this app.",
      commands: [
        StudioAgentSetupCommand(id: "opencode-plugin-install", label: "Terminal", text: "make opencode-install")
      ]
    ),
    StudioAgentSetupStep(
      id: "enforce",
      title: "Enforce a session's contract",
      detail: "Optional. Run this from your project folder, replacing <id> with a session id.",
      commands: [
        StudioAgentSetupCommand(
          id: "enforce-claude",
          label: "Claude Code",
          text: "personakit enforce install --session <id>"
        ),
        StudioAgentSetupCommand(
          id: "enforce-opencode",
          label: "OpenCode",
          text: "personakit enforce install --host opencode --session <id>"
        ),
      ]
    ),
  ]
}

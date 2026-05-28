import ArgumentParser
import ContextWorkspaceCore

struct CreateCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "create",
    abstract: "Create PersonaKit entities and authored files.",
    subcommands: [
      CreatePersonaCommand.self,
      CreateKitCommand.self,
      CreateDirectiveCommand.self,
      CreateIntentCommand.self,
      CreateSkillCommand.self,
      CreateSessionCommand.self,
      CreateEssentialCommand.self,
    ]
  )
}

struct CreateSharedOptions: ParsableArguments {
  @Option(
    name: .customLong("root"),
    help: "Writable PersonaKit root. Defaults to the nearest project .personakit, then ~/.personakit.",
    completion: .directory
  )
  var rootPath: String?

  @Option(
    name: .customLong("template"),
    help: "Template preset to use."
  )
  var template: CreateTemplateOption = .starter

  @Flag(name: .customLong("dry-run"), help: "Render destination and content without writing.")
  var dryRun = false

  @Flag(name: .customLong("force"), help: "Overwrite an existing authored file.")
  var force = false

  @Flag(name: .customLong("json"), help: "Emit machine-readable success or error output.")
  var jsonOutput = false

  var resolvedTemplate: WorkspaceCreationTemplate {
    template.workspaceTemplate
  }
}

enum CreateTemplateOption: String, ExpressibleByArgument {
  case starter
  case minimal

  var workspaceTemplate: WorkspaceCreationTemplate {
    switch self {
    case .starter:
      return .starter
    case .minimal:
      return .minimal
    }
  }
}

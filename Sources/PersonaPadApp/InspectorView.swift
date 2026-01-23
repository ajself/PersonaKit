import SwiftUI
import PersonaPadCore

struct InspectorView: View {
  @EnvironmentObject private var store: AppStore

  private var selectedPersona: Persona? {
    guard let id = store.selectedPersonaID else { return nil }
    return store.personaIndex[id]?.persona
  }

  private var selectedPersonaTags: [String] {
    selectedPersona?.sortedTags ?? []
  }

  private var selectedPackLabel: String {
    guard let persona = selectedPersona,
          let pack = store.personaPacksByID[persona.id] else {
      return "Unknown"
    }
    let name = pack.name.trimmingCharacters(in: .whitespacesAndNewlines)
    let id = pack.id.trimmingCharacters(in: .whitespacesAndNewlines)
    if !name.isEmpty && !id.isEmpty && name != id {
      return "\(name) (\(id))"
    }
    if !name.isEmpty {
      return name
    }
    if !id.isEmpty {
      return id
    }
    return "Unknown"
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 12) {
          Label("Persona", systemImage: "person")
            .font(.headline)
          VStack(alignment: .leading, spacing: 4) {
            personaHeaderLine
          }
          personaAboutSection
            .padding(.top, 8)
          personaTagsSection
          personaSourceSection
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        Divider()

        GroupBox {
          ComposerView()
        } label: {
          Label("Parameters", systemImage: "slider.horizontal.3")
        }
      }
      .padding()
    }
    .frame(minWidth: 260)
  }

  private var personaHeaderLine: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(selectedPersona?.name ?? "No persona selected")
        .font(.title3)
        .foregroundStyle(.primary)
      if let id = selectedPersona?.id {
        Text(id)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  private var personaAboutSection: some View {
    VStack(alignment: .leading, spacing: 6) {
      Label("About", systemImage: "info.circle")
        .font(.headline)
      Text(aboutText)
        .font(.callout)
        .foregroundStyle(.secondary)
    }
  }

  private var personaTagsSection: some View {
    VStack(alignment: .leading, spacing: 6) {
      Label("Persona Tags", systemImage: "tag")
        .font(.headline)
      if selectedPersonaTags.isEmpty {
        Text("No tags.")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], alignment: .leading, spacing: 8) {
          ForEach(selectedPersonaTags, id: \.self) { tag in
            TagPill(title: tag)
          }
        }
      }
    }
  }

  private var personaSourceSection: some View {
    VStack(alignment: .leading, spacing: 6) {
      Label("Source", systemImage: "tray.full")
        .font(.headline)
      Text(selectedPackLabel)
        .font(.callout)
        .foregroundStyle(.secondary)
    }
  }

  private var aboutText: String {
    guard let about = selectedPersona?.about?.trimmingCharacters(in: .whitespacesAndNewlines),
          !about.isEmpty else {
      return "No description."
    }
    return about
  }
}

private struct TagPill: View {
  let title: String

  var body: some View {
    Text(title)
      .font(.caption2)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(Color.secondary.opacity(0.12))
      .clipShape(Capsule())
  }
}

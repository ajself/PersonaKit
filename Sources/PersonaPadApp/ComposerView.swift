import SwiftUI
import PersonaPadCore

struct ComposerView: View {
  @EnvironmentObject private var store: AppStore

  private var persona: Persona? {
    guard let id = store.selectedPersonaID else { return nil }
    return store.personaIndex[id]?.persona
  }

  var body: some View {
    Group {
      if let persona {
        ScrollView {
          VStack(alignment: .leading, spacing: 12) {
            Text(persona.name).font(.title2).bold()
            if let desc = persona.description, !desc.isEmpty {
              Text(desc).foregroundStyle(.secondary)
            }

            Divider()

            let sections = persona.template?.sections ?? defaultSections
            ForEach(sections, id: \.key) { s in
              VStack(alignment: .leading, spacing: 6) {
                HStack {
                  Text(s.label).font(.headline)
                  if s.required { Text("Required").font(.caption).foregroundStyle(.secondary) }
                }
                TextEditor(text: Binding(
                  get: { store.composerValues[s.key] ?? "" },
                  set: { newValue in
                    store.composerValues[s.key] = newValue
                    store.recomputePreview()
                  }
                ))
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 100)
                .overlay(
                  RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.25))
                )
              }
            }

            Spacer(minLength: 24)
          }
          .padding()
        }
      } else {
        if #available(macOS 14.0, *) {
          ContentUnavailableView("No persona selected", systemImage: "person.crop.circle.badge.questionmark")
        } else {
          VStack(spacing: 8) {
            Image(systemName: "person.crop.circle.badge.questionmark")
              .font(.system(size: 36))
              .foregroundStyle(.secondary)
            Text("No persona selected")
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
    }
  }

  private var defaultSections: [TemplateSection] {
    [
      TemplateSection(key: "context", label: "Context", required: true),
      TemplateSection(key: "goal", label: "Goal", required: true),
      TemplateSection(key: "constraints", label: "Constraints", required: false),
      TemplateSection(key: "evidence", label: "Evidence", required: false),
      TemplateSection(key: "task", label: "Task", required: true)
    ]
  }
}

import Foundation
import OrbitServerRuntime

struct OrbitStructuredReferencesAndArtifactsSurfaceItem: Identifiable, Equatable {
  enum Content: Equatable {
    case reference(OrbitStructuredReferenceSurface)
    case artifact(OrbitStructuredArtifactSurface)
  }

  let id: String
  let createdByDisplayName: String
  let createdAt: Date
  let content: Content
}

struct OrbitStructuredReferenceSurface: Equatable {
  enum Presentation: Equatable {
    case fullMetadata
    case meetingOutputsReference
  }

  let referenceType: OrbitReferenceType
  let title: String
  let target: String
  let presentation: Presentation
}

struct OrbitStructuredArtifactSurface: Equatable {
  let artifactType: OrbitArtifactType
  let title: String
  let storageRef: String
}

extension OrbitWorkspace {
  func structuredReferencesAndArtifactsSurfaceItems(
    for postID: String
  ) -> [OrbitStructuredReferencesAndArtifactsSurfaceItem] {
    let structuredObjectRecords = structuredPostObjectRecords(for: postID)
    let meetingReferenceIDs = Set(meetingReferenceRecords(for: postID).map(\.id))
    let isMeetingPost = self.isMeetingPost(postID: postID)

    return structuredObjectRecords.compactMap { record in
      switch record.object {
      case let .reference(reference):
        let presentation: OrbitStructuredReferenceSurface.Presentation =
          isMeetingPost && meetingReferenceIDs.contains(reference.id.uuidString)
          ? .meetingOutputsReference
          : .fullMetadata

        return OrbitStructuredReferencesAndArtifactsSurfaceItem(
          id: record.id,
          createdByDisplayName: structuredCreatorDisplayName(
            for: reference.createdByParticipantType,
            participantID: reference.createdByParticipantID
          ),
          createdAt: reference.createdAt,
          content: .reference(
            OrbitStructuredReferenceSurface(
              referenceType: reference.referenceType,
              title: reference.title ?? reference.target,
              target: reference.target,
              presentation: presentation
            )
          )
        )
      case let .artifact(artifact):
        return OrbitStructuredReferencesAndArtifactsSurfaceItem(
          id: record.id,
          createdByDisplayName: structuredCreatorDisplayName(
            for: artifact.createdByParticipantType,
            participantID: artifact.createdByParticipantID
          ),
          createdAt: artifact.createdAt,
          content: .artifact(
            OrbitStructuredArtifactSurface(
              artifactType: artifact.artifactType,
              title: artifact.title ?? artifact.storageRef,
              storageRef: artifact.storageRef
            )
          )
        )
      case .note, .decision:
        return nil
      }
    }
  }

  var activeStructuredReferencesAndArtifactsSurfaceItems: [OrbitStructuredReferencesAndArtifactsSurfaceItem] {
    guard let activePostID else {
      return []
    }

    return structuredReferencesAndArtifactsSurfaceItems(for: activePostID)
  }
}

extension OrbitReferenceType {
  var displayText: String {
    switch self {
    case .url:
      return "URL"
    case .doc:
      return "Doc"
    case .file:
      return "File"
    case .issue:
      return "Issue"
    case .commit:
      return "Commit"
    case .externalNote:
      return "External Note"
    }
  }
}

extension OrbitArtifactType {
  var displayText: String {
    switch self {
    case .file:
      return "File"
    case .image:
      return "Image"
    case .codeOutput:
      return "Code Output"
    case .report:
      return "Report"
    case .bundle:
      return "Bundle"
    case .other:
      return "Other"
    }
  }
}

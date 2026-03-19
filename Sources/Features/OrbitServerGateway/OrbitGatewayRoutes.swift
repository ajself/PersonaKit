import Foundation
import OrbitServerRuntime
import Vapor

public enum OrbitGatewayRoutes {
  public static func register(
    on app: Application,
    transport: some OrbitRealtimeTransportHandling,
    roomWriter: (any OrbitPhase1RoomWriteServing)? = nil,
    systemWriter: (any OrbitSystemMessageHandling)? = nil,
    failureWriter: (any OrbitActivationFailureHandling)? = nil,
    collaboratorWriter: (any OrbitCollaboratorResponseHandling)? = nil
  ) {
    let realtime = app.grouped("api", "orbit", "realtime")
    let room = app.grouped("api", "orbit", "room")

    realtime.post("connect") { request async throws -> OrbitGatewayTransportResponse in
      let body = try request.content.decode(OrbitGatewayConnectRequest.self)
      let response = try await transport.connect(request: body.transportRequest)
      return OrbitGatewayTransportResponse(response: response)
    }

    realtime.post("poll") { request async throws -> OrbitGatewayTransportResponse in
      let body = try request.content.decode(OrbitGatewayPollRequest.self)
      let response = try await transport.poll(request: body.transportRequest)
      return OrbitGatewayTransportResponse(response: response)
    }

    realtime.webSocket("socket") { request, socket in
      Task {
        do {
          let connectQuery = try makeSocketConnectQuery(from: request)
          let encoder = JSONEncoder()

          socket.onText { _, text in
            Task {
              do {
                let clientMessage = try JSONDecoder().decode(OrbitGatewayWebSocketClientMessage.self, from: Data(text.utf8))

                let transportResponse: OrbitPhase1RealtimeTransportResponse
                switch clientMessage.kind {
                case .bootstrap:
                  transportResponse = try await transport.connect(request: connectQuery.connectRequest)
                case .poll:
                  guard let pollRequest = clientMessage.transportRequest else {
                    throw Abort(.badRequest)
                  }
                  transportResponse = try await transport.poll(request: pollRequest)
                }

                let payload = try encoder.encode(OrbitGatewayTransportResponse(response: transportResponse))
                try await socket.send(String(decoding: payload, as: UTF8.self))
              } catch {
                try? await socket.send("{\"kind\":\"error\"}")
                socket.close(promise: nil)
              }
            }
          }
        } catch {
          try? await socket.send("{\"kind\":\"error\"}")
          socket.close(promise: nil)
        }
      }
    }

    if let roomWriter {
      room.post("messages") { request async throws -> OrbitGatewayAppendMessageResponse in
        let body = try request.content.decode(OrbitGatewayAppendMessageRequest.self)
        let result = try await roomWriter.appendUserMessage(body.runtimeRequest)
        return OrbitGatewayAppendMessageResponse(result: result)
      }
    }

    if let systemWriter {
      room.post("system-messages") { request async throws -> OrbitGatewayAppendSystemMessageResponse in
        let body = try request.content.decode(OrbitGatewayAppendSystemMessageRequest.self)
        let result = try await systemWriter.appendSystemMessage(body.runtimeRequest)
        return OrbitGatewayAppendSystemMessageResponse(result: result)
      }
    }

    if let failureWriter {
      room.post("activation-failures") { request async throws -> OrbitGatewayAppendActivationFailureResponse in
        let body = try request.content.decode(OrbitGatewayAppendActivationFailureRequest.self)
        let result = try await failureWriter.appendActivationFailure(body.runtimeRequest)
        return OrbitGatewayAppendActivationFailureResponse(result: result)
      }
    }

    if let collaboratorWriter {
      room.post("responses") { request async throws -> OrbitGatewayAppendCollaboratorResponse in
        let body = try request.content.decode(OrbitGatewayAppendCollaboratorResponseRequest.self)
        guard let runtimeRequest = body.runtimeRequest else {
          throw Abort(.badRequest)
        }
        let result = try await collaboratorWriter.appendCollaboratorResponse(runtimeRequest)
        return OrbitGatewayAppendCollaboratorResponse(result: result)
      }
    }
  }

  static func makeSocketConnectQuery(
    from request: Request
  ) throws -> OrbitGatewayWebSocketConnectQuery {
    OrbitGatewayWebSocketConnectQuery(
      workspaceSlug: try request.query.get(String.self, at: "workspaceSlug"),
      channelSlug: try request.query.get(String.self, at: "channelSlug"),
      cursorWorkspaceID: try request.query.get(UUID?.self, at: "cursorWorkspaceID"),
      cursorEventID: try request.query.get(UUID?.self, at: "cursorEventID"),
      cursorEventCreatedAt: try request.query.get(Date?.self, at: "cursorEventCreatedAt")
    )
  }
}

//
//  StreamChatClientTools.swift
//  AIComponents
//
//  Created by Martin Mitrevski on 5.11.25.
//

import Foundation
import MCP
import StreamChat

struct ClientToolInvocationEventPayload: CustomEventPayload, Hashable {
    static let eventType: EventType = EventType(rawValue: "custom_client_tool_invocation")

    let messageId: String?
    let tool: ToolDescriptor
    let args: RawJSON?

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case tool
        case args
    }

    struct ToolDescriptor: Codable, Hashable {
        let name: String
        let description: String?
        let instructions: String?
        let parameters: RawJSON?

        enum CodingKeys: String, CodingKey {
            case name
            case description
            case instructions
            case parameters
        }
    }
}

extension ClientToolInvocation {
    var streamChatChannelId: ChannelId? {
        guard let channelId else { return nil }
        return channelId.base as? ChannelId
    }
}

@MainActor
final class GreetClientTool: ClientTool {
    let toolDefinition: Tool = {
        let schema: Value = .object([
            "type": .string("object"),
            "properties": .object([:]),
            "required": .array([]),
            "additionalProperties": .bool(false)
        ])

        return Tool(
            name: "greetUser",
            description: "Display a native greeting to the user",
            inputSchema: schema,
            annotations: .init(title: "Greet user")
        )
    }()

    let instructions =
        "Use the greetUser tool when the user asks to be greeted. The tool shows a greeting alert in the iOS app."

    let showExternalSourcesIndicator = false

    func handleInvocation(_ invocation: ClientToolInvocation) -> ClientToolAlert? {
        ClientToolAlert(
            title: "Greetings!",
            message: "👋 Hello there! The assistant asked me to greet you."
        )
    }
}

//
//  ClientToolRegistry.swift
//  AIComponents
//
//  Created by Martin Mitrevski on 4.11.25.
//

import Combine
import Foundation
import StreamChat
import MCP

@MainActor
final class ClientToolRegistry: ObservableObject {
    static let shared = ClientToolRegistry()

    @Published var activeAlert: ClientToolAlert?

    private var toolsByName: [String: any ClientTool] = [:]

    private init() {}

    func register(tool: any ClientTool) {
        toolsByName[tool.toolDefinition.name] = tool
    }

    func registrationPayloads() -> [ToolRegistrationPayload] {
        toolsByName.values.map { tool in
            ToolRegistrationPayload(
                name: tool.toolDefinition.name,
                description: tool.toolDefinition.description ?? tool.instructions,
                instructions: tool.instructions,
                parameters: tool.toolDefinition.inputSchema,
                showExternalSourcesIndicator: tool.showExternalSourcesIndicator
            )
        }
    }

    func handleInvocation(
        _ payload: ClientToolInvocationEventPayload,
        channelId: ChannelId
    ) {
        guard let tool = toolsByName[payload.tool.name] else { return }
        let invocation = ClientToolInvocation(
            tool: payload.tool,
            args: payload.args,
            messageId: payload.messageId,
            channelId: channelId
        )
        guard let alert = tool.handleInvocation(invocation) else { return }
        activeAlert = alert
    }
}

@MainActor
protocol ClientTool: AnyObject {
    var toolDefinition: Tool { get }
    var instructions: String { get }
    var showExternalSourcesIndicator: Bool { get }

    func handleInvocation(_ invocation: ClientToolInvocation) -> ClientToolAlert?
}

struct ClientToolInvocation {
    let tool: ClientToolInvocationEventPayload.ToolDescriptor
    let args: RawJSON?
    let messageId: String?
    let channelId: ChannelId
}

struct ClientToolAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

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

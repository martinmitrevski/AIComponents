//
//  ClientToolRegistry.swift
//  AIComponents
//
//  Created by Martin Mitrevski on 4.11.25.
//

import Combine
import Foundation
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
        channelId: AnyHashable? = nil
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
    let args: (any Codable & Hashable)?
    let messageId: String?
    let channelId: AnyHashable?
}

struct ClientToolAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

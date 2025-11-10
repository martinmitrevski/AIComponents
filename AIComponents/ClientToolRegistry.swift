//
//  ClientToolRegistry.swift
//  AIComponents
//
//  Created by Martin Mitrevski on 4.11.25.
//

import Foundation
import MCP

protocol ClientToolActionHandling: AnyObject {
    func handle(_ actions: [ClientToolAction])
}

final class ClientToolRegistry {
    static let shared = ClientToolRegistry()

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

    func handleInvocation(_ invocation: ClientToolInvocation) -> [ClientToolAction] {
        guard let tool = toolsByName[invocation.tool.name] else { return [] }
        return tool.handleInvocation(invocation)
    }
}

protocol ClientTool: AnyObject {
    var toolDefinition: Tool { get }
    var instructions: String { get }
    var showExternalSourcesIndicator: Bool { get }

    func handleInvocation(_ invocation: ClientToolInvocation) -> [ClientToolAction]
}

struct ClientToolInvocation {
    struct ToolDescriptor {
        let name: String
        let description: String?
        let instructions: String?
        let parameters: Data?

        init(
            name: String,
            description: String?,
            instructions: String?,
            parameters: Data?
        ) {
            self.name = name
            self.description = description
            self.instructions = instructions
            self.parameters = parameters
        }
    }

    let tool: ToolDescriptor
    let args: Data?
    let messageId: String?
    let channelId: AnyHashable?

    init(
        tool: ToolDescriptor,
        args: Data?,
        messageId: String?,
        channelId: AnyHashable?
    ) {
        self.tool = tool
        self.args = args
        self.messageId = messageId
        self.channelId = channelId
    }
}

typealias ClientToolAction = () -> Void

// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct CalculatorResultCommand: Command {
    public let calculation: CalcResult

    public var id: String { "calculator:\(calculation.input)" }
    public var title: String { calculation.input }
    public var subtitle: String { calculation.result }
    public let icon = CommandIcon.sfSymbol("equal.circle")
    public var keywords: [String] { [] }
    public let kind = CommandKind.system

    public init(calculation: CalcResult) {
        self.calculation = calculation
    }

    @MainActor
    public func execute(context: CommandContext) async throws {
        context.clipboard.writeText(calculation.result)
        context.toasts.show("Result copied")
    }
}

public struct CalculatorProvider: CommandProvider {
    public let service: CalculatorService

    public init(service: CalculatorService = CalculatorService()) {
        self.service = service
    }

    public func commands() async -> [any Command] {
        []
    }

    public func inlineResult(for query: String) -> CalculatorResultCommand? {
        service.evaluate(query: query).map(CalculatorResultCommand.init)
    }
}

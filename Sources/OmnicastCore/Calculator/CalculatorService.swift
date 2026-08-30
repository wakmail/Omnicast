// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SoulverCore

public enum CalcResultKind: String, Codable, Equatable, Sendable {
    case math
    case unit
    case currency
    case date
    case time
}

public struct CalcResult: Equatable, Sendable {
    public let kind: CalcResultKind
    public let input: String
    public let inputLabel: String
    public let result: String
    public let resultLabel: String

    public init(
        kind: CalcResultKind,
        input: String,
        inputLabel: String,
        result: String,
        resultLabel: String
    ) {
        self.kind = kind
        self.input = input
        self.inputLabel = inputLabel
        self.result = result
        self.resultLabel = resultLabel
    }
}

public final class CalculatorService: @unchecked Sendable {
    private let calculator: Calculator
    private let lock = NSLock()

    public init(locale: Locale = .current) {
        var customization = EngineCustomization.soulver.convertTo(locale: locale)
        customization.currencyRateProvider = ECBCurrencyRateProvider()
        customization.featureFlags.converters = true
        customization.featureFlags.wordFunctions = true
        customization.featureFlags.useDefaultRatesForUnhandledCurrencies = true
        calculator = Calculator(customization: customization)
        var formatting = FormattingPreferences()
        formatting.resultConversionBehavior = .automatic
        calculator.formattingPreferences = formatting
    }

    public func evaluate(query: String) -> CalcResult? {
        let input = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.looksLikeCalculation(input) else { return nil }

        lock.lock()
        defer { lock.unlock() }
        let calculation = calculator.calculate(input)
        guard !calculation.isEmptyResult, !calculation.isFailedResult else { return nil }
        guard let kind = Self.kind(for: calculation.evaluationResult) else { return nil }
        let labels = Self.labels(for: kind)
        return CalcResult(
            kind: kind,
            input: input,
            inputLabel: labels.input,
            result: Self.displayValue(for: calculation.evaluationResult, fallback: calculation.stringValue),
            resultLabel: labels.result
        )
    }

    public static func looksLikeCalculation(_ input: String) -> Bool {
        guard !input.isEmpty else { return false }
        if input.range(of: #"^\d+(\.\d+)?$"#, options: .regularExpression) != nil {
            return false
        }
        if input.range(of: #"^[A-Za-z]+$"#, options: .regularExpression) != nil {
            let keywords: Set<String> = ["today", "tomorrow", "yesterday", "now", "pi", "e", "tau", "phi"]
            return keywords.contains(input.lowercased())
        }
        return true
    }

    private static func kind(for result: EvaluationResult) -> CalcResultKind? {
        switch result {
        case .decimal, .scientificNotation, .binary, .octal, .hex, .fraction, .multiplier, .percentage:
            return .math
        case .unitExpression(let expression):
            return expression.unit.unitType == .currency ? .currency : .unit
        case .unit(let unit):
            return unit.unitType == .currency ? .currency : .unit
        case .unitRate, .decimalRate, .percentageRate, .unitRange:
            return .unit
        case .date, .iso8601, .timestamp, .datespan:
            return .date
        case .timespan, .laptime, .frametime, .pace:
            return .time
        default:
            return nil
        }
    }

    private static func labels(for kind: CalcResultKind) -> (input: String, result: String) {
        switch kind {
        case .math:
            return ("Expression", "Result")
        case .unit, .currency, .time:
            return ("From", "To")
        case .date:
            return ("Query", "Resolved date")
        }
    }

    private static func displayValue(for result: EvaluationResult, fallback: String) -> String {
        let date: Date?
        switch result {
        case .date(let stamp):
            date = stamp.date
        case .datespan(let span):
            date = span.startDate
        default:
            date = nil
        }
        guard let date else { return fallback }
        return date.formatted(
            Date.FormatStyle()
                .weekday(.wide)
                .day()
                .month(.wide)
                .year()
        )
    }
}

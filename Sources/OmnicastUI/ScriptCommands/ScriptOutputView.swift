// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import SwiftUI

@MainActor
public final class ScriptOutputViewModel: ObservableObject {
    @Published public private(set) var output = ""
    @Published public private(set) var isRunning = false
    @Published public private(set) var errorMessage: String?

    public let command: ScriptExecutableCommand
    private let arguments: [String: String]
    private var task: Task<Void, Never>?

    public init(
        command: ScriptExecutableCommand,
        arguments: [String: String]
    ) {
        self.command = command
        self.arguments = arguments
    }

    public func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            guard let self else { return }
            repeat {
                await runOnce()
                guard command.script.mode == .inline,
                      let interval = command.script.refreshInterval,
                      !Task.isCancelled else { break }
                do {
                    try await Task.sleep(nanoseconds: UInt64(max(1, interval) * 1_000_000_000))
                } catch {
                    break
                }
            } while !Task.isCancelled
            task = nil
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
    }

    private func runOnce() async {
        isRunning = true
        defer { isRunning = false }
        do {
            let result = try await command.runner.run(command.script, arguments: arguments)
            guard result.exitCode == 0 else {
                throw ScriptCommandExecutionError.unsuccessful(
                    exitCode: result.exitCode,
                    message: result.lastLine
                )
            }
            output = command.script.mode == .inline ? result.firstLine : result.output
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

public struct ScriptOutputView: View {
    @StateObject private var model: ScriptOutputViewModel
    @Environment(\.colorScheme) private var colorScheme

    public init(model: ScriptOutputViewModel) {
        _model = StateObject(wrappedValue: model)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: LauncherTheme.Metrics.footerGroupSpacing) {
            if model.command.script.mode == .inline {
                Text(model.output.isEmpty ? "Waiting for output" : model.output)
                    .font(LauncherTheme.Typography.search)
                    .foregroundStyle(LauncherTheme.Palette.primaryText(for: colorScheme))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                ScrollView {
                    Text(model.output.isEmpty ? "Waiting for output" : model.output)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(LauncherTheme.Palette.primaryText(for: colorScheme))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }

            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .font(LauncherTheme.Typography.footerTitle)
                    .foregroundStyle(.red)
            } else if model.isRunning {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(LauncherTheme.Metrics.searchHorizontalPadding)
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }
}

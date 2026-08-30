// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import SwiftUI

public struct LauncherView: View {
    @StateObject private var model: LauncherViewModel
    @ObservedObject private var toasts: ToastCenter

    @MainActor
    public init(
        registry: CommandRegistry,
        context: CommandContext,
        frecencyStore: FrecencyStore,
        keyEvents: LauncherKeyEvents,
        toasts: ToastCenter,
        onHide: @escaping (Bool) -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        _model = StateObject(wrappedValue: LauncherViewModel(
            registry: registry,
            context: context,
            frecencyStore: frecencyStore,
            keyEvents: keyEvents,
            onHide: onHide,
            onOpenSettings: onOpenSettings
        ))
        self.toasts = toasts
    }

    public var body: some View {
        ZStack {
            VisualEffectBackground(material: .hudWindow)

            VStack(spacing: 0) {
                LauncherSearchField(text: $model.query)
                    .frame(height: 52)
                    .padding(.horizontal, 16)

                Divider().opacity(0.45)

                resultList

                Divider().opacity(0.45)

                footer
            }

            if let message = toasts.message {
                VStack {
                    Spacer()
                    Text(message)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThickMaterial, in: Capsule())
                        .padding(.bottom, 48)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.easeOut(duration: 0.18), value: message)
            }
        }
        .frame(width: 750, height: 480)
        .preferredColorScheme(colorScheme)
    }

    private var resultList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    Text("Results")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .padding(.bottom, 2)

                    if model.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 260)
                    } else if model.results.isEmpty {
                        Text("No matching commands")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 260)
                    } else {
                        ForEach(Array(model.results.enumerated()), id: \.element.command.id) { index, result in
                            CommandRowView(
                                command: result.command,
                                isSelected: index == model.selectedIndex
                            )
                            .id(result.command.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                model.select(index)
                                model.executeSelected()
                            }
                            .onHover { hovering in
                                if hovering { model.select(index) }
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            .onChange(of: model.selectedIndex) {
                if let command = model.selectedCommand {
                    proxy.scrollTo(command.id, anchor: .center)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Text(model.selectedCommand?.title ?? "No selection")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            Button("Actions  ⌘K") {
                model.actionPanelVisible.toggle()
            }
            .buttonStyle(.plain)
            .popover(isPresented: $model.actionPanelVisible, arrowEdge: .bottom) {
                actionPanel
            }

            Text("Open  ↩")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
    }

    private var actionPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button("Open") { model.executeSelected() }
                .keyboardShortcut(.return, modifiers: [])

            if model.selectedCommand?.resourceURL != nil {
                Button("Show in Finder") { model.revealSelected() }
                Button("Copy path") { model.copySelectedPath() }
            }
        }
        .buttonStyle(.plain)
        .padding(12)
        .frame(width: 210, alignment: .leading)
    }

    private var colorScheme: ColorScheme? {
        nil
    }
}

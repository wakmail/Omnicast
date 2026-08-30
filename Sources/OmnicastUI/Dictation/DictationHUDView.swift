// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import SwiftUI

public struct DictationHUDView: View {
    @ObservedObject private var viewModel: DictationHUDViewModel

    public init(viewModel: DictationHUDViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Group {
            switch viewModel.state {
            case .idle:
                EmptyView()
            case .listening(let level):
                content(label: "Listening", level: level, active: true)
            case .transcribing:
                content(label: "Transcribing", level: 0.2, active: false)
            }
        }
    }

    private func content(label: String, level: Double, active: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: active ? "waveform" : "text.bubble")
                .foregroundStyle(active ? Color.red : Color.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                if !viewModel.partialTranscript.isEmpty {
                    Text(viewModel.partialTranscript)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            levelMeter(level)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: 320)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.white.opacity(0.14))
        }
        .shadow(color: .black.opacity(0.2), radius: 18, y: 8)
    }

    private func levelMeter(_ level: Double) -> some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                Capsule()
                    .fill(Double(index) / 5 < level ? Color.red : Color.secondary.opacity(0.25))
                    .frame(width: 3, height: CGFloat(5 + index * 3))
            }
        }
        .frame(width: 24)
    }
}

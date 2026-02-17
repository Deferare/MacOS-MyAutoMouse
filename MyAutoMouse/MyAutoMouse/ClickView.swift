//
//  ClickView.swift
//  MyAutoMouse
//
//  Created by JiHoon K on 2/17/26.
//

import SwiftUI

struct ClickView: View {
    @StateObject private var viewModel = ClickMacroViewModel()

    private var permissionStatus: PermissionStatus {
        viewModel.accessibilityGranted ? .granted : .notGranted
    }

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    HStack {
                        TextField("", text: $viewModel.intervalMilliseconds, prompt: Text("100"))
                            .labelsHidden()
                            .textFieldStyle(.roundedBorder)
                        Text("ms")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 100)
                } label: {
                    FormRowLabel("Interval", subtitle: "Time between clicks.", icon: "timer")
                }

                LabeledContent {
                    HStack {
                        TextField("", text: $viewModel.repeatCount, prompt: Text("0"))
                            .labelsHidden()
                            .textFieldStyle(.roundedBorder)
                        Text("times")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 100)
                } label: {
                    FormRowLabel("Repeat", subtitle: "0 for infinite.", icon: "repeat")
                }

                Picker(selection: $viewModel.mouseButton) {
                    ForEach(ClickMouseButton.allCases) { button in
                        Text(button.title).tag(button)
                    }
                } label: {
                    FormRowLabel("Button", subtitle: "Mouse button to use.", icon: "computermouse")
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Automation")
            }

            Section {
                Toggle(isOn: $viewModel.useFixedPosition) {
                    FormRowLabel(
                        "Fixed Position",
                        subtitle: "Capture records the cursor position after 3 seconds.",
                        icon: "scope"
                    )
                }

                if viewModel.useFixedPosition {
                    LabeledContent {
                        HStack {
                            Text(viewModel.savedPositionDescription)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(viewModel.savedPosition == nil ? .secondary : .primary)

                            Spacer()

                            Button {
                                viewModel.captureCurrentCursorPosition()
                            } label: {
                                Label(
                                    viewModel.isCaptureScheduled ? "Capturing..." : "Capture",
                                    systemImage: viewModel.isCaptureScheduled ? "hourglass" : "target"
                                )
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(!viewModel.canCapturePosition)
                        }
                    } label: {
                        Text("Current Position")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Position")
            }

            Section {
                HStack {
                    FormRowLabel(
                        "Accessibility",
                        subtitle: "Required for mouse automation.",
                        icon: "hand.raised.fill"
                    )
                    Spacer()

                    HStack(spacing: 8) {
                        Image(systemName: permissionStatus.icon)
                            .foregroundStyle(permissionStatus.color)

                        Text(permissionStatus.title)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(permissionStatus.color)

                        Button("Settings") {
                            viewModel.openAccessibilitySettings()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            } header: {
                Text("Status")
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomControlContainer {
                runControlBar
            }
        }
        .onAppear {
            viewModel.refreshAccessibilityStatus()
        }
    }

    private var runControlBar: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.statusMessage)
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(.primary)
                    .animation(.easeInOut, value: viewModel.statusMessage)

                if viewModel.isAutomationActive {
                    HStack(spacing: 8) {
                        ProgressView(value: viewModel.displayedProgressValue)
                            .progressViewStyle(.linear)
                            .frame(width: 100)
                            .tint(Color.accentColor)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.displayedProgressValue)

                        Text(viewModel.progressPercentageText)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Total clicks: \(viewModel.clickCount)")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                if viewModel.isAutomationActive {
                    viewModel.stop(reason: "Stopped")
                } else {
                    viewModel.start()
                }
            } label: {
                Label(
                    viewModel.primaryActionTitle,
                    systemImage: viewModel.primaryActionIcon
                )
                .frame(width: 80)
            }
            .keyboardShortcut(.return, modifiers: [])
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!viewModel.canTriggerPrimaryAction)
        }
    }

    private func bottomControlContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial)
            .overlay(Divider(), alignment: .top)
    }
}

private struct FormRowLabel: View {
    let title: String
    let subtitle: String?
    let icon: String?

    init(_ title: String, subtitle: String? = nil, icon: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 20)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.body, design: .rounded))
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(.caption2))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

private enum PermissionStatus {
    case granted
    case notGranted

    var title: String {
        switch self {
        case .granted: return "Granted"
        case .notGranted: return "Denied"
        }
    }

    var icon: String {
        switch self {
        case .granted: return "checkmark.circle.fill"
        case .notGranted: return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .granted: return .green
        case .notGranted: return .orange
        }
    }
}

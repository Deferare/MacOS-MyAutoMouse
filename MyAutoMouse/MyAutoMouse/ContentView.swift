//
//  ContentView.swift
//  MyAutoMouse
//
//  Created by JiHoon K on 2/17/26.
//

import SwiftUI
import AppKit
import Combine

struct ContentView: View {
    @State private var selection: AppSection = .click

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .symbolRenderingMode(.hierarchical)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 260)
        } detail: {
            NavigationStack {
                selectedSectionView
                    .navigationTitle(selection.title)
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private var selectedSectionView: some View {
        switch selection {
        case .click:
            ClickView()
        case .about:
            AboutView()
        }
    }
}

private enum AppSection: String, CaseIterable, Identifiable {
    case click
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .click:
            return "Click"
        case .about:
            return "About"
        }
    }

    var systemImage: String {
        switch self {
        case .click:
            return "cursorarrow.click"
        case .about:
            return "info.circle"
        }
    }
}

private struct ClickView: View {
    @StateObject private var viewModel = ClickMacroViewModel()

    private var permissionStatus: PermissionStatus {
        viewModel.accessibilityGranted ? .granted : .notGranted
    }

    var body: some View {
        Form {
            Section("Click Macro") {
                HStack(alignment: .center) {
                    FormRowLabel(
                        "Interval (ms)",
                        subtitle: "Time between clicks in milliseconds."
                    )
                    Spacer()
                    TextField("", text: $viewModel.intervalMilliseconds, prompt: Text("500"))
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .multilineTextAlignment(.trailing)
                    .frame(width: 220, alignment: .trailing)
                }

                HStack(alignment: .center) {
                    FormRowLabel(
                        "Repeat Count",
                        subtitle: "Set 0 to run continuously."
                    )
                    Spacer()
                    TextField("", text: $viewModel.repeatCount, prompt: Text("0"))
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 220, alignment: .trailing)
                }

                HStack(alignment: .center) {
                    FormRowLabel(
                        "Button",
                        subtitle: "Choose the mouse button to automate."
                    )
                    Spacer()
                    Picker("", selection: $viewModel.mouseButton) {
                        ForEach(ClickMouseButton.allCases) { button in
                            Text(button.title).tag(button)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 220, alignment: .trailing)
                }
            }

            Section("Position") {
                Toggle(isOn: $viewModel.useFixedPosition) {
                    FormRowLabel(
                        "Use Fixed Position",
                        subtitle: "Click a saved coordinate instead of the current cursor location."
                    )
                }
                .toggleStyle(.switch)

                LabeledContent {
                    Text(viewModel.savedPositionDescription)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                } label: {
                    FormRowLabel(
                        "Saved Position",
                        subtitle: "Capture once, then reuse this coordinate."
                    )
                }

                HStack(alignment: .center) {
                    FormRowLabel(
                        "Capture Cursor",
                        subtitle: "Save the current cursor location."
                    )
                    Spacer()
                    Button("Capture") {
                        viewModel.captureCurrentCursorPosition()
                    }
                    .disabled(viewModel.isRunning)
                }
            }

            Section("Run") {
                HStack(alignment: .center) {
                    FormRowLabel(
                        "Controls",
                        subtitle: "Start begins immediately. Stop halts the macro."
                    )
                    Spacer()
                    HStack(spacing: 8) {
                        Button("Start") {
                            viewModel.start()
                        }
                        .keyboardShortcut(.return, modifiers: [])
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isRunning)

                        Button("Stop") {
                            viewModel.stop(reason: "Stopped by user.")
                        }
                        .disabled(!viewModel.isRunning)
                    }
                }

                LabeledContent {
                    Text("\(viewModel.clickCount)")
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                } label: {
                    FormRowLabel(
                        "Clicks Sent",
                        subtitle: "Number of click events posted in this run."
                    )
                }

                FormHelpText(text: viewModel.statusMessage, leadingPadding: 0)
            }

            Section("Permissions") {
                HStack(alignment: .center) {
                    FormRowLabel(
                        "Accessibility",
                        subtitle: "Required to post synthetic mouse events."
                    )
                    Spacer()
                    PermissionStatusBadge(status: permissionStatus)
                    Button("Request…") {
                        viewModel.requestAccessibilityPermission()
                    }
                }

                HStack(alignment: .center) {
                    FormRowLabel(
                        "System Settings",
                        subtitle: "Open Privacy & Security > Accessibility."
                    )
                    Spacer()
                    Button("Open…") {
                        viewModel.openAccessibilitySettings()
                    }
                }
            }
        }
        .onAppear {
            viewModel.refreshAccessibilityStatus()
        }
    }
}

private struct FormRowLabel: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .alignmentGuide(.firstTextBaseline) { dimensions in
            dimensions[VerticalAlignment.center]
        }
    }
}

private struct FormHelpText: View {
    let text: String
    var leadingPadding: CGFloat = 24

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.leading, leadingPadding)
    }
}

private struct PermissionStatusBadge: View {
    let status: PermissionStatus

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: status.icon)
            Text(status.title)
        }
        .foregroundStyle(status.color)
    }
}

private enum PermissionStatus {
    case granted
    case notGranted

    var title: String {
        switch self {
        case .granted:
            return "Granted"
        case .notGranted:
            return "Not granted"
        }
    }

    var icon: String {
        switch self {
        case .granted:
            return "checkmark.circle.fill"
        case .notGranted:
            return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .granted:
            return .green
        case .notGranted:
            return .orange
        }
    }
}

@MainActor
private final class ClickMacroViewModel: ObservableObject {
    @Published var intervalMilliseconds: String = "500"
    @Published var repeatCount: String = "0"
    @Published var mouseButton: ClickMouseButton = .left
    @Published var useFixedPosition = false
    @Published private(set) var clickCount = 0
    @Published private(set) var isRunning = false
    @Published private(set) var accessibilityGranted = AXIsProcessTrusted()
    @Published private(set) var statusMessage = "Ready."
    @Published private(set) var savedPosition: CGPoint?

    private var timer: DispatchSourceTimer?

    var savedPositionDescription: String {
        guard let savedPosition else {
            return "No saved position."
        }
        return "X: \(Int(savedPosition.x)), Y: \(Int(savedPosition.y))"
    }

    func refreshAccessibilityStatus() {
        accessibilityGranted = AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() {
        accessibilityGranted = checkAccessibilityPermission(prompt: true)
        if accessibilityGranted {
            statusMessage = "Accessibility permission granted."
        } else {
            statusMessage = "Allow accessibility access in System Settings > Privacy & Security > Accessibility."
        }
    }

    func openAccessibilitySettings() {
        guard let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(settingsURL)
    }

    func captureCurrentCursorPosition() {
        guard let currentPosition = CGEvent(source: nil)?.location else {
            statusMessage = "Could not read current cursor position."
            return
        }
        savedPosition = currentPosition
        statusMessage = "Saved current cursor position."
    }

    func start() {
        guard !isRunning else { return }

        guard let interval = Int(intervalMilliseconds), interval > 0 else {
            statusMessage = "Interval must be a number greater than 0."
            return
        }

        guard let repeatTarget = Int(repeatCount), repeatTarget >= 0 else {
            statusMessage = "Repeat count must be 0 or greater."
            return
        }

        if useFixedPosition && savedPosition == nil {
            statusMessage = "Capture a cursor position first, or disable fixed position."
            return
        }

        accessibilityGranted = checkAccessibilityPermission(prompt: true)
        guard accessibilityGranted else {
            statusMessage = "Accessibility permission is required before starting."
            return
        }

        clickCount = 0
        isRunning = true
        statusMessage = repeatTarget == 0 ? "Running. (infinite)" : "Running. (\(repeatTarget) clicks)"

        let selectedButton = mouseButton
        let fixedPosition = useFixedPosition ? savedPosition : nil
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInteractive))

        timer.schedule(deadline: .now(), repeating: .milliseconds(interval))
        timer.setEventHandler { [weak self] in
            guard let self else { return }

            let position = fixedPosition ?? CGEvent(source: nil)?.location ?? .zero
            self.postClick(at: position, button: selectedButton)

            DispatchQueue.main.async {
                guard self.isRunning else { return }
                self.clickCount += 1

                if repeatTarget > 0, self.clickCount >= repeatTarget {
                    self.stop(reason: "Completed \(repeatTarget) clicks.")
                }
            }
        }

        self.timer = timer
        timer.resume()
    }

    func stop(reason: String = "Stopped.") {
        timer?.cancel()
        timer = nil

        if isRunning {
            statusMessage = reason
        }
        isRunning = false
    }

    private func checkAccessibilityPermission(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private func postClick(at position: CGPoint, button: ClickMouseButton) {
        guard
            let mouseDown = CGEvent(
                mouseEventSource: nil,
                mouseType: button.downEventType,
                mouseCursorPosition: position,
                mouseButton: button.cgButton
            ),
            let mouseUp = CGEvent(
                mouseEventSource: nil,
                mouseType: button.upEventType,
                mouseCursorPosition: position,
                mouseButton: button.cgButton
            )
        else {
            return
        }

        mouseDown.post(tap: .cghidEventTap)
        mouseUp.post(tap: .cghidEventTap)
    }

    deinit {
        timer?.cancel()
    }
}

private enum ClickMouseButton: String, CaseIterable, Identifiable {
    case left
    case right

    var id: Self { self }

    var title: String {
        switch self {
        case .left:
            return "Left"
        case .right:
            return "Right"
        }
    }

    var cgButton: CGMouseButton {
        switch self {
        case .left:
            return .left
        case .right:
            return .right
        }
    }

    var downEventType: CGEventType {
        switch self {
        case .left:
            return .leftMouseDown
        case .right:
            return .rightMouseDown
        }
    }

    var upEventType: CGEventType {
        switch self {
        case .left:
            return .leftMouseUp
        case .right:
            return .rightMouseUp
        }
    }
}

private struct AboutView: View {
    var body: some View {
        Form {
            Section("MyAutoMouse") {
                FormRowLabel(
                    "MyAutoMouse",
                    subtitle: "A macOS mouse macro utility focused on auto-click workflows."
                )
                FormRowLabel(
                    "Permissions",
                    subtitle: "Accessibility permission is required for posting mouse events."
                )
                FormRowLabel(
                    "Usage",
                    subtitle: "Set interval and repeat count, then start the click macro."
                )
            }
        }
    }
}

#Preview {
    ContentView()
}

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
                    TextField("", text: $viewModel.intervalMilliseconds, prompt: Text("100"))
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
                    TextField("", text: $viewModel.repeatCount, prompt: Text("100"))
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
                    .disabled(viewModel.isRunning || viewModel.isStartScheduled)
                }
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
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .lastTextBaseline) {
                    Text(viewModel.statusMessage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()

                    Text(viewModel.progressPercentageText)
                        .font(.system(.caption, design: .monospaced).weight(.bold))
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: viewModel.displayedProgressValue, total: 1.0)
                    .progressViewStyle(.linear)
                    .tint(progressTint)
                    .scaleEffect(x: 1, y: 2, anchor: .center)
                    .clipShape(Capsule())
                    .animation(.spring(), value: viewModel.displayedProgressValue)
            }

            Button {
                if viewModel.isRunning || viewModel.isStartScheduled {
                    viewModel.stop(reason: "Stopped by user.")
                } else {
                    viewModel.start()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: (viewModel.isRunning || viewModel.isStartScheduled) ? "stop.fill" : "play.fill")
                        .font(.system(size: 14, weight: .black))
                    Text((viewModel.isRunning || viewModel.isStartScheduled) ? "Stop" : "Start")
                        .font(.system(size: 14, weight: .bold))
                }
                .frame(minWidth: 130, minHeight: 44)
            }
            .keyboardShortcut(.return, modifiers: [])
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled((viewModel.isRunning || viewModel.isStartScheduled) ? false : !viewModel.canStart)
        }
    }

    private var progressTint: Color {
        viewModel.displayedProgressValue > 0 ? .accentColor : .clear
    }

    private func bottomControlContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(.ultraThinMaterial)
            .overlay(Rectangle().frame(height: 1).foregroundStyle(.primary.opacity(0.05)), alignment: .top)
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
    private let startDelaySeconds = 3

    @Published var intervalMilliseconds: String = "100"
    @Published var repeatCount: String = "100"
    @Published var mouseButton: ClickMouseButton = .left
    @Published var useFixedPosition = false
    @Published private(set) var clickCount = 0
    @Published private(set) var currentRunTargetCount = 0
    @Published private(set) var isRunning = false
    @Published private(set) var isStartScheduled = false
    @Published private(set) var accessibilityGranted = AXIsProcessTrusted()
    @Published private(set) var statusMessage = "Start waits 3 seconds before running."
    @Published private(set) var savedPosition: CGPoint?

    private var timer: DispatchSourceTimer?
    private var delayedStartTask: Task<Void, Never>?

    var canStart: Bool {
        guard !isRunning, !isStartScheduled else {
            return false
        }
        guard parsedInterval != nil, parsedRepeatTarget != nil else {
            return false
        }
        if useFixedPosition && savedPosition == nil {
            return false
        }
        return true
    }

    var displayedProgressValue: Double {
        let target = currentProgressTarget
        guard target > 0 else {
            return 0
        }
        return min(Double(clickCount) / Double(target), 1)
    }

    var progressPercentageText: String {
        let target = currentProgressTarget
        guard target > 0 else {
            return "∞"
        }
        return "\(Int((displayedProgressValue * 100).rounded()))%"
    }

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
        guard !isRunning, !isStartScheduled else { return }

        guard let interval = parsedInterval else {
            statusMessage = "Interval must be a number greater than 0."
            return
        }

        guard let repeatTarget = parsedRepeatTarget else {
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

        scheduleDelayedStart(interval: interval, repeatTarget: repeatTarget)
    }

    func stop(reason: String = "Stopped.") {
        let wasRunning = isRunning
        let wasScheduled = isStartScheduled

        delayedStartTask?.cancel()
        delayedStartTask = nil
        isStartScheduled = false

        timer?.cancel()
        timer = nil
        isRunning = false

        if wasRunning || wasScheduled {
            statusMessage = reason
        }
    }

    private var parsedInterval: Int? {
        guard let interval = Int(intervalMilliseconds), interval > 0 else {
            return nil
        }
        return interval
    }

    private var parsedRepeatTarget: Int? {
        guard let repeatTarget = Int(repeatCount), repeatTarget >= 0 else {
            return nil
        }
        return repeatTarget
    }

    private var currentProgressTarget: Int {
        if currentRunTargetCount > 0 || isRunning || isStartScheduled || clickCount > 0 {
            return currentRunTargetCount
        }
        return parsedRepeatTarget ?? 0
    }

    private func scheduleDelayedStart(interval: Int, repeatTarget: Int) {
        delayedStartTask?.cancel()
        timer?.cancel()
        timer = nil

        clickCount = 0
        currentRunTargetCount = repeatTarget
        isStartScheduled = true
        statusMessage = "Starting in \(startDelaySeconds)s..."

        let selectedButton = mouseButton
        let fixedPosition = useFixedPosition ? savedPosition : nil

        delayedStartTask = Task { [weak self] in
            guard let self else { return }

            for remaining in stride(from: self.startDelaySeconds, through: 1, by: -1) {
                self.statusMessage = "Starting in \(remaining)s..."
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }
                if Task.isCancelled {
                    return
                }
            }

            if Task.isCancelled {
                return
            }

            self.isStartScheduled = false
            self.beginClickRun(interval: interval, repeatTarget: repeatTarget, button: selectedButton, fixedPosition: fixedPosition)
        }
    }

    private func beginClickRun(interval: Int, repeatTarget: Int, button: ClickMouseButton, fixedPosition: CGPoint?) {
        isRunning = true
        statusMessage = repeatTarget == 0 ? "Running. (infinite)" : "Running. (\(repeatTarget) clicks)"

        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInteractive))
        timer.schedule(deadline: .now(), repeating: .milliseconds(interval))
        timer.setEventHandler { [weak self] in
            guard let self else { return }

            let position = fixedPosition ?? CGEvent(source: nil)?.location ?? .zero
            self.postClick(at: position, button: button)

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
        delayedStartTask?.cancel()
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

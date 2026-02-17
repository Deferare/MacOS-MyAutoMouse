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
            Section {
                LabeledContent {
                    HStack {
                        TextField("", text: $viewModel.intervalMilliseconds, prompt: Text("100"))
                            .labelsHidden()
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                        
                        Stepper("", value: Binding(get: {
                            Int(viewModel.intervalMilliseconds) ?? 100
                        }, set: {
                            viewModel.intervalMilliseconds = String($0)
                        }), in: 10...10000, step: 10)
                        .labelsHidden()
                    }
                } label: {
                    FormRowLabel("Interval (ms)", subtitle: "Time between clicks in milliseconds.")
                }

                LabeledContent {
                    HStack {
                        TextField("", text: $viewModel.repeatCount, prompt: Text("100"))
                            .labelsHidden()
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                        
                        Stepper("", value: Binding(get: {
                            Int(viewModel.repeatCount) ?? 100
                        }, set: {
                            viewModel.repeatCount = String($0)
                        }), in: 0...1000000, step: 100)
                        .labelsHidden()
                    }
                } label: {
                    FormRowLabel("Repeat Count", subtitle: "Set 0 to run continuously.")
                }

                Picker(selection: $viewModel.mouseButton) {
                    ForEach(ClickMouseButton.allCases) { button in
                        Text(button.title).tag(button)
                    }
                } label: {
                    FormRowLabel("Button", subtitle: "Choose the mouse button to automate.")
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Click Macro")
            }

            Section {
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
                } label: {
                    FormRowLabel(
                        "Saved Position",
                        subtitle: "Capture once, then reuse this coordinate."
                    )
                }

                HStack {
                    FormRowLabel(
                        "Capture Cursor",
                        subtitle: "Save the current cursor location."
                    )
                    Spacer()
                    Button("Capture") {
                        viewModel.captureCurrentCursorPosition()
                    }
                    .disabled(viewModel.isRunning || viewModel.isStartScheduled)
                    .buttonStyle(.bordered)
                }
            } header: {
                Text("Position")
            }

            Section {
                HStack {
                    FormRowLabel(
                        "Accessibility",
                        subtitle: "Required to post synthetic mouse events."
                    )
                    Spacer()
                    PermissionStatusBadge(status: permissionStatus)
                    Button("Request…") {
                        viewModel.requestAccessibilityPermission()
                    }
                    .buttonStyle(.bordered)
                }

                HStack {
                    FormRowLabel(
                        "System Settings",
                        subtitle: "Open Privacy & Security > Accessibility."
                    )
                    Spacer()
                    Button("Open…") {
                        viewModel.openAccessibilitySettings()
                    }
                    .buttonStyle(.bordered)
                }
            } header: {
                Text("Permissions")
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
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .lastTextBaseline) {
                    Text(viewModel.statusMessage)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle((viewModel.isRunning || viewModel.isStartScheduled) ? .primary : .secondary)
                        .animation(.default, value: viewModel.statusMessage)

                    Spacer()

                    if viewModel.currentRunTargetCount > 0 {
                        Text(viewModel.progressPercentageText)
                            .font(.system(size: 10, design: .monospaced).weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }

                ProgressView(value: viewModel.displayedProgressValue, total: 1.0)
                    .progressViewStyle(.linear)
                    .tint(Color.accentColor)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.displayedProgressValue)
            }

            Button {
                if viewModel.isRunning || viewModel.isStartScheduled {
                    viewModel.stop(reason: "Stopped by user.")
                } else {
                    viewModel.start()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: (viewModel.isRunning || viewModel.isStartScheduled) ? "stop.fill" : "play.fill")
                        .imageScale(.small)
                    Text((viewModel.isRunning || viewModel.isStartScheduled) ? "Stop" : "Start")
                        .font(.headline)
                }
                .frame(width: 100, height: 32)
            }
            .keyboardShortcut(.return, modifiers: [])
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled((viewModel.isRunning || viewModel.isStartScheduled) ? false : !viewModel.canStart)
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

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.body)
            
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct PermissionStatusBadge: View {
    let status: PermissionStatus

    var body: some View {
        Label(status.title, systemImage: status.icon)
            .font(.caption.weight(.medium))
            .foregroundStyle(status.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(status.color.opacity(0.1))
            .clipShape(Capsule())
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
    @Published private(set) var statusMessage = "Ready to start."
    @Published private(set) var savedPosition: CGPoint?

    private var timer: DispatchSourceTimer?
    private var delayedStartTask: Task<Void, Never>?

    var canStart: Bool {
        guard !isRunning, !isStartScheduled else {
            return false
        }
        guard let interval = Int(intervalMilliseconds), interval > 0 else {
            return false
        }
        guard let repeatTarget = Int(repeatCount), repeatTarget >= 0 else {
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
            return isRunning ? 1.0 : 0.0
        }
        return min(Double(clickCount) / Double(target), 1)
    }

    var progressPercentageText: String {
        let target = currentProgressTarget
        guard target > 0 else {
            return ""
        }
        return "\(Int((displayedProgressValue * 100).rounded()))%"
    }

    var savedPositionDescription: String {
        guard let savedPosition else {
            return "No saved position."
        }
        return "\(Int(savedPosition.x)), \(Int(savedPosition.y))"
    }

    func refreshAccessibilityStatus() {
        accessibilityGranted = AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() {
        accessibilityGranted = checkAccessibilityPermission(prompt: true)
        if accessibilityGranted {
            statusMessage = "Permission granted."
        } else {
            statusMessage = "Accessibility denied."
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
            statusMessage = "Capture failed."
            return
        }
        savedPosition = currentPosition
        statusMessage = "Position captured."
    }

    func start() {
        guard !isRunning, !isStartScheduled else { return }

        guard let interval = Int(intervalMilliseconds), interval > 0 else {
            statusMessage = "Invalid interval."
            return
        }

        guard let repeatTarget = Int(repeatCount), repeatTarget >= 0 else {
            statusMessage = "Invalid repeat count."
            return
        }

        if useFixedPosition && savedPosition == nil {
            statusMessage = "Capture position first."
            return
        }

        accessibilityGranted = checkAccessibilityPermission(prompt: true)
        guard accessibilityGranted else {
            statusMessage = "Permission required."
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

    private var currentProgressTarget: Int {
        if currentRunTargetCount > 0 || isRunning || isStartScheduled || clickCount > 0 {
            return currentRunTargetCount
        }
        return Int(repeatCount) ?? 0
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
        statusMessage = repeatTarget == 0 ? "Running..." : "Running (\(repeatTarget) clicks)"

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
                    self.stop(reason: "Finished.")
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
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "cursorarrow.click.badge.clock")
                .font(.system(size: 72))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
            
            VStack(spacing: 8) {
                Text("MyAutoMouse")
                    .font(.title.bold())
                
                Text("Version 1.0.0")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Text("A minimalist mouse macro utility for macOS.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Divider()
                .frame(width: 200)
            
            VStack(alignment: .leading, spacing: 12) {
                AboutBullet(icon: "lock.shield", text: "Requires Accessibility permission")
                AboutBullet(icon: "cursorarrow.rays", text: "Supports fixed or relative clicks")
                AboutBullet(icon: "timer", text: "Adjustable interval and repeat count")
            }
            
            Spacer()
        }
        .padding()
    }
}

private struct AboutBullet: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    ContentView()
}

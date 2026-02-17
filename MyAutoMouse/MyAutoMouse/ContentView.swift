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
                        subtitle: "Click at a specific screen coordinate.",
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
                                Label("Capture", systemImage: "target")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(viewModel.isRunning || viewModel.isStartScheduled)
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
                
                if viewModel.isRunning || viewModel.isStartScheduled {
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
                if viewModel.isRunning || viewModel.isStartScheduled {
                    viewModel.stop(reason: "Stopped")
                } else {
                    viewModel.start()
                }
            } label: {
                Label(
                    (viewModel.isRunning || viewModel.isStartScheduled) ? "Stop" : "Start",
                    systemImage: (viewModel.isRunning || viewModel.isStartScheduled) ? "stop.fill" : "play.fill"
                )
                .frame(width: 80)
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
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Image(systemName: "cursorarrow.click.badge.clock")
                        .font(.system(size: 64))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.accentColor)
                        .padding(.top, 40)
                    
                    VStack(spacing: 4) {
                        Text("MyAutoMouse")
                            .font(.system(.title, design: .rounded).bold())
                        
                        Text("Version 1.0.0")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                
                Text("A simple, minimalist mouse macro utility\ndesigned for efficiency on macOS.")
                    .font(.system(.subheadline, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)
                
                VStack(alignment: .leading, spacing: 16) {
                    AboutBullet(icon: "lock.shield.fill", text: "Securely interacts with accessibility services.")
                    AboutBullet(icon: "cursorarrow.rays", text: "Supports multiple mouse buttons and positions.")
                    AboutBullet(icon: "timer", text: "Precision timing for automation tasks.")
                }
                .padding(.vertical, 8)
                
                Divider()
                    .frame(width: 100)
                
                Text("© 2026 JiHoon K.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 40)
            }
        }
    }
}

private struct AboutBullet: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24, height: 24)
            
            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.primary)
        }
    }
}

#Preview {
    ContentView()
}

//
//  ClickMacroViewModel.swift
//  MyAutoMouse
//
//  Created by JiHoon K on 2/17/26.
//

import AppKit
import Combine

@MainActor
final class ClickMacroViewModel: ObservableObject {
    private let startDelaySeconds = 3
    private let captureDelaySeconds = 3

    @Published var intervalMilliseconds: String = "100"
    @Published var repeatCount: String = "100"
    @Published var mouseButton: ClickMouseButton = .left
    @Published var useFixedPosition = false
    @Published private(set) var clickCount = 0
    @Published private(set) var currentRunTargetCount = 0
    @Published private(set) var isRunning = false
    @Published private(set) var isStartScheduled = false
    @Published private(set) var isCaptureScheduled = false
    @Published private(set) var accessibilityGranted = AXIsProcessTrusted()
    @Published private(set) var statusMessage = "Ready to start."
    @Published private(set) var savedPosition: CGPoint?

    private var timer: DispatchSourceTimer?
    private var delayedStartTask: Task<Void, Never>?
    private var delayedCaptureTask: Task<Void, Never>?

    var isAutomationActive: Bool {
        isRunning || isStartScheduled
    }

    var canCapturePosition: Bool {
        !isAutomationActive && !isCaptureScheduled
    }

    var primaryActionTitle: String {
        isAutomationActive ? "Stop" : "Start"
    }

    var primaryActionIcon: String {
        isAutomationActive ? "stop.fill" : "play.fill"
    }

    var canTriggerPrimaryAction: Bool {
        isAutomationActive || canStart
    }

    var canStart: Bool {
        guard !isAutomationActive, !isCaptureScheduled else {
            return false
        }
        guard parsedIntervalMilliseconds != nil else {
            return false
        }
        guard parsedRepeatCount != nil else {
            return false
        }
        return !useFixedPosition || savedPosition != nil
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

    func openAccessibilitySettings() {
        guard let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(settingsURL)
    }

    func captureCurrentCursorPosition() {
        guard !isCaptureScheduled else {
            return
        }

        isCaptureScheduled = true
        delayedCaptureTask = Task { [weak self] in
            guard let self else { return }
            defer {
                self.isCaptureScheduled = false
                self.delayedCaptureTask = nil
            }

            let didFinishCountdown = await self.runCountdown(seconds: self.captureDelaySeconds) {
                "Capturing in \($0)s..."
            }
            guard didFinishCountdown else {
                return
            }

            guard let currentPosition = CGEvent(source: nil)?.location else {
                self.statusMessage = "Capture failed."
                return
            }
            self.savedPosition = currentPosition
            self.statusMessage = "Position captured."
        }
    }

    func start() {
        guard let startInput = validatedStartInput() else {
            return
        }

        accessibilityGranted = checkAccessibilityPermission(prompt: true)
        guard accessibilityGranted else {
            statusMessage = "Permission required."
            return
        }

        scheduleDelayedStart(interval: startInput.interval, repeatTarget: startInput.repeatTarget)
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
        if currentRunTargetCount > 0 || isAutomationActive || clickCount > 0 {
            return currentRunTargetCount
        }
        return parsedRepeatCount ?? 0
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

            let didFinishCountdown = await self.runCountdown(seconds: self.startDelaySeconds) {
                "Starting in \($0)s..."
            }
            guard didFinishCountdown else {
                return
            }

            self.isStartScheduled = false
            self.beginClickRun(interval: interval, repeatTarget: repeatTarget, button: selectedButton, fixedPosition: fixedPosition)
        }
    }

    private var parsedIntervalMilliseconds: Int? {
        guard let interval = Int(intervalMilliseconds), interval > 0 else {
            return nil
        }
        return interval
    }

    private var parsedRepeatCount: Int? {
        guard let target = Int(repeatCount), target >= 0 else {
            return nil
        }
        return target
    }

    private func validatedStartInput() -> (interval: Int, repeatTarget: Int)? {
        guard !isCaptureScheduled else {
            statusMessage = "Wait for capture to finish."
            return nil
        }

        guard !isAutomationActive else {
            return nil
        }

        guard let interval = parsedIntervalMilliseconds else {
            statusMessage = "Invalid interval."
            return nil
        }

        guard let repeatTarget = parsedRepeatCount else {
            statusMessage = "Invalid repeat count."
            return nil
        }

        guard !useFixedPosition || savedPosition != nil else {
            statusMessage = "Capture position first."
            return nil
        }

        return (interval, repeatTarget)
    }

    private func runCountdown(seconds: Int, statusBuilder: (Int) -> String) async -> Bool {
        guard seconds > 0 else {
            return true
        }

        for remaining in stride(from: seconds, through: 1, by: -1) {
            statusMessage = statusBuilder(remaining)
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return false
            }
            if Task.isCancelled {
                return false
            }
        }

        return !Task.isCancelled
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
        delayedCaptureTask?.cancel()
        delayedStartTask?.cancel()
        timer?.cancel()
    }
}

enum ClickMouseButton: String, CaseIterable, Identifiable {
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

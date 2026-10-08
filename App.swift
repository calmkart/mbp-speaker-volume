import AppKit
import Foundation

@MainActor
final class VolumePanel: NSViewController {
    private let audio = SpeakerAudio()
    private let slider = NSSlider(value: 0, minValue: 0, maxValue: 100, target: nil, action: nil)
    private let percentage = NSTextField(labelWithString: "—")
    private let message = NSTextField(labelWithString: "仅调节内置扬声器")
    private var timer: Timer?

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 142))
        let title = NSTextField(labelWithString: "MacBook Pro 扬声器")
        title.font = .systemFont(ofSize: 14, weight: .semibold)
        title.setContentCompressionResistancePriority(.required, for: .horizontal)
        percentage.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        percentage.alignment = .right
        percentage.textColor = .secondaryLabelColor
        let heading = NSStackView(views: [title, NSView(), percentage])
        heading.orientation = .horizontal

        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(volumeChanged)
        slider.setAccessibilityLabel("内置扬声器音量")
        slider.setAccessibilityHelp("仅调整 MacBook Pro 扬声器，不切换输出设备")

        message.font = .systemFont(ofSize: 11)
        message.textColor = .secondaryLabelColor
        message.lineBreakMode = .byTruncatingTail
        let quit = NSButton(title: "退出", target: NSApp, action: #selector(NSApplication.terminate(_:)))
        quit.isBordered = false
        quit.font = .systemFont(ofSize: 11)
        quit.contentTintColor = .secondaryLabelColor
        let footer = NSStackView(views: [message, NSView(), quit])
        footer.orientation = .horizontal

        let stack = NSStackView(views: [heading, slider, footer])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 17
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            heading.widthAnchor.constraint(equalTo: stack.widthAnchor),
            slider.widthAnchor.constraint(equalTo: stack.widthAnchor),
            footer.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        refresh()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                if NSEvent.pressedMouseButtons == 0 { self?.refresh() }
            }
        }
    }

    override func viewDidDisappear() {
        timer?.invalidate()
        timer = nil
        super.viewDidDisappear()
    }

    private func refresh() {
        do {
            let snapshot = try audio.snapshot()
            slider.doubleValue = Double(snapshot.volume) * 100
            percentage.stringValue = "\(Int((snapshot.volume * 100).rounded()))%"
            slider.isEnabled = true
            message.stringValue = "仅调节内置扬声器"
            message.toolTip = "当前系统输出：\(snapshot.defaultOutput)"
        } catch {
            slider.isEnabled = false
            percentage.stringValue = "—"
            message.stringValue = error.localizedDescription
        }
    }

    @objc private func volumeChanged() {
        do {
            try audio.setVolume(Float32(slider.doubleValue / 100))
            percentage.stringValue = "\(Int(slider.doubleValue.rounded()))%"
            message.stringValue = "仅调节内置扬声器"
        } catch {
            message.stringValue = error.localizedDescription
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var item: NSStatusItem!
    private let popover = NSPopover()

    func applicationDidFinishLaunching(_ notification: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = "MBPSpeakerVolume"
        item.button?.title = "MBP"
        item.button?.image = NSImage(systemSymbolName: "speaker.wave.2", accessibilityDescription: "MBP 音量")
        item.button?.imagePosition = .imageLeading
        item.button?.toolTip = "单独调节 MacBook Pro 扬声器音量"
        item.button?.setAccessibilityLabel("MBP 扬声器音量")
        item.button?.target = self
        item.button?.action = #selector(togglePanel)
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 300, height: 142)
        popover.contentViewController = VolumePanel()
        if CommandLine.arguments.contains("--show") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.showPanel() }
        }
    }

    private func showPanel() {
        guard let button = item.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    @objc private func togglePanel() {
        if popover.isShown { popover.performClose(nil) } else { showPanel() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPanel()
        return false
    }
}

@main
struct SpeakerVolumeApp {
    @MainActor static func main() throws {
        if CommandLine.arguments.contains("--check") {
            let audio = SpeakerAudio()
            let before = try audio.snapshot()
            // Verify the setter with the existing value: no audible change.
            try audio.setVolume(before.volume)
            let after = try audio.snapshot()
            guard before.defaultOutput == after.defaultOutput,
                  abs(before.volume - after.volume) < 0.001 else {
                throw SpeakerError.unavailable(-1)
            }
            print(String(data: try JSONEncoder().encode(after), encoding: .utf8)!)
            return
        }
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        if let index = CommandLine.arguments.firstIndex(of: "--render"),
           CommandLine.arguments.indices.contains(index + 1) {
            let panel = VolumePanel()
            panel.loadView()
            panel.view.wantsLayer = true
            panel.view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            panel.view.layoutSubtreeIfNeeded()
            guard let bitmap = panel.view.bitmapImageRepForCachingDisplay(in: panel.view.bounds) else { return }
            panel.view.cacheDisplay(in: panel.view.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])?.write(
                to: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
            return
        }
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

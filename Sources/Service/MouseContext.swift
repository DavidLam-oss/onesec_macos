import AppKit
import Combine

class MouseContextService: @unchecked Sendable {
    static let shared = MouseContextService()

    @Published var mouseContextState: [NSEvent.EventType: (position: NSPoint, screen: NSScreen)] = [:]
    private var isRecordingActive = false
    private var mouseUpMonitor: Any?
    private var mouseDownMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupMouseMonitors()
        setupEventListeners()
    }

    deinit {
        if let monitor = mouseUpMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = mouseDownMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func setupMouseMonitors() {
        mouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            guard let self, !self.isRecordingActive else { return }
            self.mouseContextState.removeAll()
            self.saveMouseContext(type: .leftMouseDown)
        }

        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            guard let self, !self.isRecordingActive else { return }
            self.saveMouseContext(type: .leftMouseUp)
        }
    }

    private func setupEventListeners() {
        EventBus.shared.eventSubject
            .sink { [weak self] event in
                guard let self else { return }
                if case .recordingStarted = event {
                    if self.mouseContextState[.leftMouseUp] == nil {
                        self.saveMouseContext(type: .leftMouseUp)
                    }
                    self.isRecordingActive = true
                }
            }
            .store(in: &cancellables)
        
        EventBus.shared.recordingSessionEnded
            .sink { [weak self] in
                self?.isRecordingActive = false
            }
            .store(in: &cancellables)
    }

    private func saveMouseContext(type: NSEvent.EventType) {
        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) else {
            return
        }

        mouseContextState[type] = (position: mouseLocation, screen: screen)
    }

    func getMouseRect() -> NSRect? {
        guard let mouseDown = mouseContextState[.leftMouseDown],
              let mouseUp = mouseContextState[.leftMouseUp]
        else {
            return nil
        }

        let screenFrame = mouseUp.screen.frame
        let screenHeight = screenFrame.height

        let downAxY = screenHeight - (mouseDown.position.y - screenFrame.origin.y)
        let upAxY = screenHeight - (mouseUp.position.y - screenFrame.origin.y)

        let minX = min(mouseDown.position.x, mouseUp.position.x) - screenFrame.origin.x
        let maxX = max(mouseDown.position.x, mouseUp.position.x) - screenFrame.origin.x
        let minY = min(downAxY, upAxY)
        let maxY = max(downAxY, upAxY)

        return NSRect(x: minX, y: minY, width: max(maxX - minX, 1), height: max(maxY - minY, 1))
    }

    func getMouseScreen() -> NSScreen? {
        mouseContextState[.leftMouseUp]?.screen
    }

    func getMousePoint(type: NSEvent.EventType) -> NSPoint? {
        mouseContextState[type]?.position
    }
}

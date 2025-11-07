import Cocoa
import Combine
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate {
    var connectionCenter: ConnectionCenter!

    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_: Notification) {
        CommandParser.main()
        SoundService.shared.initialize()
        SignalHandler.shared.setupSignalHandlers()

        connectionCenter = ConnectionCenter.shared
        connectionCenter.initialize()

        StatusPanelManager.shared.showPanel()
        Task { @MainActor in
            //  AXSelectionObserver.shared.startObserving()
            // try? await Task.sleep(nanoseconds: 1_000_000_000)
            // EventBus.shared.publish(.notificationReceived(.recordingFailed))
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

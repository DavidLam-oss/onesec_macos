import Foundation
import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var connectionCenter: ConnectionCenter?
    var inputController: InputController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        CommandParser.main()
        
        SoundService.shared.initialize()
        SignalHandler.shared.setupSignalHandlers()
        
        connectionCenter = ConnectionCenter.shared
        inputController = InputController()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
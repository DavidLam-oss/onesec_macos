import Foundation

class Throttler {
    private var lastExecutionTime: Date?
    private let interval: TimeInterval
    
    init(interval: TimeInterval) {
        self.interval = interval
    }
    
    func execute(_ action: () -> Void) {
        let now = Date()
        if let lastTime = lastExecutionTime,
           now.timeIntervalSince(lastTime) < interval {
            return
        }
        lastExecutionTime = now
        action()
    }
}


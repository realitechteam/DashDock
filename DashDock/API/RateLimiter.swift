import Foundation

actor RateLimiter {
    private var requestTimestamps: [Date] = []
    private let maxRequests: Int
    private let windowSeconds: TimeInterval

    init(maxRequestsPerMinute: Int) {
        self.maxRequests = maxRequestsPerMinute
        self.windowSeconds = 60
    }

    func tryAcquire() -> Bool {
        let now = Date()
        let windowStart = now.addingTimeInterval(-windowSeconds)
        requestTimestamps.removeAll { $0 < windowStart }

        if requestTimestamps.count < maxRequests {
            requestTimestamps.append(now)
            return true
        }
        return false
    }

    func secondsUntilAvailable() -> TimeInterval {
        guard let oldest = requestTimestamps.first else { return 0 }
        let available = oldest.addingTimeInterval(windowSeconds)
        return max(0, available.timeIntervalSinceNow)
    }
}

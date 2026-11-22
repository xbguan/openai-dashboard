import Foundation

struct UpdateCheckTimeout {
    static let interval: TimeInterval = 30
    static let message = "检查更新超时，请稍后重试。"

    private(set) var generation: UInt = 0
    private var manual = false

    mutating func begin(manual: Bool) -> UInt {
        generation &+= 1
        self.manual = manual
        return generation
    }

    func shouldTimeout(generation: UInt, status: UpdateStatus) -> Bool {
        generation == self.generation && status == .checking
    }

    var timeoutToast: String? {
        manual ? Self.message : nil
    }

    mutating func finish() {
        manual = false
    }
}

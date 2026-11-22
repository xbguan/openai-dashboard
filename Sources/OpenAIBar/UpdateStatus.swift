enum UpdateStatus: Equatable, Hashable {
    case idle
    case checking
    case current
    case available(String)
    case failed

    var actionTitle: String {
        switch self {
        case .checking: return "检查中…"
        case .available(let version): return "更新至 v\(version)"
        case .idle, .current, .failed: return "检查更新"
        }
    }

    var toastID: String {
        switch self {
        case .idle: return "idle"
        case .checking: return "checking"
        case .current: return "current"
        case .available(let version): return "available-\(version)"
        case .failed: return "failed"
        }
    }
}

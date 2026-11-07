enum UpdateStatus: Equatable {
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
}

import Foundation
import Combine
import Sparkle

@MainActor
final class UpdateManager: NSObject, ObservableObject, SPUUpdaterDelegate {
    @Published private(set) var status: UpdateStatus = .idle
    @Published private(set) var errorMessage = "检查更新失败，请稍后重试。"

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var updaterController: SPUStandardUpdaterController?
    private var checkTimer: Timer?

    func start() {
        guard updaterController == nil else { return }
        let controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
        updaterController = controller
        controller.startUpdater()
        checkForUpdates()

        let timer = Timer(timeInterval: 8 * 60 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkForUpdates() }
        }
        RunLoop.main.add(timer, forMode: .common)
        checkTimer = timer
    }

    func performPrimaryAction() {
        switch status {
        case .available:
            updaterController?.updater.checkForUpdates()
        case .checking:
            break
        case .idle, .current, .failed:
            checkForUpdates()
        }
    }

    private func checkForUpdates() {
        guard let updater = updaterController?.updater, !updater.sessionInProgress else { return }
        status = .checking
        updater.checkForUpdateInformation()
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        status = .available(item.displayVersionString)
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: any Error) {
        status = .current
    }

    func updater(_ updater: SPUUpdater,
                 didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
                 error: (any Error)?) {
        if case .checking = status {
            if let error {
                errorMessage = UpdateCheckFailure.message(for: error)
                status = .failed
            } else {
                status = .current
            }
        }
    }
}

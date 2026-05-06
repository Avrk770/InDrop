import ServiceManagement

@MainActor
enum LaunchAtLoginManager {
    struct State {
        let isEnabled: Bool
        let requiresApproval: Bool
    }

    static func currentState() -> State {
        switch SMAppService.mainApp.status {
        case .enabled:
            return State(isEnabled: true, requiresApproval: false)
        case .requiresApproval:
            return State(isEnabled: false, requiresApproval: true)
        case .notFound, .notRegistered:
            return State(isEnabled: false, requiresApproval: false)
        @unknown default:
            return State(isEnabled: false, requiresApproval: false)
        }
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

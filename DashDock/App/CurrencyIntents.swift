import AppIntents

struct CurrencyEntity: AppEntity, Hashable {
    let id: String

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Currency")
    static var defaultQuery = CurrencyQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(id)")
    }
}

struct CurrencyQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [CurrencyEntity] {
        identifiers.map { CurrencyEntity(id: $0) }
    }

    func suggestedEntities() async throws -> [CurrencyEntity] {
        AppCurrency.allCases.map { CurrencyEntity(id: $0.code) }
    }
}

struct ChangeDashDockCurrencyIntent: AppIntent {
    static var title: LocalizedStringResource = "Change DashDock Currency"
    static var description = IntentDescription("Change the currency used in DashDock metrics.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Currency")
    var currency: CurrencyEntity

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let selected = AppCurrency.fromStoredCode(currency.id)
        SharedDataStore.shared.savePreferredCurrency(selected.code)
        return .result(dialog: "DashDock currency changed to \(selected.code).")
    }
}

struct DashDockShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ChangeDashDockCurrencyIntent(),
            phrases: [
                "Change DashDock currency to \(.applicationName)",
                "Set DashDock currency with \(.applicationName)",
                "Update DashDock currency with \(.applicationName)"
            ],
            shortTitle: "Set Currency",
            systemImageName: "coloncurrencysign.circle"
        )
    }
}

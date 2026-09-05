import SwiftUI

@main
struct NuanceOSApp: App {
    @StateObject private var store = GoalStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}

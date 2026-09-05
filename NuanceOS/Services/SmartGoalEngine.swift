import Foundation

struct SmartGoalEngine {
    private let apple = AppleFoundationGoalEngine()
    private let fallback = GoalEngine()

    var availabilityDescription: String {
        apple.availabilityDescription
    }

    func buildPlan(from objective: String) async -> (plan: GoalPlan, usedAppleIntelligence: Bool, note: String?) {
        do {
            let plan = try await apple.buildPlan(from: objective)
            return (plan, true, nil)
        } catch {
            let plan = fallback.buildPlan(from: objective)
            return (plan, false, error.localizedDescription)
        }
    }
}

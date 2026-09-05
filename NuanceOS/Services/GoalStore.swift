import Foundation

@MainActor
final class GoalStore: ObservableObject {
    @Published private(set) var plans: [GoalPlan] = []

    private let storageKey = "nuance.goal.plans.v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        load()
    }

    func add(_ plan: GoalPlan) {
        plans.insert(plan, at: 0)
        save()
    }

    func delete(at offsets: IndexSet) {
        plans.remove(atOffsets: offsets)
        save()
    }

    func toggleStep(planID: UUID, stepID: UUID) {
        guard let planIndex = plans.firstIndex(where: { $0.id == planID }),
              let stepIndex = plans[planIndex].actionPlan.firstIndex(where: { $0.id == stepID }) else {
            return
        }
        plans[planIndex].actionPlan[stepIndex].isCompleted.toggle()
        save()
    }

    func clear() {
        plans.removeAll()
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        plans = (try? decoder.decode([GoalPlan].self, from: data)) ?? []
    }

    private func save() {
        guard let data = try? encoder.encode(plans) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

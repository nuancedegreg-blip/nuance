import Foundation
import UserNotifications

@MainActor
final class GoalStore: ObservableObject {
    @Published private(set) var plans: [GoalPlan] = []

    private let storageKey = "nuance.goal.plans.v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let notificationCenter = UNUserNotificationCenter.current()

    var activePlans: [GoalPlan] {
        plans.filter { $0.actionPlan.contains(where: { !$0.isCompleted }) }
    }

    var completedPlans: [GoalPlan] {
        plans.filter { !$0.actionPlan.isEmpty && $0.actionPlan.allSatisfy(\.isCompleted) }
    }

    init() {
        load()
    }

    func add(_ plan: GoalPlan) {
        plans.insert(plan, at: 0)
        save()
        refreshReminder(for: plan.id, askingPermissionIfNeeded: true)
    }

    func delete(at offsets: IndexSet) {
        let ids = offsets.compactMap { index in
            plans.indices.contains(index) ? plans[index].id : nil
        }
        plans.remove(atOffsets: offsets)
        save()
        ids.forEach(cancelReminder)
    }

    func delete(planID: UUID) {
        plans.removeAll { $0.id == planID }
        save()
        cancelReminder(planID)
    }

    func toggleStep(planID: UUID, stepID: UUID) {
        guard let planIndex = plans.firstIndex(where: { $0.id == planID }),
              let stepIndex = plans[planIndex].actionPlan.firstIndex(where: { $0.id == stepID }) else {
            return
        }

        plans[planIndex].actionPlan[stepIndex].isCompleted.toggle()
        save()
        refreshReminder(for: planID, askingPermissionIfNeeded: false)
    }

    func markNextStepDone(planID: UUID) {
        guard let plan = plans.first(where: { $0.id == planID }),
              let next = plan.actionPlan.first(where: { !$0.isCompleted }) else { return }
        toggleStep(planID: planID, stepID: next.id)
    }

    func clear() {
        let ids = plans.map(\.id)
        plans.removeAll()
        save()
        ids.forEach(cancelReminder)
    }

    func nextAction(for plan: GoalPlan) -> ActionStep? {
        plan.actionPlan.first(where: { !$0.isCompleted })
    }

    func progress(for plan: GoalPlan) -> Double {
        guard !plan.actionPlan.isEmpty else { return 0 }
        let completed = plan.actionPlan.filter(\.isCompleted).count
        return Double(completed) / Double(plan.actionPlan.count)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        plans = (try? decoder.decode([GoalPlan].self, from: data)) ?? []
    }

    private func save() {
        guard let data = try? encoder.encode(plans) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func refreshReminder(for planID: UUID, askingPermissionIfNeeded: Bool) {
        guard let plan = plans.first(where: { $0.id == planID }) else {
            cancelReminder(planID)
            return
        }

        guard let next = nextAction(for: plan) else {
            cancelReminder(planID)
            return
        }

        Task {
            let settings = await notificationCenter.notificationSettings()
            var authorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional

            if !authorized, askingPermissionIfNeeded, settings.authorizationStatus == .notDetermined {
                authorized = (try? await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            }

            guard authorized else { return }

            notificationCenter.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier(for: planID)])

            let content = UNMutableNotificationContent()
            content.title = "Ta prochaine action"
            content.subtitle = plan.objective
            content.body = "\(next.title) — \(next.details)"
            content.sound = .default

            var date = DateComponents()
            date.hour = 9
            date.minute = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
            let request = UNNotificationRequest(
                identifier: notificationIdentifier(for: planID),
                content: content,
                trigger: trigger
            )

            try? await notificationCenter.add(request)
        }
    }

    private func cancelReminder(_ planID: UUID) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier(for: planID)])
    }

    private func notificationIdentifier(for planID: UUID) -> String {
        "nuance.plan.\(planID.uuidString).daily"
    }
}

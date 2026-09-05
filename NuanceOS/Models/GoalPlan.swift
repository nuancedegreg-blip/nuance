import Foundation

struct GoalPlan: Identifiable, Codable, Hashable {
    let id: UUID
    let createdAt: Date
    var objective: String
    var detectedIntent: String
    var subgoals: [String]
    var missingInformation: [String]
    var actionPlan: [ActionStep]
    var recommendedNextStep: String

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        objective: String,
        detectedIntent: String,
        subgoals: [String],
        missingInformation: [String],
        actionPlan: [ActionStep],
        recommendedNextStep: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.objective = objective
        self.detectedIntent = detectedIntent
        self.subgoals = subgoals
        self.missingInformation = missingInformation
        self.actionPlan = actionPlan
        self.recommendedNextStep = recommendedNextStep
    }
}

struct ActionStep: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var details: String
    var isCompleted: Bool

    init(id: UUID = UUID(), title: String, details: String, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.details = details
        self.isCompleted = isCompleted
    }
}

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

struct AppleFoundationGoalEngine {
    enum EngineError: LocalizedError {
        case unavailable(String)

        var errorDescription: String? {
            switch self {
            case .unavailable(let reason):
                return reason
            }
        }
    }

    var availabilityDescription: String {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default
            switch model.availability {
            case .available:
                return "Apple Intelligence disponible"
            case .unavailable(.deviceNotEligible):
                return "Cet appareil n'est pas compatible avec Apple Intelligence"
            case .unavailable(.modelNotReady):
                return "Le modèle Apple Intelligence n'est pas encore prêt"
            case .unavailable(let reason):
                return "Apple Intelligence indisponible : \(String(describing: reason))"
            }
        }
#endif
        return "Foundation Models nécessite iOS 26 ou une version ultérieure"
    }

    func buildPlan(from rawObjective: String) async throws -> GoalPlan {
        let objective = rawObjective.trimmingCharacters(in: .whitespacesAndNewlines)

#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default
            guard model.isAvailable else {
                throw EngineError.unavailable(availabilityDescription)
            }

            let session = LanguageModelSession(
                model: model,
                instructions: """
                Tu es le moteur de planification de l'application Nuance.
                Réponds toujours en français.
                Transforme l'objectif de l'utilisateur en plan concret, réaliste et directement exploitable.
                Ne prétends pas avoir effectué des actions externes.
                Ne fabrique pas de faits, de prix ou de disponibilités qui nécessiteraient une recherche.
                Les étapes doivent être courtes, précises et ordonnées.
                """
            )

            let prompt = """
            Analyse cet objectif : \(objective)

            Déduis une catégorie courte, 3 à 5 sous-objectifs, jusqu'à 4 informations importantes à préciser,
            puis 3 à 6 étapes d'action. Termine par une seule prochaine action très concrète.
            """

            let response = try await session.respond(to: prompt, generating: GeneratedGoalPlan.self)
            let generated = response.content

            return GoalPlan(
                objective: objective,
                detectedIntent: generated.detectedIntent,
                subgoals: generated.subgoals,
                missingInformation: generated.missingInformation,
                actionPlan: generated.actionPlan.map {
                    ActionStep(title: $0.title, details: $0.details)
                },
                recommendedNextStep: generated.recommendedNextStep
            )
        }
#endif

        throw EngineError.unavailable(availabilityDescription)
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable(description: "Un plan structuré pour atteindre un objectif")
private struct GeneratedGoalPlan {
    @Guide(description: "Catégorie courte de l'objectif")
    var detectedIntent: String

    @Guide(description: "Sous-objectifs essentiels", .count(3...5))
    var subgoals: [String]

    @Guide(description: "Informations importantes qui manquent pour rendre le plan plus précis", .maximumCount(4))
    var missingInformation: [String]

    @Guide(description: "Étapes ordonnées et concrètes", .count(3...6))
    var actionPlan: [GeneratedActionStep]

    @Guide(description: "Une seule prochaine action à réaliser maintenant")
    var recommendedNextStep: String
}

@available(iOS 26.0, *)
@Generable(description: "Une étape d'action")
private struct GeneratedActionStep {
    @Guide(description: "Titre court de l'étape")
    var title: String

    @Guide(description: "Explication pratique en une ou deux phrases")
    var details: String
}
#endif

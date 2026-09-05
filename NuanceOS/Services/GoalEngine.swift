import Foundation

struct GoalEngine {
    func buildPlan(from rawObjective: String) -> GoalPlan {
        let objective = rawObjective.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = objective.lowercased()

        let intent: String
        if lower.contains("économ") || lower.contains("budget") || lower.contains("argent") {
            intent = "Finances"
        } else if lower.contains("vacance") || lower.contains("voyage") {
            intent = "Voyage"
        } else if lower.contains("entreprise") || lower.contains("activité") || lower.contains("business") {
            intent = "Projet professionnel"
        } else if lower.contains("sport") || lower.contains("poids") || lower.contains("forme") {
            intent = "Bien-être"
        } else {
            intent = "Objectif général"
        }

        let subgoals = makeSubgoals(for: objective, intent: intent)
        let missing = makeMissingInformation(for: objective, intent: intent)
        let steps = makeSteps(for: objective, intent: intent)

        return GoalPlan(
            objective: objective,
            detectedIntent: intent,
            subgoals: subgoals,
            missingInformation: missing,
            actionPlan: steps,
            recommendedNextStep: steps.first?.title ?? "Préciser l'objectif"
        )
    }

    private func makeSubgoals(for objective: String, intent: String) -> [String] {
        switch intent {
        case "Finances":
            return [
                "Définir le montant et l'échéance",
                "Mesurer les dépenses actuelles",
                "Identifier les économies possibles",
                "Mettre en place un suivi régulier"
            ]
        case "Voyage":
            return [
                "Définir destination et dates",
                "Fixer un budget",
                "Réserver transport et hébergement",
                "Préparer les formalités et le programme"
            ]
        case "Projet professionnel":
            return [
                "Clarifier l'offre et le résultat attendu",
                "Identifier les ressources nécessaires",
                "Définir les étapes de lancement",
                "Mesurer les premiers résultats"
            ]
        default:
            return [
                "Définir précisément le résultat attendu",
                "Découper l'objectif en étapes simples",
                "Choisir une première action réalisable",
                "Faire un point après la première étape"
            ]
        }
    }

    private func makeMissingInformation(for objective: String, intent: String) -> [String] {
        var items: [String] = []
        let lower = objective.lowercased()

        if !lower.contains("€") && !lower.contains("euro") && intent == "Finances" {
            items.append("Montant cible")
        }
        if !lower.contains("jour") && !lower.contains("semaine") && !lower.contains("mois") && !lower.contains("année") {
            items.append("Échéance ou fréquence")
        }
        items.append("Contraintes principales")
        items.append("Ressources déjà disponibles")

        return Array(items.prefix(4))
    }

    private func makeSteps(for objective: String, intent: String) -> [ActionStep] {
        switch intent {
        case "Finances":
            return [
                ActionStep(title: "Noter la situation actuelle", details: "Lister revenus, charges fixes et dépenses variables."),
                ActionStep(title: "Fixer une cible chiffrée", details: "Définir combien économiser et à quelle fréquence."),
                ActionStep(title: "Choisir 3 leviers", details: "Sélectionner trois dépenses à réduire ou revenus à augmenter."),
                ActionStep(title: "Automatiser le suivi", details: "Prévoir un contrôle hebdomadaire et un bilan mensuel.")
            ]
        case "Voyage":
            return [
                ActionStep(title: "Choisir les dates", details: "Déterminer une fenêtre réaliste et la durée."),
                ActionStep(title: "Fixer le budget maximum", details: "Inclure transport, logement, repas et activités."),
                ActionStep(title: "Comparer les options", details: "Comparer transport et hébergement avant réservation."),
                ActionStep(title: "Créer la checklist", details: "Documents, bagages, réservations et programme.")
            ]
        default:
            return [
                ActionStep(title: "Reformuler l'objectif", details: "Écrire le résultat attendu en une phrase claire et mesurable."),
                ActionStep(title: "Lister les contraintes", details: "Temps, budget, personnes, outils et échéances."),
                ActionStep(title: "Découper en petites étapes", details: "Créer des actions qui peuvent être réalisées une par une."),
                ActionStep(title: "Commencer maintenant", details: "Exécuter la plus petite action utile dans les prochaines 24 heures.")
            ]
        }
    }
}

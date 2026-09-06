import Foundation

struct GoalEngine {
    func buildPlan(from rawObjective: String) -> GoalPlan {
        let objective = rawObjective.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = objective.lowercased()
        let intent = detectIntent(in: lower)
        let subgoals = makeSubgoals(intent: intent)
        let missing = makeMissingInformation(for: lower, intent: intent)
        let steps = makeSteps(intent: intent)

        return GoalPlan(
            objective: objective,
            detectedIntent: intent,
            subgoals: subgoals,
            missingInformation: missing,
            actionPlan: steps,
            recommendedNextStep: steps.first?.title ?? "Clarifier le résultat attendu"
        )
    }

    private func detectIntent(in text: String) -> String {
        if containsAny(text, ["économ", "budget", "argent", "dette", "épargne", "invest", "salaire", "revenu"]) {
            return "Finances"
        }
        if containsAny(text, ["voyage", "vacance", "partir", "destination", "week-end", "avion", "hôtel"]) {
            return "Voyage"
        }
        if containsAny(text, ["entreprise", "activité", "business", "client", "chiffre d'affaires", "vendre", "lancer", "projet pro"]) {
            return "Projet professionnel"
        }
        if containsAny(text, ["sport", "poids", "forme", "courir", "muscle", "nutrition", "santé", "sommeil"]) {
            return "Bien-être"
        }
        if containsAny(text, ["maison", "appartement", "acheter", "immobilier", "déménager", "travaux", "rénover"]) {
            return "Maison & immobilier"
        }
        if containsAny(text, ["organiser", "organisation", "temps", "productiv", "retard", "planning", "routine"]) {
            return "Organisation"
        }
        if containsAny(text, ["apprendre", "formation", "examen", "langue", "étudier", "diplôme", "compétence"]) {
            return "Apprentissage"
        }
        if containsAny(text, ["couple", "famille", "relation", "enfant", "amis", "rencontrer"]) {
            return "Vie personnelle"
        }
        return "Objectif personnel"
    }

    private func makeSubgoals(intent: String) -> [String] {
        switch intent {
        case "Finances":
            return ["Connaître précisément le point de départ", "Fixer une cible mensuelle réaliste", "Créer une marge automatique", "Mesurer l'écart chaque semaine"]
        case "Voyage":
            return ["Fixer dates et contraintes", "Définir le budget total", "Sécuriser transport et logement", "Préparer les détails pratiques"]
        case "Projet professionnel":
            return ["Définir le résultat commercial attendu", "Valider le besoin réel", "Construire une première offre simple", "Obtenir un premier résultat mesurable"]
        case "Bien-être":
            return ["Définir un résultat mesurable", "Choisir une routine soutenable", "Réduire les principaux obstacles", "Suivre les progrès sans perfectionnisme"]
        case "Maison & immobilier":
            return ["Clarifier le résultat et le budget", "Identifier les contraintes techniques ou financières", "Découper en décisions successives", "Sécuriser l'étape la plus engageante"]
        case "Organisation":
            return ["Identifier les vraies priorités", "Réduire les tâches parasites", "Créer une routine simple", "Faire un point court et régulier"]
        case "Apprentissage":
            return ["Définir le niveau cible", "Évaluer le niveau actuel", "Créer une pratique régulière", "Tester les acquis fréquemment"]
        case "Vie personnelle":
            return ["Clarifier ce que tu veux changer", "Identifier ce qui dépend réellement de toi", "Choisir une action simple", "Observer l'effet et ajuster"]
        default:
            return ["Définir le résultat attendu", "Identifier le point de départ", "Découper l'objectif", "Créer une première victoire rapide"]
        }
    }

    private func makeMissingInformation(for text: String, intent: String) -> [String] {
        var items: [String] = []

        if !containsAny(text, ["jour", "semaine", "mois", "an", "année", "avant", "d'ici", "pour le"]) {
            items.append("Délai souhaité")
        }

        if intent == "Finances" && !containsAny(text, ["€", "euro", "euros"]) {
            items.append("Montant cible")
        }

        if intent == "Voyage" && !containsAny(text, ["à ", "au ", "aux ", "en "]) {
            items.append("Destination")
        }

        items.append("Point de départ actuel")
        items.append("Contrainte principale")
        items.append("Temps ou budget réellement disponible")

        var seen = Set<String>()
        return items.filter { seen.insert($0).inserted }.prefix(4).map { $0 }
    }

    private func makeSteps(intent: String) -> [ActionStep] {
        switch intent {
        case "Finances":
            return [
                ActionStep(title: "Faire le vrai bilan", details: "Note les revenus nets, charges fixes, remboursements et dépenses variables du dernier mois."),
                ActionStep(title: "Créer la marge cible", details: "Décide d'un montant automatique à isoler dès l'entrée d'argent, avant les dépenses facultatives."),
                ActionStep(title: "Trouver trois leviers", details: "Choisis au maximum trois postes à réduire ou trois façons réalistes d'augmenter les revenus."),
                ActionStep(title: "Automatiser", details: "Programme le virement ou la règle qui rend la bonne décision automatique."),
                ActionStep(title: "Contrôler chaque semaine", details: "Compare le réalisé à l'objectif et ajuste un seul levier à la fois.")
            ]
        case "Voyage":
            return [
                ActionStep(title: "Fixer le cadre", details: "Écris les dates possibles, la durée, le nombre de personnes et les contraintes non négociables."),
                ActionStep(title: "Fixer le plafond", details: "Définis un budget total et une réserve pour les imprévus."),
                ActionStep(title: "Sécuriser les gros postes", details: "Commence par transport et hébergement avant les détails secondaires."),
                ActionStep(title: "Créer la checklist", details: "Documents, assurances, réservations, déplacements, moyens de paiement et bagages."),
                ActionStep(title: "Préparer le plan B", details: "Identifie les deux risques principaux et la solution de secours pour chacun.")
            ]
        case "Projet professionnel":
            return [
                ActionStep(title: "Définir la victoire", details: "Formule un résultat mesurable : vente, client, revenu, lancement ou validation."),
                ActionStep(title: "Tester le besoin", details: "Parle à de vraies personnes concernées avant d'ajouter des fonctionnalités ou des coûts."),
                ActionStep(title: "Créer l'offre minimale", details: "Construis la version la plus simple qui apporte déjà une vraie valeur."),
                ActionStep(title: "Obtenir un premier utilisateur", details: "Cherche un premier usage réel plutôt qu'un produit parfait."),
                ActionStep(title: "Mesurer et corriger", details: "Observe ce qui bloque, conserve ce qui marche et modifie une chose à la fois.")
            ]
        case "Bien-être":
            return [
                ActionStep(title: "Mesurer le point de départ", details: "Choisis un ou deux indicateurs simples et note ta situation actuelle."),
                ActionStep(title: "Réduire l'objectif", details: "Choisis une routine assez petite pour être tenue même une mauvaise journée."),
                ActionStep(title: "Bloquer le créneau", details: "Décide à l'avance quand et où l'action aura lieu."),
                ActionStep(title: "Préparer l'environnement", details: "Retire un obstacle concret et rends l'action souhaitée plus facile."),
                ActionStep(title: "Faire le bilan", details: "Après une semaine, garde ce qui tient dans la vraie vie et ajuste le reste.")
            ]
        case "Organisation":
            return [
                ActionStep(title: "Vider la tête", details: "Liste tout ce qui te prend de l'attention sans chercher à organiser tout de suite."),
                ActionStep(title: "Choisir trois priorités", details: "Garde uniquement les trois résultats qui comptent le plus actuellement."),
                ActionStep(title: "Définir la prochaine action", details: "Transforme chaque priorité en une action physique et réalisable."),
                ActionStep(title: "Protéger un créneau", details: "Réserve une plage sans interruption pour la priorité numéro un."),
                ActionStep(title: "Revoir chaque soir", details: "Fais un bilan de deux minutes et choisis l'action du lendemain.")
            ]
        case "Apprentissage":
            return [
                ActionStep(title: "Tester ton niveau", details: "Fais un petit test ou exercice sans aide pour voir précisément ce qui manque."),
                ActionStep(title: "Choisir le minimum quotidien", details: "Définis une durée ou quantité réaliste que tu peux tenir presque tous les jours."),
                ActionStep(title: "Pratiquer activement", details: "Privilégie exercices, rappel de mémoire et production plutôt que lecture passive."),
                ActionStep(title: "Corriger les lacunes", details: "Travaille en priorité ce qui provoque les erreurs récurrentes."),
                ActionStep(title: "Retester", details: "Mesure les progrès à intervalle régulier avec une situation proche du résultat final.")
            ]
        default:
            return [
                ActionStep(title: "Définir le résultat", details: "Écris ce qui devra être concrètement différent quand l'objectif sera atteint."),
                ActionStep(title: "Décrire le point de départ", details: "Note les faits actuels, les ressources disponibles et les contraintes."),
                ActionStep(title: "Identifier le principal blocage", details: "Choisis le problème qui ralentit le plus l'objectif aujourd'hui."),
                ActionStep(title: "Faire la plus petite action utile", details: "Choisis une action réalisable aujourd'hui qui réduit directement ce blocage."),
                ActionStep(title: "Ajuster après le résultat", details: "Observe ce qui s'est réellement passé et décide de la prochaine action à partir des faits.")
            ]
        }
    }

    private func containsAny(_ text: String, _ terms: [String]) -> Bool {
        terms.contains { text.contains($0) }
    }
}

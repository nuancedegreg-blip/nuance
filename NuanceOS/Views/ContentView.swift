import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

struct ContentView: View {
    @EnvironmentObject private var store: GoalStore
    @State private var objective = ""
    @State private var generatedPlan: GoalPlan?
    @State private var isGenerating = false
    @State private var aiStatus = "Vérification d’Apple Intelligence…"
    @State private var usedAppleIntelligence: Bool?

    private let fallbackEngine = GoalEngine()

    var body: some View {
        TabView {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Quel est ton objectif ?")
                                .font(.largeTitle.bold())
                            Text("Décris ce que tu veux obtenir. Nuance le transforme en plan clair et actionnable.")
                                .foregroundStyle(.secondary)
                        }

                        statusCard

                        VStack(spacing: 14) {
                            TextField("Ex : Économiser 500 € par mois", text: $objective, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(3...6)

                            Button(action: generate) {
                                HStack {
                                    if isGenerating { ProgressView() } else { Image(systemName: "sparkles") }
                                    Text(isGenerating ? "Analyse en cours…" : "Créer mon plan")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 5)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isGenerating || objective.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))

                        if let generatedPlan {
                            PlanView(plan: generatedPlan, isSavedPlan: false)
                        }
                    }
                    .padding()
                }
                .navigationTitle("Nuance")
                .task { refreshAIStatus() }
            }
            .tabItem { Label("Objectif", systemImage: "sparkles") }

            NavigationStack { HistoryView() }
                .tabItem { Label("Historique", systemImage: "clock.arrow.circlepath") }
        }
    }

    private var statusCard: some View {
        HStack(spacing: 10) {
            Image(systemName: usedAppleIntelligence == false ? "cpu" : "sparkles")
            VStack(alignment: .leading, spacing: 2) {
                Text(usedAppleIntelligence == true ? "Apple Intelligence" : usedAppleIntelligence == false ? "Mode local" : "Moteur IA")
                    .font(.subheadline.weight(.semibold))
                Text(aiStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func refreshAIStatus() {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                aiStatus = "Disponible sur cet iPhone. Les plans seront générés sur l’appareil."
                usedAppleIntelligence = nil
            case .unavailable(.deviceNotEligible):
                aiStatus = "Cet appareil n’est pas compatible avec Apple Intelligence."
                usedAppleIntelligence = false
            case .unavailable(.modelNotReady):
                aiStatus = "Apple Intelligence n’est pas encore prêt sur cet appareil."
                usedAppleIntelligence = false
            case .unavailable:
                aiStatus = "Apple Intelligence est actuellement indisponible."
                usedAppleIntelligence = false
            }
            return
        }
#endif
        aiStatus = "Foundation Models nécessite iOS 26 ou une version ultérieure."
        usedAppleIntelligence = false
    }

    private func generate() {
        let text = objective.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isGenerating = true

        Task {
#if canImport(FoundationModels)
            if #available(iOS 26.0, *), SystemLanguageModel.default.isAvailable {
                do {
                    let session = LanguageModelSession(
                        model: SystemLanguageModel.default,
                        instructions: """
                        Tu es le moteur de planification de Nuance. Réponds en français.
                        Transforme l’objectif en plan concret, réaliste et directement exploitable.
                        N’invente pas de faits, de prix ou de disponibilités qui nécessitent une recherche externe.
                        Ne prétends jamais avoir effectué une action externe.
                        """
                    )

                    let response = try await session.respond(
                        to: """
                        Analyse cet objectif : \(text)
                        Donne une catégorie courte, 3 à 5 sous-objectifs, jusqu’à 4 informations à préciser,
                        3 à 6 étapes d’action ordonnées et une seule prochaine action très concrète.
                        """,
                        generating: GeneratedGoalPlan.self
                    )

                    let result = response.content
                    let plan = GoalPlan(
                        objective: text,
                        detectedIntent: result.detectedIntent,
                        subgoals: result.subgoals,
                        missingInformation: result.missingInformation,
                        actionPlan: result.actionPlan.map { ActionStep(title: $0.title, details: $0.details) },
                        recommendedNextStep: result.recommendedNextStep
                    )

                    await MainActor.run {
                        generatedPlan = plan
                        store.add(plan)
                        usedAppleIntelligence = true
                        aiStatus = "Plan généré localement avec Apple Intelligence."
                        isGenerating = false
                    }
                    return
                } catch {
                    await MainActor.run {
                        aiStatus = "Apple Intelligence n’a pas pu traiter cette demande. Mode local utilisé."
                    }
                }
            }
#endif
            let plan = fallbackEngine.buildPlan(from: text)
            await MainActor.run {
                generatedPlan = plan
                store.add(plan)
                usedAppleIntelligence = false
                if !aiStatus.contains("n’a pas pu") {
                    aiStatus = "Apple Intelligence indisponible. Plan généré avec le moteur local de secours."
                }
                isGenerating = false
            }
        }
    }
}

private struct PlanView: View {
    @EnvironmentObject private var store: GoalStore
    let plan: GoalPlan
    let isSavedPlan: Bool

    private var currentPlan: GoalPlan {
        if isSavedPlan, let saved = store.plans.first(where: { $0.id == plan.id }) { return saved }
        return plan
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            card("Objectif détecté", icon: "target") {
                Text(currentPlan.objective)
                Text(currentPlan.detectedIntent)
                    .font(.caption.weight(.semibold))
            }

            card("Sous-objectifs", icon: "square.stack.3d.up") {
                ForEach(Array(currentPlan.subgoals.enumerated()), id: \.offset) { index, item in
                    Text("\(index + 1). \(item)")
                }
            }

            card("Informations à préciser", icon: "questionmark.circle") {
                ForEach(currentPlan.missingInformation, id: \.self) { Text("• \($0)") }
            }

            card("Plan d’action", icon: "checklist") {
                ForEach(currentPlan.actionPlan) { step in
                    Button {
                        if isSavedPlan { store.toggleStep(planID: currentPlan.id, stepID: step.id) }
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: step.isCompleted ? "checkmark.circle.fill" : "circle")
                            VStack(alignment: .leading, spacing: 3) {
                                Text(step.title).font(.headline).strikethrough(step.isCompleted)
                                Text(step.details).font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            card("Prochaine étape", icon: "bolt.fill") {
                Text(currentPlan.recommendedNextStep).font(.headline)
            }
        }
    }

    @ViewBuilder
    private func card<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon).font(.title3.bold())
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct HistoryView: View {
    @EnvironmentObject private var store: GoalStore

    var body: some View {
        Group {
            if store.plans.isEmpty {
                ContentUnavailableView("Aucun objectif", systemImage: "clock", description: Text("Tes objectifs enregistrés apparaîtront ici."))
            } else {
                List {
                    ForEach(store.plans) { plan in
                        NavigationLink {
                            ScrollView { PlanView(plan: plan, isSavedPlan: true).padding() }
                                .navigationTitle("Plan")
                        } label: {
                            VStack(alignment: .leading) {
                                Text(plan.objective).font(.headline).lineLimit(2)
                                Text(plan.createdAt, format: .dateTime.day().month().year().hour().minute())
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: store.delete)
                }
            }
        }
        .navigationTitle("Historique")
        .toolbar { if !store.plans.isEmpty { EditButton() } }
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable(description: "Plan structuré pour atteindre un objectif")
private struct GeneratedGoalPlan {
    @Guide(description: "Catégorie courte de l’objectif")
    var detectedIntent: String

    @Guide(description: "Sous-objectifs essentiels", .minimumCount(3), .maximumCount(5))
    var subgoals: [String]

    @Guide(description: "Informations importantes manquantes", .maximumCount(4))
    var missingInformation: [String]

    @Guide(description: "Étapes ordonnées et concrètes", .minimumCount(3), .maximumCount(6))
    var actionPlan: [GeneratedActionStep]

    @Guide(description: "Une seule prochaine action à réaliser maintenant")
    var recommendedNextStep: String
}

@available(iOS 26.0, *)
@Generable(description: "Une étape d’action")
private struct GeneratedActionStep {
    @Guide(description: "Titre court de l’étape")
    var title: String

    @Guide(description: "Explication pratique en une ou deux phrases")
    var details: String
}
#endif

#Preview {
    ContentView().environmentObject(GoalStore())
}

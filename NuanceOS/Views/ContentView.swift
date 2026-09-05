import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

struct ContentView: View {
    @EnvironmentObject private var store: GoalStore
    @State private var objective = ""
    @State private var generatedPlan: GoalPlan?
    @State private var selectedTab = 0
    @State private var isGenerating = false
    @State private var aiStatus = "Vérification d’Apple Intelligence…"
    @State private var usedAppleIntelligence: Bool?

    private let fallbackEngine = GoalEngine()

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        hero
                        aiStatusCard
                        objectiveCard

                        if let generatedPlan {
                            PlanView(plan: generatedPlan, isSavedPlan: false)
                        }
                    }
                    .padding()
                }
                .navigationTitle("Nuance")
                .task {
                    refreshAIStatus()
                }
            }
            .tabItem {
                Label("Objectif", systemImage: "sparkles")
            }
            .tag(0)

            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label("Historique", systemImage: "clock.arrow.circlepath")
            }
            .tag(1)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quel est ton objectif ?")
                .font(.largeTitle.bold())
            Text("Décris ce que tu veux obtenir. Nuance le transforme en plan clair et actionnable.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var aiStatusCard: some View {
        HStack(spacing: 10) {
            Image(systemName: usedAppleIntelligence == false ? "cpu" : "sparkles")
                .font(.title3)
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

    private var objectiveCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Ex : Économiser 500 € par mois", text: $objective, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)

            Button {
                generate()
            } label: {
                HStack {
                    if isGenerating {
                        ProgressView()
                    } else {
                        Image(systemName: "sparkles")
                    }
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
    }

    private func refreshAIStatus() {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default
            switch model.availability {
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
            if #available(iOS 26.0, *) {
                let model = SystemLanguageModel.default
                if model.isAvailable {
                    do {
                        let session = LanguageModelSession(
                            model: model,
                            instructions: """
                            Tu es le moteur de planification de l’application Nuance.
                            Réponds en français.
                            Transforme l’objectif de l’utilisateur en plan concret, réaliste et directement exploitable.
                            Ne prétends jamais avoir effectué une action externe.
                            N’invente pas de prix, de disponibilité ou de faits qui exigeraient une recherche externe.
                            Fais des étapes courtes, précises et ordonnées.
                            """
                        )

                        let response = try await session.respond(
                            to: """
                            Analyse cet objectif : \(text)
                            Déduis une catégorie courte, 3 à 5 sous-objectifs, jusqu’à 4 informations importantes à préciser,
                            3 à 6 étapes d’action ordonnées, puis une seule prochaine action très concrète.
                            """,
                            generating: GeneratedGoalPlan.self
                        )

                        let generated = response.content
                        let plan = GoalPlan(
                            objective: text,
                            detectedIntent: generated.detectedIntent,
                            subgoals: generated.subgoals,
                            missingInformation: generated.missingInformation,
                            actionPlan: generated.actionPlan.map {
                                ActionStep(title: $0.title, details: $0.details)
                            },
                            recommendedNextStep: generated.recommendedNextStep
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
                            aiStatus = "Apple Intelligence a échoué pour cette demande. Mode local utilisé."
                        }
                    }
                }
            }
#endif

            let fallbackPlan = fallbackEngine.buildPlan(from: text)
            await MainActor.run {
                generatedPlan = fallbackPlan
                store.add(fallbackPlan)
                usedAppleIntelligence = false
                if !aiStatus.contains("échoué") {
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
        if isSavedPlan, let updated = store.plans.first(where: { $0.id == plan.id }) {
            return updated
        }
        return plan
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            section("Objectif détecté", systemImage: "target") {
                Text(currentPlan.objective)
                Text(currentPlan.detectedIntent)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.quaternary, in: Capsule())
            }

            section("Sous-objectifs", systemImage: "square.stack.3d.up") {
                ForEach(Array(currentPlan.subgoals.enumerated()), id: \.offset) { index, item in
                    Label("\(index + 1). \(item)", systemImage: "circle")
                }
            }

            section("Informations à préciser", systemImage: "questionmark.circle") {
                ForEach(currentPlan.missingInformation, id: \.self) { item in
                    Label(item, systemImage: "exclamationmark.bubble")
                }
            }

            section("Plan d’action", systemImage: "checklist") {
                ForEach(currentPlan.actionPlan) { step in
                    Button {
                        guard isSavedPlan else { return }
                        store.toggleStep(planID: currentPlan.id, stepID: step.id)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: step.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(step.title)
                                    .font(.headline)
                                    .strikethrough(step.isCompleted)
                                Text(step.details)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            section("Prochaine étape", systemImage: "bolt.fill") {
                Text(currentPlan.recommendedNextStep)
                    .font(.headline)
            }
        }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.title3.bold())
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
                ContentUnavailableView(
                    "Aucun objectif",
                    systemImage: "clock",
                    description: Text("Tes objectifs enregistrés apparaîtront ici.")
                )
            } else {
                List {
                    ForEach(store.plans) { plan in
                        NavigationLink {
                            ScrollView {
                                PlanView(plan: plan, isSavedPlan: true)
                                    .padding()
                            }
                            .navigationTitle("Plan")
                            .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(plan.objective)
                                    .font(.headline)
                                    .lineLimit(2)
                                Text(plan.createdAt, format: .dateTime.day().month().year().hour().minute())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: store.delete)
                }
            }
        }
        .navigationTitle("Historique")
        .toolbar {
            if !store.plans.isEmpty {
                EditButton()
            }
        }
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable(description: "Plan structuré pour atteindre un objectif")
private struct GeneratedGoalPlan {
    @Guide(description: "Catégorie courte de l’objectif")
    var detectedIntent: String

    @Guide(description: "Sous-objectifs essentiels", .count(3...5))
    var subgoals: [String]

    @Guide(description: "Informations importantes manquantes", .maximumCount(4))
    var missingInformation: [String]

    @Guide(description: "Étapes ordonnées et concrètes", .count(3...6))
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
    ContentView()
        .environmentObject(GoalStore())
}

import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

struct ContentView: View {
    @EnvironmentObject private var store: GoalStore

    @State private var input = ""
    @State private var messages: [ChatMessage] = []
    @State private var generatedPlan: GoalPlan?
    @State private var isGenerating = false
    @State private var aiStatus = "Vérification d’Apple Intelligence…"
    @State private var usedAppleIntelligence: Bool?
    @State private var questionCount = 0
    @State private var knownFacts: [String] = []
    @State private var situationSummary = ""

    private let fallbackEngine = GoalEngine()

    var body: some View {
        TabView {
            NavigationStack {
                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 14) {
                                introCard
                                statusCard

                                if messages.isEmpty {
                                    starterCard
                                }

                                ForEach(messages) { message in
                                    MessageBubble(message: message)
                                        .id(message.id)
                                }

                                if isGenerating {
                                    ThinkingBubble()
                                        .id("thinking")
                                }

                                if !situationSummary.isEmpty {
                                    situationCard
                                }

                                if let generatedPlan {
                                    PlanView(plan: generatedPlan, isSavedPlan: false)
                                }
                            }
                            .padding()
                        }
                        .onChange(of: messages.count) { _, _ in
                            scrollToBottom(proxy)
                        }
                        .onChange(of: isGenerating) { _, _ in
                            scrollToBottom(proxy)
                        }
                    }

                    composer
                }
                .navigationTitle("Nuance")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            if !messages.isEmpty && generatedPlan == nil {
                                Button("Créer le plan maintenant", systemImage: "checklist") {
                                    forcePlan()
                                }
                            }
                            Button("Nouvelle conversation", systemImage: "arrow.counterclockwise") {
                                resetConversation()
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                .task { refreshAIStatus() }
            }
            .tabItem { Label("Assistant", systemImage: "bubble.left.and.bubble.right.fill") }

            NavigationStack { HistoryView() }
                .tabItem { Label("Plans", systemImage: "checklist") }
        }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Un objectif. Une vraie stratégie.")
                .font(.largeTitle.bold())
            Text("Explique ce que tu veux faire. Nuance te pose les bonnes questions, comprend ta situation et construit un plan adapté à toi.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusCard: some View {
        HStack(spacing: 10) {
            Image(systemName: usedAppleIntelligence == false ? "cpu" : "apple.intelligence")
            VStack(alignment: .leading, spacing: 2) {
                Text(usedAppleIntelligence == false ? "Mode local" : "Apple Intelligence")
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

    private var starterCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Commence simplement", systemImage: "sparkles")
                .font(.headline)
            Text("Exemples :")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            starterButton("Je veux économiser 500 € par mois")
            starterButton("Je veux lancer mon activité")
            starterButton("Je veux organiser un voyage au Japon")
            starterButton("Je veux reprendre le sport sérieusement")
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private func starterButton(_ text: String) -> some View {
        Button {
            input = text
            send()
        } label: {
            HStack {
                Text(text)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "arrow.up.right")
            }
            .font(.subheadline)
        }
        .buttonStyle(.bordered)
    }

    private var situationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Ce que Nuance a compris", systemImage: "brain.head.profile")
                .font(.headline)
            Text(situationSummary)
                .font(.subheadline)
            if !knownFacts.isEmpty {
                Divider()
                ForEach(Array(knownFacts.prefix(6)), id: \.self) { fact in
                    Label(fact, systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField(messages.isEmpty ? "Quel est ton objectif ?" : "Réponds à Nuance…", text: $input, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(12)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
                .submitLabel(.send)
                .onSubmit { send() }

            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 34))
            }
            .disabled(isGenerating || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || generatedPlan != nil)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.25)) {
            if isGenerating {
                proxy.scrollTo("thinking", anchor: .bottom)
            } else if let id = messages.last?.id {
                proxy.scrollTo(id, anchor: .bottom)
            }
        }
    }

    private func refreshAIStatus() {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                aiStatus = "Disponible sur cet iPhone. La conversation est traitée sur l’appareil."
                usedAppleIntelligence = true
            case .unavailable(.deviceNotEligible):
                aiStatus = "Cet appareil n’est pas compatible avec Apple Intelligence."
                usedAppleIntelligence = false
            case .unavailable(.modelNotReady):
                aiStatus = "Apple Intelligence n’est pas encore prêt sur cet appareil."
                usedAppleIntelligence = false
            case .unavailable(.appleIntelligenceNotEnabled):
                aiStatus = "Apple Intelligence n’est pas activé dans Réglages."
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

    private func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isGenerating, generatedPlan == nil else { return }

        input = ""
        messages.append(ChatMessage(role: .user, text: text))
        isGenerating = true

        Task {
            await processConversation(forcePlan: false)
        }
    }

    private func forcePlan() {
        guard !messages.isEmpty, !isGenerating, generatedPlan == nil else { return }
        isGenerating = true
        Task {
            await processConversation(forcePlan: true)
        }
    }

    private func processConversation(forcePlan: Bool) async {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *), SystemLanguageModel.default.isAvailable {
            do {
                let transcriptText = messages.map { message in
                    "\(message.role == .user ? "UTILISATEUR" : "NUANCE"): \(message.text)"
                }.joined(separator: "\n")

                let session = LanguageModelSession(
                    model: SystemLanguageModel.default,
                    instructions: """
                    Tu es Nuance, un assistant personnel de réflexion et de planification en français.
                    Ton rôle n’est PAS de donner immédiatement des conseils génériques.
                    Tu dois d’abord comprendre la situation réelle de la personne : objectif précis, point de départ, contraintes, ressources, délai, budget, priorités et critères de réussite.
                    Pose UNE seule question à la fois, courte et utile. Ne demande jamais une information déjà donnée.
                    Après 2 à 5 questions pertinentes, ou dès que tu as assez d’informations, construis un plan personnalisé.
                    Ne prétends jamais connaître une information que la personne n’a pas fournie.
                    N’invente pas de prix, lois, horaires, disponibilités ou faits qui nécessitent des données externes.
                    Le plan doit être concret, réaliste, priorisé et adapté aux réponses de la personne.
                    """
                )

                let forceInstruction = forcePlan || questionCount >= 5
                    ? "Tu dois maintenant produire le plan final avec les informations disponibles."
                    : "Décide si une question supplémentaire est réellement nécessaire. Si oui, pose seulement la meilleure prochaine question. Sinon, produis le plan final."

                let response = try await session.respond(
                    to: """
                    Voici la conversation actuelle :
                    \(transcriptText)

                    Nombre de questions déjà posées par Nuance : \(questionCount).
                    \(forceInstruction)

                    Fournis une évaluation structurée. Le champ reply doit être le message naturel que Nuance affiche maintenant.
                    Si shouldBuildPlan est faux, reply doit contenir UNE question et les champs du plan peuvent rester très courts.
                    Si shouldBuildPlan est vrai, reply doit annoncer brièvement que le plan est prêt et tous les champs du plan doivent être complets.
                    """,
                    generating: GeneratedAssistantTurn.self
                )

                let result = response.content
                await MainActor.run {
                    situationSummary = result.situationSummary
                    knownFacts = result.knownFacts

                    if result.shouldBuildPlan {
                        let objective = messages.first(where: { $0.role == .user })?.text ?? "Objectif"
                        let plan = GoalPlan(
                            objective: objective,
                            detectedIntent: result.detectedIntent,
                            subgoals: result.subgoals,
                            missingInformation: result.missingInformation,
                            actionPlan: result.actionPlan.map { ActionStep(title: $0.title, details: $0.details) },
                            recommendedNextStep: result.recommendedNextStep
                        )
                        messages.append(ChatMessage(role: .assistant, text: result.reply))
                        generatedPlan = plan
                        store.add(plan)
                    } else {
                        questionCount += 1
                        messages.append(ChatMessage(role: .assistant, text: result.reply))
                    }

                    usedAppleIntelligence = true
                    aiStatus = "Apple Intelligence analyse la conversation localement."
                    isGenerating = false
                }
                return
            } catch {
                await MainActor.run {
                    aiStatus = "Apple Intelligence n’a pas pu traiter ce tour. Mode local utilisé."
                }
            }
        }
#endif
        await MainActor.run {
            fallbackConversation(forcePlan: forcePlan)
            isGenerating = false
        }
    }

    private func fallbackConversation(forcePlan: Bool) {
        let userMessages = messages.filter { $0.role == .user }
        let firstObjective = userMessages.first?.text ?? "Objectif"

        if !forcePlan && questionCount < 3 {
            let questions = [
                "Pour que je t’aide vraiment : quelle est ta situation actuelle par rapport à cet objectif ?",
                "Quelle est ta principale contrainte aujourd’hui : temps, argent, organisation, motivation ou autre chose ?",
                "Dans quel délai voudrais-tu obtenir un résultat concret ?"
            ]
            let question = questions[min(questionCount, questions.count - 1)]
            questionCount += 1
            messages.append(ChatMessage(role: .assistant, text: question))
            situationSummary = "Nuance rassemble les informations nécessaires avant de construire le plan."
            return
        }

        let context = userMessages.map(\.text).joined(separator: " — ")
        let plan = fallbackEngine.buildPlan(from: context)
        generatedPlan = GoalPlan(
            objective: firstObjective,
            detectedIntent: plan.detectedIntent,
            subgoals: plan.subgoals,
            missingInformation: plan.missingInformation,
            actionPlan: plan.actionPlan,
            recommendedNextStep: plan.recommendedNextStep
        )
        if let generatedPlan { store.add(generatedPlan) }
        messages.append(ChatMessage(role: .assistant, text: "J’ai assez d’éléments pour te proposer un premier plan. Tu pourras ensuite l’affiner."))
        usedAppleIntelligence = false
    }

    private func resetConversation() {
        input = ""
        messages = []
        generatedPlan = nil
        isGenerating = false
        questionCount = 0
        knownFacts = []
        situationSummary = ""
        refreshAIStatus()
    }
}

private struct ChatMessage: Identifiable, Hashable {
    enum Role: Hashable { case user, assistant }
    let id = UUID()
    let role: Role
    let text: String
}

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 50) }

            VStack(alignment: .leading, spacing: 5) {
                if message.role == .assistant {
                    Label("Nuance", systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text(message.text)
                    .textSelection(.enabled)
            }
            .padding(12)
            .background(
                message.role == .user ? Color.accentColor.opacity(0.16) : Color(uiColor: .secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: 17)
            )

            if message.role == .assistant { Spacer(minLength: 35) }
        }
    }
}

private struct ThinkingBubble: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text("Nuance réfléchit à la prochaine étape…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 17))
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
            HStack {
                Label("Ton plan personnalisé", systemImage: "wand.and.stars")
                    .font(.title2.bold())
                Spacer()
            }
            .padding(.top, 4)

            card("Objectif", icon: "target") {
                Text(currentPlan.objective)
                Text(currentPlan.detectedIntent)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            card("Priorités", icon: "square.stack.3d.up") {
                ForEach(Array(currentPlan.subgoals.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top) {
                        Text("\(index + 1)")
                            .font(.caption.bold())
                            .frame(width: 24, height: 24)
                            .background(.thinMaterial, in: Circle())
                        Text(item)
                    }
                }
            }

            if !currentPlan.missingInformation.isEmpty {
                card("À vérifier ou préciser", icon: "questionmark.circle") {
                    ForEach(currentPlan.missingInformation, id: \.self) { Text("• \($0)") }
                }
            }

            card("Plan d’action", icon: "checklist") {
                ForEach(currentPlan.actionPlan) { step in
                    Button {
                        if isSavedPlan { store.toggleStep(planID: currentPlan.id, stepID: step.id) }
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: step.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 3) {
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

            card("À faire maintenant", icon: "bolt.fill") {
                Text(currentPlan.recommendedNextStep)
                    .font(.headline)
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
                ContentUnavailableView("Aucun plan", systemImage: "checklist", description: Text("Les plans créés par Nuance apparaîtront ici."))
            } else {
                List {
                    ForEach(store.plans) { plan in
                        NavigationLink {
                            ScrollView { PlanView(plan: plan, isSavedPlan: true).padding() }
                                .navigationTitle("Plan")
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(plan.objective).font(.headline).lineLimit(2)
                                Text(plan.detectedIntent)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(plan.createdAt, format: .dateTime.day().month().year().hour().minute())
                                    .font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .onDelete(perform: store.delete)
                }
            }
        }
        .navigationTitle("Mes plans")
        .toolbar { if !store.plans.isEmpty { EditButton() } }
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable(description: "Décision conversationnelle et éventuel plan personnalisé")
private struct GeneratedAssistantTurn {
    @Guide(description: "Message naturel et bref affiché à l’utilisateur. Si une question est nécessaire, une seule question.")
    var reply: String

    @Guide(description: "Résumé factuel de la situation comprise, sans invention")
    var situationSummary: String

    @Guide(description: "Faits importants explicitement fournis par l’utilisateur", .maximumCount(8))
    var knownFacts: [String]

    @Guide(description: "Vrai uniquement quand assez d’informations sont disponibles pour créer un plan personnalisé")
    var shouldBuildPlan: Bool

    @Guide(description: "Catégorie courte de l’objectif")
    var detectedIntent: String

    @Guide(description: "Priorités ou sous-objectifs essentiels", .maximumCount(5))
    var subgoals: [String]

    @Guide(description: "Informations encore incertaines ou à vérifier", .maximumCount(4))
    var missingInformation: [String]

    @Guide(description: "Étapes ordonnées, concrètes et adaptées à la situation", .maximumCount(7))
    var actionPlan: [GeneratedActionStep]

    @Guide(description: "Une seule action précise à effectuer maintenant")
    var recommendedNextStep: String
}

@available(iOS 26.0, *)
@Generable(description: "Une étape d’action personnalisée")
private struct GeneratedActionStep {
    @Guide(description: "Titre court de l’étape")
    var title: String

    @Guide(description: "Explication pratique et précise en une ou deux phrases")
    var details: String
}
#endif

#Preview {
    ContentView().environmentObject(GoalStore())
}

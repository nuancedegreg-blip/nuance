import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

struct ContentView: View {
    @EnvironmentObject private var store: GoalStore
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            CoachView(onOpenProjects: { selectedTab = 2 })
                .tabItem { Label("Nuance", systemImage: "sparkles") }
                .tag(0)

            TodayView()
                .tabItem { Label("Aujourd’hui", systemImage: "bolt.fill") }
                .tag(1)

            ProjectsView()
                .tabItem { Label("Projets", systemImage: "square.stack.3d.up.fill") }
                .tag(2)
        }
        .tint(.indigo)
    }
}

// MARK: - Assistant

private struct CoachView: View {
    @EnvironmentObject private var store: GoalStore
    let onOpenProjects: () -> Void

    @State private var input = ""
    @State private var messages: [ChatMessage] = []
    @State private var generatedPlan: GoalPlan?
    @State private var isGenerating = false
    @State private var aiStatus = "Vérification d’Apple Intelligence…"
    @State private var appleIntelligenceAvailable = false
    @State private var questionCount = 0
    @State private var knownFacts: [String] = []
    @State private var situationSummary = ""

    private let fallbackEngine = GoalEngine()

    var body: some View {
        NavigationStack {
            ZStack {
                NuanceBackground()

                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 14) {
                                hero
                                intelligencePill

                                if messages.isEmpty { starterPanel }

                                ForEach(messages) { message in
                                    MessageBubble(message: message)
                                        .id(message.id)
                                }

                                if isGenerating {
                                    ThinkingBubble()
                                        .id("thinking")
                                }

                                if !situationSummary.isEmpty {
                                    understandingCard
                                }

                                if let generatedPlan {
                                    GeneratedPlanCard(plan: generatedPlan, openProjects: onOpenProjects)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 20)
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .onChange(of: messages.count) { _, _ in scrollToBottom(proxy) }
                        .onChange(of: isGenerating) { _, _ in scrollToBottom(proxy) }
                    }

                    composer
                }
            }
            .navigationTitle("Nuance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if !messages.isEmpty && generatedPlan == nil {
                            Button("Créer le plan maintenant", systemImage: "wand.and.stars") { forcePlan() }
                        }
                        Button("Nouvelle conversation", systemImage: "arrow.counterclockwise") { resetConversation() }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .task { refreshAIStatus() }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(generatedPlan == nil ? "Qu’est-ce que tu veux changer ?" : "Continue, je t’écoute.")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text(generatedPlan == nil
                 ? "Parle normalement. Je comprends ta situation, je te pose les bonnes questions et je transforme ton objectif en prochaines actions."
                 : "Ton plan existe, mais la conversation continue. Tu peux me demander de l’expliquer, le remettre en question ou parler de ce qui change.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var intelligencePill: some View {
        HStack(spacing: 8) {
            Image(systemName: appleIntelligenceAvailable ? "apple.intelligence" : "cpu")
            Text(appleIntelligenceAvailable ? "Apple Intelligence · sur l’appareil" : "Moteur local de secours")
                .lineLimit(1)
            Spacer()
            Circle()
                .frame(width: 7, height: 7)
                .foregroundStyle(appleIntelligenceAvailable ? .green : .orange)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial, in: Capsule())
        .accessibilityLabel(aiStatus)
    }

    private var starterPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Commence par une phrase").font(.headline)
                    Text("Pas de formulaire. Pas de jargon.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "quote.bubble.fill")
                    .font(.title2)
                    .foregroundStyle(.indigo)
            }

            QuickPrompt(title: "Économiser", text: "Je veux économiser 500 € par mois", icon: "eurosign.circle.fill") { sendPreset($0) }
            QuickPrompt(title: "Projet", text: "Je veux lancer une activité qui rapporte", icon: "briefcase.fill") { sendPreset($0) }
            QuickPrompt(title: "Organisation", text: "Je veux reprendre le contrôle de mon organisation", icon: "calendar.badge.clock") { sendPreset($0) }
            QuickPrompt(title: "Ambition", text: "J’ai un gros objectif mais je ne sais pas par où commencer", icon: "flag.checkered") { sendPreset($0) }
        }
        .nuanceCard()
    }

    private var understandingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Ce que j’ai compris", systemImage: "brain.head.profile.fill")
                .font(.headline)
            Text(situationSummary)
                .font(.subheadline)
            if !knownFacts.isEmpty { FlowFacts(facts: Array(knownFacts.prefix(6))) }
        }
        .nuanceCard()
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField(generatedPlan == nil ? "Dis-moi ton objectif…" : "Continue la conversation…", text: $input, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .submitLabel(.send)
                .onSubmit { send() }

            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .frame(width: 43, height: 43)
                    .background(.indigo, in: Circle())
            }
            .disabled(isGenerating || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(isGenerating ? 0.45 : 1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private func sendPreset(_ text: String) {
        input = text
        send()
    }

    private func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isGenerating else { return }
        input = ""
        messages.append(ChatMessage(role: .user, text: text))
        isGenerating = true

        Task {
            if generatedPlan == nil {
                await processPlanningConversation(forcePlan: false)
            } else {
                await continueConversation()
            }
        }
    }

    private func forcePlan() {
        guard !messages.isEmpty, !isGenerating, generatedPlan == nil else { return }
        isGenerating = true
        Task { await processPlanningConversation(forcePlan: true) }
    }

    private func processPlanningConversation(forcePlan: Bool) async {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *), SystemLanguageModel.default.isAvailable {
            do {
                let transcript = transcriptText
                let session = LanguageModelSession(
                    model: SystemLanguageModel.default,
                    instructions: """
                    Tu es Nuance, un assistant personnel orienté résultats. Tu réponds en français.
                    Tu comprends la situation avant de conseiller et tu poses UNE seule question à la fois.
                    Ne redemande jamais une information déjà donnée. Cherche le résultat attendu, le point de départ, les contraintes, les ressources, le délai, le budget si pertinent, les blocages et le critère de réussite.
                    Après 2 à 5 questions utiles, construis un plan concret et personnalisé avec une première action immédiatement réalisable.
                    N’invente jamais de faits externes, prix, lois ou disponibilités.
                    Ton ton est naturel, direct et utile.
                    """
                )

                let decision = (forcePlan || questionCount >= 5)
                    ? "Produis le plan final maintenant avec ce que tu sais."
                    : "Décide si une seule question supplémentaire améliore vraiment le plan. Sinon, produis le plan final."

                let response = try await session.respond(
                    to: """
                    Conversation :
                    \(transcript)

                    Questions déjà posées : \(questionCount)
                    \(decision)

                    Si shouldBuildPlan=false, reply contient UNE seule question.
                    Si shouldBuildPlan=true, complète le plan et choisis UNE priorité immédiate.
                    """,
                    generating: GeneratedAssistantTurn.self
                )

                let turn = response.content
                await MainActor.run {
                    situationSummary = turn.situationSummary
                    knownFacts = turn.knownFacts

                    if turn.shouldBuildPlan {
                        let objective = messages.first(where: { $0.role == .user })?.text ?? "Objectif"
                        let plan = GoalPlan(
                            objective: objective,
                            detectedIntent: turn.detectedIntent,
                            subgoals: turn.subgoals,
                            missingInformation: turn.missingInformation,
                            actionPlan: turn.actionPlan.map { ActionStep(title: $0.title, details: $0.details) },
                            recommendedNextStep: turn.recommendedNextStep
                        )
                        messages.append(ChatMessage(role: .assistant, text: turn.reply))
                        generatedPlan = plan
                        store.add(plan)
                    } else {
                        questionCount += 1
                        messages.append(ChatMessage(role: .assistant, text: turn.reply))
                    }
                    isGenerating = false
                }
                return
            } catch {
                await MainActor.run { aiStatus = "Apple Intelligence n’a pas pu traiter ce tour. Mode local utilisé." }
            }
        }
#endif
        await MainActor.run {
            fallbackPlanning(forcePlan: forcePlan)
            isGenerating = false
        }
    }

    private func continueConversation() async {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *), SystemLanguageModel.default.isAvailable {
            do {
                let planText: String
                if let plan = generatedPlan {
                    planText = """
                    Objectif: \(plan.objective)
                    Type: \(plan.detectedIntent)
                    Prochaine action: \(plan.recommendedNextStep)
                    Étapes: \(plan.actionPlan.map { "\($0.title): \($0.details)" }.joined(separator: " | "))
                    """
                } else {
                    planText = "Aucun plan."
                }

                let session = LanguageModelSession(
                    model: SystemLanguageModel.default,
                    instructions: """
                    Tu es Nuance, l’assistant personnel de l’utilisateur. La conversation ne s’arrête jamais parce qu’un plan a été créé.
                    Réponds en français, de façon naturelle et concise. Utilise le plan et l’historique pour répondre aux questions, expliquer les choix, aider en cas de blocage, challenger une hypothèse et proposer un ajustement si la situation change.
                    Ne prétends pas avoir effectué d’action externe et n’invente pas de données factuelles absentes.
                    """
                )

                let response = try await session.respond(to: """
                Plan actuel :
                \(planText)

                Conversation :
                \(transcriptText)

                Réponds au dernier message de l’utilisateur. Ne termine pas la conversation et ne dis pas que le plan est figé.
                """)

                await MainActor.run {
                    messages.append(ChatMessage(role: .assistant, text: response.content))
                    isGenerating = false
                }
                return
            } catch {
                await MainActor.run { aiStatus = "Apple Intelligence est temporairement indisponible. Réponse locale utilisée." }
            }
        }
#endif
        await MainActor.run {
            messages.append(ChatMessage(
                role: .assistant,
                text: "Oui, on peut continuer. Dis-moi ce que tu veux modifier, ce qui te bloque ou ce qui a changé, et je m’appuie sur ton plan actuel pour t’aider."
            ))
            isGenerating = false
        }
    }

    private var transcriptText: String {
        messages.map { "\($0.role == .user ? "UTILISATEUR" : "NUANCE"): \($0.text)" }
            .joined(separator: "\n")
    }

    private func fallbackPlanning(forcePlan: Bool) {
        let userMessages = messages.filter { $0.role == .user }
        let firstObjective = userMessages.first?.text ?? "Objectif"

        if !forcePlan && questionCount < 3 {
            let questions = [
                "Où en es-tu aujourd’hui par rapport à cet objectif ?",
                "Qu’est-ce qui risque le plus de t’empêcher d’y arriver : temps, argent, organisation, motivation ou autre chose ?",
                "Quel résultat concret voudrais-tu voir, et dans quel délai ?"
            ]
            let question = questions[min(questionCount, questions.count - 1)]
            questionCount += 1
            messages.append(ChatMessage(role: .assistant, text: question))
            situationSummary = "Je précise ton point de départ, tes contraintes et le résultat que tu veux vraiment obtenir."
            return
        }

        let context = userMessages.map(\.text).joined(separator: " — ")
        let base = fallbackEngine.buildPlan(from: context)
        let plan = GoalPlan(
            objective: firstObjective,
            detectedIntent: base.detectedIntent,
            subgoals: base.subgoals,
            missingInformation: base.missingInformation,
            actionPlan: base.actionPlan,
            recommendedNextStep: base.recommendedNextStep
        )
        generatedPlan = plan
        store.add(plan)
        messages.append(ChatMessage(role: .assistant, text: "J’ai créé une première trajectoire. Et on peut continuer à en parler : le plan n’arrête pas la conversation."))
    }

    private func refreshAIStatus() {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                appleIntelligenceAvailable = true
                aiStatus = "Apple Intelligence disponible sur cet iPhone."
            case .unavailable(.deviceNotEligible):
                appleIntelligenceAvailable = false
                aiStatus = "Appareil non compatible Apple Intelligence."
            case .unavailable(.modelNotReady):
                appleIntelligenceAvailable = false
                aiStatus = "Le modèle Apple Intelligence n’est pas encore prêt."
            case .unavailable(.appleIntelligenceNotEnabled):
                appleIntelligenceAvailable = false
                aiStatus = "Apple Intelligence est désactivé dans Réglages."
            case .unavailable:
                appleIntelligenceAvailable = false
                aiStatus = "Apple Intelligence est indisponible pour le moment."
            }
            return
        }
#endif
        appleIntelligenceAvailable = false
        aiStatus = "Foundation Models nécessite iOS 26 ou plus récent."
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

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.25)) {
            if isGenerating {
                proxy.scrollTo("thinking", anchor: .bottom)
            } else if let last = messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}

// MARK: - Today

private struct TodayView: View {
    @EnvironmentObject private var store: GoalStore

    var body: some View {
        NavigationStack {
            ZStack {
                NuanceBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Aujourd’hui")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                        Text("Pas dix priorités. La bonne prochaine action.")
                            .foregroundStyle(.secondary)

                        if let plan = store.plans.first(where: { $0.actionPlan.contains(where: { !$0.isCompleted }) }),
                           let step = plan.actionPlan.first(where: { !$0.isCompleted }) {
                            FocusCard(plan: plan, step: step)
                        } else {
                            EmptyTodayCard()
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Focus")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct FocusCard: View {
    @EnvironmentObject private var store: GoalStore
    let plan: GoalPlan
    let step: ActionStep

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("PRIORITÉ DU JOUR", systemImage: "bolt.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.indigo)
                Spacer()
                ProgressBadge(plan: plan)
            }

            Text(step.title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(step.details)
                .foregroundStyle(.secondary)

            Button {
                store.toggleStep(planID: plan.id, stepID: step.id)
            } label: {
                Label("C’est fait", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
        }
        .nuanceCard()
    }
}

// MARK: - Projects

private struct ProjectsView: View {
    @EnvironmentObject private var store: GoalStore

    var body: some View {
        NavigationStack {
            ZStack {
                NuanceBackground()
                if store.plans.isEmpty {
                    ContentUnavailableView("Aucun projet", systemImage: "sparkles", description: Text("Crée ton premier objectif avec Nuance."))
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(store.plans) { plan in
                                NavigationLink {
                                    ProjectDetailView(plan: plan)
                                } label: {
                                    ProjectCard(plan: plan)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Mes projets")
        }
    }
}

private struct ProjectDetailView: View {
    @EnvironmentObject private var store: GoalStore
    let plan: GoalPlan

    private var current: GoalPlan {
        store.plans.first(where: { $0.id == plan.id }) ?? plan
    }

    var body: some View {
        ZStack {
            NuanceBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(current.objective)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                        HStack {
                            Text(current.detectedIntent)
                                .font(.caption.bold())
                            Spacer()
                            ProgressBadge(plan: current)
                        }
                    }
                    .nuanceCard()

                    VStack(alignment: .leading, spacing: 12) {
                        Label("Plan d’action", systemImage: "checklist")
                            .font(.title3.bold())
                        ForEach(current.actionPlan) { step in
                            Button {
                                store.toggleStep(planID: current.id, stepID: step.id)
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: step.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(step.isCompleted ? .green : .indigo)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(step.title)
                                            .font(.headline)
                                            .strikethrough(step.isCompleted)
                                            .foregroundStyle(.primary)
                                        Text(step.details)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .nuanceCard()

                    ShareLink(item: shareText) {
                        Label("Partager mon plan", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(16)
            }
        }
        .navigationTitle("Projet")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var shareText: String {
        let steps = current.actionPlan.enumerated().map { "\($0.offset + 1). \($0.element.title)" }.joined(separator: "\n")
        return "Objectif : \(current.objective)\n\nPlan Nuance :\n\(steps)\n\nProchaine action : \(current.recommendedNextStep)"
    }
}

// MARK: - Design

private struct NuanceBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color.indigo.opacity(0.10), Color.clear, Color.purple.opacity(0.06)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private struct QuickPrompt: View {
    let title: String
    let text: String
    let icon: String
    let action: (String) -> Void

    var body: some View {
        Button { action(text) } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.indigo)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.bold())
                    Text(text).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer()
                Image(systemName: "arrow.up.right").font(.caption.bold()).foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

private struct FlowFacts: View {
    let facts: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(facts, id: \.self) { fact in
                Label(fact, systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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
        HStack(alignment: .bottom) {
            if message.role == .user { Spacer(minLength: 48) }
            VStack(alignment: .leading, spacing: 6) {
                if message.role == .assistant {
                    Label("Nuance", systemImage: "sparkles")
                        .font(.caption.bold())
                        .foregroundStyle(.indigo)
                }
                Text(message.text).textSelection(.enabled)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                message.role == .user ? AnyShapeStyle(Color.indigo.opacity(0.16)) : AnyShapeStyle(.ultraThinMaterial),
                in: RoundedRectangle(cornerRadius: 19)
            )
            if message.role == .assistant { Spacer(minLength: 34) }
        }
    }
}

private struct ThinkingBubble: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text("Nuance réfléchit…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(13)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct GeneratedPlanCard: View {
    let plan: GoalPlan
    let openProjects: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Plan créé", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                Spacer()
                ProgressBadge(plan: plan)
            }
            Text(plan.recommendedNextStep).font(.title3.bold())
            Text("Le plan est enregistré, mais tu peux continuer à discuter avec Nuance juste en dessous.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button(action: openProjects) {
                Label("Ouvrir le projet", systemImage: "arrow.right.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
        }
        .nuanceCard()
    }
}

private struct ProjectCard: View {
    let plan: GoalPlan
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.detectedIntent.uppercased())
                        .font(.caption2.bold())
                        .foregroundStyle(.indigo)
                    Text(plan.objective).font(.title3.bold()).lineLimit(2)
                }
                Spacer()
                ProgressBadge(plan: plan)
            }
            if let next = plan.actionPlan.first(where: { !$0.isCompleted }) {
                Label(next.title, systemImage: "bolt.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            } else {
                Label("Objectif terminé", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .nuanceCard()
    }
}

private struct ProgressBadge: View {
    let plan: GoalPlan
    private var progress: Int {
        guard !plan.actionPlan.isEmpty else { return 0 }
        let done = plan.actionPlan.filter(\.isCompleted).count
        return Int((Double(done) / Double(plan.actionPlan.count)) * 100)
    }
    var body: some View {
        Text("\(progress)%")
            .font(.caption.bold())
            .monospacedDigit()
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(.thinMaterial, in: Capsule())
    }
}

private struct EmptyTodayCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "sparkles").font(.largeTitle).foregroundStyle(.indigo)
            Text("Rien à prioriser pour l’instant").font(.title2.bold())
            Text("Crée un objectif avec Nuance. Dès qu’un plan existe, cette page te montre la prochaine action la plus utile.")
                .foregroundStyle(.secondary)
        }
        .nuanceCard()
    }
}

private extension View {
    func nuanceCard() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.primary.opacity(0.055), lineWidth: 1)
            }
    }
}

// MARK: - Foundation Models

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable(description: "Un tour de conversation intelligent de l’assistant Nuance")
private struct GeneratedAssistantTurn {
    @Guide(description: "true si les informations suffisent pour produire un plan, false si une question est encore nécessaire")
    var shouldBuildPlan: Bool
    @Guide(description: "Message naturel et court affiché à l’utilisateur")
    var reply: String
    @Guide(description: "Résumé fidèle de la situation comprise")
    var situationSummary: String
    @Guide(description: "Faits importants explicitement donnés par l’utilisateur")
    var knownFacts: [String]
    @Guide(description: "Catégorie courte de l’objectif")
    var detectedIntent: String
    @Guide(description: "Sous-objectifs prioritaires")
    var subgoals: [String]
    @Guide(description: "Informations encore manquantes")
    var missingInformation: [String]
    @Guide(description: "Étapes concrètes et ordonnées")
    var actionPlan: [GeneratedActionStep]
    @Guide(description: "Une seule action immédiate, précise et réalisable")
    var recommendedNextStep: String
}

@available(iOS 26.0, *)
@Generable(description: "Une étape concrète d’un plan")
private struct GeneratedActionStep {
    @Guide(description: "Titre court et orienté action")
    var title: String
    @Guide(description: "Explication pratique en une ou deux phrases")
    var details: String
}
#endif

#Preview {
    ContentView().environmentObject(GoalStore())
}

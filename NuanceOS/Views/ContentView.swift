import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: GoalStore
    @State private var objective = ""
    @State private var generatedPlan: GoalPlan?
    @State private var selectedTab = 0

    private let engine = GoalEngine()

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        hero
                        objectiveCard

                        if let generatedPlan {
                            PlanView(plan: generatedPlan, isSavedPlan: false)
                        }
                    }
                    .padding()
                }
                .navigationTitle("NuanceOS")
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

    private var objectiveCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Ex : Économiser 500 € par mois", text: $objective, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)

            Button {
                generate()
            } label: {
                Label("Atteindre cet objectif", systemImage: "arrow.right.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
            }
            .buttonStyle(.borderedProminent)
            .disabled(objective.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private func generate() {
        let plan = engine.buildPlan(from: objective)
        generatedPlan = plan
        store.add(plan)
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

            section("Plan d'action", systemImage: "checklist") {
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

#Preview {
    ContentView()
        .environmentObject(GoalStore())
}

import SwiftUI
import ARKit
import RealityKit

struct ARStudioView: View {
    @EnvironmentObject private var store: GoalStore
    @Environment(\.dismiss) private var dismiss

    @State private var mode: ARMode = .action
    @State private var measuredDistance: Double?
    @State private var resetToken = UUID()

    private var activePlan: GoalPlan? {
        store.activePlans.first
    }

    private var actionTitle: String {
        guard let plan = activePlan,
              let next = store.nextAction(for: plan) else {
            return "Crée d’abord un projet dans Nuance"
        }
        return next.title
    }

    var body: some View {
        ZStack {
            NuanceARContainer(
                mode: mode,
                actionTitle: actionTitle,
                measuredDistance: $measuredDistance,
                resetToken: resetToken
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer()
                bottomPanel
            }
        }
        .background(.black)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.bold())
                    .frame(width: 42, height: 42)
                    .background(.ultraThinMaterial, in: Circle())
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Nuance AR")
                    .font(.headline)
                Text(mode == .action ? "Place ta prochaine action dans le monde réel" : "Mesure rapidement une distance")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                resetToken = UUID()
                measuredDistance = nil
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.headline)
                    .frame(width: 42, height: 42)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var bottomPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Mode AR", selection: $mode) {
                Label("Action", systemImage: "bolt.fill").tag(ARMode.action)
                Label("Mesure", systemImage: "ruler").tag(ARMode.measure)
            }
            .pickerStyle(.segmented)

            if mode == .action {
                VStack(alignment: .leading, spacing: 6) {
                    Text("PROCHAINE ACTION")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    Text(actionTitle)
                        .font(.headline)
                        .lineLimit(2)
                    Text("Pointe une surface puis touche l’écran pour poser un repère AR.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("MESURE AR")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    if let measuredDistance {
                        Text(String(format: "%.2f m", measuredDistance))
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    } else {
                        Text("Touche deux points dans la scène")
                            .font(.headline)
                    }
                    Text("La mesure AR est indicative et ne remplace pas un instrument de mesure certifié.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .padding(16)
    }
}

enum ARMode: Hashable {
    case action
    case measure
}

private struct NuanceARContainer: UIViewRepresentable {
    let mode: ARMode
    let actionTitle: String
    @Binding var measuredDistance: Double?
    let resetToken: UUID

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero)
        context.coordinator.arView = view

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic

        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
            view.environment.sceneUnderstanding.options.insert(.occlusion)
            view.environment.sceneUnderstanding.options.insert(.physics)
        }

        view.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.handleResetIfNeeded(resetToken)
    }

    final class Coordinator: NSObject {
        var parent: NuanceARContainer
        weak var arView: ARView?
        private var firstMeasurementPoint: SIMD3<Float>?
        private var lastResetToken: UUID
        private var placedAnchors: [AnchorEntity] = []

        init(parent: NuanceARContainer) {
            self.parent = parent
            self.lastResetToken = parent.resetToken
        }

        func handleResetIfNeeded(_ token: UUID) {
            guard token != lastResetToken else { return }
            lastResetToken = token
            firstMeasurementPoint = nil
            placedAnchors.forEach { $0.removeFromParent() }
            placedAnchors.removeAll()
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let arView else { return }
            let point = recognizer.location(in: arView)

            guard let result = arView.raycast(
                from: point,
                allowing: .estimatedPlane,
                alignment: .any
            ).first else { return }

            let worldPosition = SIMD3<Float>(
                result.worldTransform.columns.3.x,
                result.worldTransform.columns.3.y,
                result.worldTransform.columns.3.z
            )

            switch parent.mode {
            case .action:
                placeActionMarker(at: worldPosition, in: arView)
            case .measure:
                handleMeasurementPoint(worldPosition, in: arView)
            }
        }

        private func placeActionMarker(at position: SIMD3<Float>, in arView: ARView) {
            let anchor = AnchorEntity(world: position)

            let marker = ModelEntity(
                mesh: .generateSphere(radius: 0.035),
                materials: [SimpleMaterial(color: .systemIndigo, isMetallic: true)]
            )
            marker.position.y = 0.035
            anchor.addChild(marker)

            let stem = ModelEntity(
                mesh: .generateBox(size: [0.008, 0.12, 0.008]),
                materials: [SimpleMaterial(color: .white, isMetallic: false)]
            )
            stem.position.y = 0.10
            anchor.addChild(stem)

            let plate = ModelEntity(
                mesh: .generateBox(size: [0.26, 0.10, 0.012]),
                materials: [SimpleMaterial(color: UIColor.systemBackground.withAlphaComponent(0.92), isMetallic: false)]
            )
            plate.position = [0, 0.20, 0]
            anchor.addChild(plate)

            arView.scene.addAnchor(anchor)
            placedAnchors.append(anchor)
        }

        private func handleMeasurementPoint(_ point: SIMD3<Float>, in arView: ARView) {
            placeMeasurementDot(at: point, in: arView)

            if let first = firstMeasurementPoint {
                let distance = simd_distance(first, point)
                firstMeasurementPoint = nil
                parent.measuredDistance = Double(distance)
                placeMeasurementLine(from: first, to: point, in: arView)
            } else {
                firstMeasurementPoint = point
                parent.measuredDistance = nil
            }
        }

        private func placeMeasurementDot(at point: SIMD3<Float>, in arView: ARView) {
            let anchor = AnchorEntity(world: point)
            let dot = ModelEntity(
                mesh: .generateSphere(radius: 0.012),
                materials: [SimpleMaterial(color: .systemYellow, isMetallic: false)]
            )
            anchor.addChild(dot)
            arView.scene.addAnchor(anchor)
            placedAnchors.append(anchor)
        }

        private func placeMeasurementLine(from start: SIMD3<Float>, to end: SIMD3<Float>, in arView: ARView) {
            let delta = end - start
            let length = simd_length(delta)
            guard length > 0.001 else { return }

            let midpoint = (start + end) / 2
            let anchor = AnchorEntity(world: midpoint)
            let line = ModelEntity(
                mesh: .generateBox(size: [0.006, 0.006, length]),
                materials: [SimpleMaterial(color: .systemYellow, isMetallic: false)]
            )
            line.look(at: end, from: midpoint, relativeTo: nil)
            anchor.addChild(line)
            arView.scene.addAnchor(anchor)
            placedAnchors.append(anchor)
        }
    }
}

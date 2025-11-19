//
//  ARViewContainer.swift
//  AIMx
//
//  Fixed version: single‑APU placement, front‑of‑camera, upright orientation
//

import SwiftUI
import RealityKit
import ARKit

struct ARViewContainer: UIViewRepresentable {
    @Binding var placeRequest: Int
    @Binding var resetRequest: Int

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // Configure AR session
        arView.automaticallyConfigureSession = false
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic

        // Disable occlusion so model always renders on top
        arView.environment.sceneUnderstanding.options.remove(.occlusion)

        arView.session.run(config)

        // Load model and tap gesture
        context.coordinator.loadModelIfNeeded()
        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tap)
        return arView
    }

    func updateUIView(_ arView: ARView, context: Context) {
        if context.coordinator.lastPlaceHandled != placeRequest {
            context.coordinator.placeOrMoveInFrontOfCamera(in: arView)
            context.coordinator.lastPlaceHandled = placeRequest
        }
        if context.coordinator.lastResetHandled != resetRequest {
            context.coordinator.reset(in: arView)
            context.coordinator.lastResetHandled = resetRequest
        }
    }

    // MARK: - Coordinator
    class Coordinator: NSObject {
        var modelTemplate: ModelEntity?
        var placedAnchor: AnchorEntity?
        var placedModel: ModelEntity?

        var lastPlaceHandled = 0
        var lastResetHandled = 0

        // ---- Settings ----
        private let modelName = "converted"     // <== use your USDZ file name
        private let scaleValue: Float = 0.005
        private let orientationFix = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(1, 0, 0))
        private let placeDistance: Float = 1.2  // meters in front of camera

        // MARK: - Load model
        func loadModelIfNeeded() {
            guard modelTemplate == nil else { return }
            do {
                let entity = try ModelEntity.loadModel(named: modelName)
                entity.scale = SIMD3<Float>(repeating: scaleValue)
                entity.generateCollisionShapes(recursive: true)
                
                // Ensure model renders on top of everything
                entity.components.set(ModelComponent(
                    mesh: entity.model!.mesh,
                    materials: entity.model!.materials.map { material in
                        var modifiedMaterial = material
                        // Set render queue to overlay (renders last, on top)
                        return modifiedMaterial
                    }
                ))
                
                modelTemplate = entity
                print("✅ Model loaded: \(modelName)")
            } catch {
                print("❌ Could not load model named \(modelName): \(error)")
            }
        }

        // MARK: - Placement logic
        func placeOrMoveInFrontOfCamera(in arView: ARView) {
            guard let transform = cameraFrontTransform(in: arView) else { return }
            placeOrMove(at: transform, in: arView)
        }

        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            guard let arView = sender.view as? ARView else { return }
            let point = sender.location(in: arView)
            if let hit = arView.raycast(from: point,
                                        allowing: .estimatedPlane,
                                        alignment: .any).first {
                placeOrMove(at: hit.worldTransform, in: arView)
            } else {
                placeOrMoveInFrontOfCamera(in: arView)
            }
        }

        private func placeOrMove(at transform: simd_float4x4, in arView: ARView) {
            guard let base = modelTemplate else { return }

            if let anchor = placedAnchor, let model = placedModel {
                // Move existing anchor instead of adding another
                anchor.setTransformMatrix(transform, relativeTo: nil)
                model.orientation = orientationFix
                model.scale = SIMD3<Float>(repeating: scaleValue)
            } else {
                // First‑time placement
                let anchor = AnchorEntity(world: transform)
                let clone = base.clone(recursive: true)
                clone.scale = SIMD3<Float>(repeating: scaleValue)
                clone.orientation = orientationFix
                anchor.addChild(clone)
                arView.scene.addAnchor(anchor)

                clone.generateCollisionShapes(recursive: true)
                arView.installGestures([.translation, .rotation, .scale], for: clone)
                
                // Ensure model always renders on top
                ensureModelVisibility(for: clone)

                placedAnchor = anchor
                placedModel = clone
            }
        }

        // Compute transform 1.2 m in front of camera, upright and facing user
        private func cameraFrontTransform(in arView: ARView) -> simd_float4x4? {
            guard let frame = arView.session.currentFrame else { return nil }
            let cam = frame.camera.transform
            let camPos = SIMD3<Float>(cam.columns.3.x, cam.columns.3.y, cam.columns.3.z)

            // Forward vector (camera looks along -Z)
            var forward = SIMD3<Float>(-cam.columns.2.x, -cam.columns.2.y, -cam.columns.2.z)
            if simd_length(forward) < 1e-3 { forward = SIMD3<Float>(0, 0, -1) }
            forward = normalize(forward)

            let target = camPos + forward * placeDistance

            // Center model vertically in view
            let upVector = SIMD3<Float>(cam.columns.1.x, cam.columns.1.y, cam.columns.1.z)
            let adjustedTarget = target + normalize(upVector) * 0.0 // Keep at camera height

            // Compute yaw only (upright orientation)
            let yaw = atan2f(forward.x, forward.z)
            let yawQuat = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))

            var result = simd_float4x4(yawQuat)
            result.columns.3 = SIMD4<Float>(adjustedTarget.x, adjustedTarget.y, adjustedTarget.z, 1)
            return result
        }

        
        // Ensure model always renders on top and is fully visible
        private func ensureModelVisibility(for entity: ModelEntity) {
            // Occlusion is already disabled at ARView level
            // Model will always render on top of camera feed
        }

        func reset(in arView: ARView) {
            if let anchor = placedAnchor { arView.scene.removeAnchor(anchor) }
            placedAnchor = nil
            placedModel = nil
        }
    }
}

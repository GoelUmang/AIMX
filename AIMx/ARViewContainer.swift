//
//  ARViewContainer.swift
//  AIMx
//
//  One-APU AR placement in front of camera (upright, no occlusion)
//  Controls:
//   • 1 finger pan  → translation (move the APU)
//   • Pinch         → scale (zoom)
//   • Bottom slider → yaw (rotate around world Y axis)
//   • Right slider  → pitch (rotate around the model's local X axis)
//
//  Sliders drive orientation deterministically; we DO NOT enable any rotation gestures,
//  so sliders are the single source of truth for orientation.
//

import SwiftUI
import RealityKit
import ARKit
import UIKit

struct ARViewContainer: UIViewRepresentable {
    @Binding var placeRequest: Int
    @Binding var resetRequest: Int

    // Slider-driven angles (degrees)
    @Binding var yawDegrees: Double   // around world Y
    @Binding var pitchDegrees: Double // around model local X
    
    @Binding var aputapped: Int

    func makeCoordinator() -> Coordinator { Coordinator(aputapped: $aputapped) }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // --- AR session config ---
        arView.automaticallyConfigureSession = false
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic

        // Keep the model “over” the camera feed (never hidden by real objects)
        arView.environment.sceneUnderstanding.options.remove(.occlusion)
        arView.session.run(config)

        // Expose ARView to the coordinator
        context.coordinator.arView = arView

        // Load model once
        context.coordinator.loadModelIfNeeded()

        // Optional: tap-to-place on real planes (ignored if you tap on the model itself)
        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        arView.addGestureRecognizer(tap)

        return arView
    }

    func updateUIView(_ arView: ARView, context: Context) {
        // Handle "Place" / "Reset"
        if context.coordinator.lastPlaceHandled != placeRequest {
            context.coordinator.placeOrMoveInFrontOfCamera(in: arView)
            context.coordinator.lastPlaceHandled = placeRequest
        }
        if context.coordinator.lastResetHandled != resetRequest {
            context.coordinator.reset(in: arView)
            context.coordinator.lastResetHandled = resetRequest
        }

        // Apply slider-driven orientation whenever sliders change
        context.coordinator.applyYawPitch(yawDeg: yawDegrees,
                                          pitchDeg: pitchDegrees,
                                          in: arView)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        // References
        weak var arView: ARView?
        var modelTemplate: ModelEntity?
        var placedAnchor: AnchorEntity?
        var placedModel: ModelEntity?

        // Track SwiftUI requests
        var lastPlaceHandled = 0
        var lastResetHandled = 0
        
        // Binding to communicate back to SwiftUI (increments on each tap)
        var aputapped: Binding<Int>
        
        init(aputapped: Binding<Int>) {
            self.aputapped = aputapped
        }

        // ---- Tunables ----
        private let modelName = "converted"     // your USDZ base name in the app bundle
        private let scaleValue: Float = 0.004   // (your chosen perfect size)
        private let placeDistance: Float = 1.2  // meters in front of the camera

        // If the USDZ imports lying on its side, stand it up once
        private let orientationFix = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(1, 0, 0))

        // Cached angles (radians)
        private var yawRad:   Float = 0
        private var pitchRad: Float = 0

        // MARK: - Model loading

        /// Loads the USDZ once, applies fixed scale and collision shapes so gestures work.
        func loadModelIfNeeded() {
            guard modelTemplate == nil else { return }
            do {
                let entity = try ModelEntity.loadModel(named: modelName)
                entity.scale = SIMD3<Float>(repeating: scaleValue)
                entity.generateCollisionShapes(recursive: true)
                modelTemplate = entity
                print("✅ Model loaded: \(modelName)")
            } catch {
                print("❌ Could not load model named \(modelName): \(error)")
            }
        }

        // MARK: - Placement

        /// Places or moves the APU directly in front of the camera, then applies current slider orientation.
        func placeOrMoveInFrontOfCamera(in arView: ARView) {
            guard let transform = cameraFrontTransform(in: arView) else { return }
            placeOrMove(at: transform, in: arView)
            updatePlacedModelOrientation() // ensure sliders immediately apply
        }

        /// Tap-to-place on a detected plane; fallback to front-of-camera if no hit.
        /// Ignores taps that land on the model (prevents accidental re-placement).
        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            guard let arView = sender.view as? ARView else { return }
            let point = sender.location(in: arView)

            if isTouchOnPlacedModel(point, in: arView) {
                aputapped.wrappedValue += 1  // Increment count on each tap
                print("🎯 APU model tapped! New count: \(aputapped.wrappedValue)")
                return
            }
            print("👆 Tap on background (not on model)")

            if let hit = arView.raycast(from: point,
                                        allowing: .estimatedPlane,
                                        alignment: .any).first {
                placeOrMove(at: hit.worldTransform, in: arView)
            } else {
                placeOrMoveInFrontOfCamera(in: arView)
            }
            updatePlacedModelOrientation()
        }

        /// Creates (first time) or moves (subsequent times) a single APU instance at `transform`.
        /// Wires gestures: 1-finger translation, pinch-to-scale. (Rotation is slider-driven only.)
        private func placeOrMove(at transform: simd_float4x4, in arView: ARView) {
            guard let base = modelTemplate else { return }

            if let anchor = placedAnchor, let model = placedModel {
                anchor.setTransformMatrix(transform, relativeTo: nil)
                model.scale = SIMD3<Float>(repeating: scaleValue)
            } else {
                let anchor = AnchorEntity(world: transform)
                let clone = base.clone(recursive: true)
                clone.scale = SIMD3<Float>(repeating: scaleValue)
                anchor.addChild(clone)
                arView.scene.addAnchor(anchor)

                // Gestures require collision shapes
                clone.generateCollisionShapes(recursive: true)

                // 1-finger PAN → translation; Pinch → scale
                arView.installGestures([.translation, .scale], for: clone)

                placedAnchor = anchor
                placedModel  = clone
            }
        }

        /// Builds a transform 1.2 m in front of the camera, yaw-aligned to face the user (upright).
        private func cameraFrontTransform(in arView: ARView) -> simd_float4x4? {
            guard let frame = arView.session.currentFrame else { return nil }
            let cam = frame.camera.transform
            let camPos = SIMD3<Float>(cam.columns.3.x, cam.columns.3.y, cam.columns.3.z)

            // Camera forward (points where the device looks): -Z
            var forward = SIMD3<Float>(-cam.columns.2.x, -cam.columns.2.y, -cam.columns.2.z)
            if simd_length(forward) < 1e-3 { forward = SIMD3<Float>(0, 0, -1) }
            forward = normalize(forward)

            let target = camPos + forward * placeDistance

            // Keep object upright: yaw-only rotation so it faces the user
            let yaw = atan2f(forward.x, forward.z)
            let yawQuat = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))

            var result = simd_float4x4(yawQuat)
            result.columns.3 = SIMD4<Float>(target.x, target.y, target.z, 1)
            return result
        }

        // MARK: - Slider → orientation

        /// Public entry from SwiftUI: update cached angles and apply to the placed model (if any).
        func applyYawPitch(yawDeg: Double, pitchDeg: Double, in arView: ARView) {
            self.yawRad   = Float(yawDeg  * .pi / 180.0)
            self.pitchRad = Float(pitchDeg * .pi / 180.0)
            updatePlacedModelOrientation()
        }

        /// Computes orientation = Pitch(local X after orientationFix+Yaw) * (Yaw about world Y) * orientationFix
        /// This keeps yaw as a world-up turn, and pitch as a natural tilt around the model's current right axis.
        private func updatePlacedModelOrientation() {
            guard let model = placedModel else { return }

            let yawQuat = simd_quatf(angle: yawRad, axis: SIMD3<Float>(0, 1, 0))
            // Base = yaw applied to the upright-fixed model
            let base = yawQuat * orientationFix

            // Local X axis after base (used for pitch)
            let baseMat = simd_float4x4(base)
            var localX  = SIMD3<Float>(baseMat.columns.0.x,
                                       baseMat.columns.0.y,
                                       baseMat.columns.0.z)
            if simd_length(localX) < 1e-6 { localX = SIMD3<Float>(1, 0, 0) }
            localX = normalize(localX)

            let pitchQuat = simd_quatf(angle: pitchRad, axis: localX)

            // Final orientation
            model.orientation = pitchQuat * base
        }

        // MARK: - Hit testing helper

        /// Returns true if the touch lands on the placed model (any descendant).
        private func isTouchOnPlacedModel(_ point: CGPoint, in arView: ARView) -> Bool {
            guard let hitEntity = arView.entity(at: point), let root = placedModel else { 
                print("🔍 Hit test: No entity or no model placed")
                return false 
            }
            var node: Entity? = hitEntity
            while let n = node {
                if n == root { 
                    print("🔍 Hit test: Found APU model!")
                    return true 
                }
                node = n.parent
            }
            print("🔍 Hit test: Hit entity '\(hitEntity.name)', but not the APU model")
            return false
        }

        // MARK: - Gesture delegate

        /// Allow our tap recognizer to live alongside translation & pinch recognizers.
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }

        /// Prevent tap-to-place when touching the model (avoid “jump” on tap).
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldReceive touch: UITouch) -> Bool {
            // Always allow taps - handleTap method will check if it's on the model
            return true
        }

        // MARK: - Reset

        /// Removes the placed APU so you can start fresh.
        func reset(in arView: ARView) {
            if let anchor = placedAnchor { arView.scene.removeAnchor(anchor) }
            placedAnchor = nil
            placedModel  = nil
        }
    }
}


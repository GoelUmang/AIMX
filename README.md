# AIMX — Augmented Reality APU Maintenance Assistant

> An iPad AR application for aircraft maintenance workflows — place, inspect, and rotate a virtual APU while surfacing real-time component data and technical manuals, all in one interface.

---

## Demo

<!-- Demo video showing APU placement, gesture manipulation, and the info panel -->
<video src="https://github.com/GoelUmang/AIMX/raw/main/demo_AIMX.mov" controls="controls" muted="muted" playsinline="playsinline" style="max-width: 100%; height: auto;"></video>

---

## Overview

AIMX is an augmented reality maintenance assistance application built to streamline technician workflows through interactive 3D visualization and real-time contextual information. Designed for iPad using SwiftUI and RealityKit/ARKit, it enables intuitive manipulation of a virtual Auxiliary Power Unit (APU) while surfacing critical maintenance data directly in the field of view.

This project emphasizes performance, usability, and real-world applicability in maintenance environments.

### Key Impact

- Accelerated maintenance inspection workflows by enabling direct AR-based interaction with components
- Reduced context-switching by consolidating manuals and component metadata into a single interface
- Achieved smooth, low-latency interaction through optimized gesture handling and rendering pipeline
- Designed scalable architecture to support additional components, datasets, and workflows

---

## Features

### 🔧 Interactive 3D APU Model
- Dynamically loads USDZ model in AR space, placed 1.2 m in front of the camera
- Optimized initial scaling for realistic field placement
- Occlusion disabled to ensure persistent model visibility during interaction

### High-Performance Gesture System
- One-finger pan for precise spatial repositioning
- Pinch-to-scale with smooth interpolation
- Tap-to-place on detected planes (horizontal and vertical); falls back to front-of-camera

###  Fine-Grained Orientation Control
- Bottom horizontal slider — yaw (world Y-axis rotation)
- Right vertical slider — pitch (model local X-axis tilt)
- Sliders are the single source of truth for orientation; no gesture conflicts

###  Contextual Maintenance Data Access
- Embedded PDF viewer for instant access to the APU technical manual
- Tap-based interaction to retrieve component-level metadata in AR
- Info card displays: component name, part number (P/N), life limit, APU cycles remaining

###  Minimal, Functional UI
- Compact overlay design to maximize AR viewport
- Top-left menu for quick access to tools
- Draggable floating panels for flexible in-field use

###  Observability & Debugging
- Integrated debug logging across all gesture and UI events
- Facilitates rapid iteration and performance tuning

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift 5 |
| UI Framework | SwiftUI |
| AR Engine | ARKit + RealityKit |
| PDF Viewer | PDFKit |
| 3D Model Format | USDZ |
| Min Deployment | iOS 14+ |
| IDE | Xcode |

---

## Project Structure

```
AIMx/
├── AppDelegate.swift       # App entry point; configures UISceneSession
├── SceneDelegate.swift     # Bootstraps the SwiftUI window
├── ContentView.swift       # Main UI: AR overlay, menu, sliders, info card, manual viewer
├── ARViewContainer.swift   # UIViewRepresentable wrapping ARView; all AR logic lives here
└── Resources/
    ├── converted.usdz      # APU 3D model (must be added to app bundle)
    └── Manual_APU.pdf      # APU maintenance manual (must be added to app bundle)
```

---

## Getting Started

### Prerequisites

- macOS with Xcode 15 or later
- ARKit-supported iPad or iPhone (A12 chip or later)
- iOS 14.0+ — AR requires a physical device; simulator will not work

### Setup

1. Clone the repository and open `AIMx.xcodeproj` in Xcode
2. Add your assets to the Xcode target:
   - `converted.usdz` — the APU 3D model
   - `Manual_APU.pdf` — the maintenance manual
3. Ensure both files are listed under **Build Phases → Copy Bundle Resources** (the app will crash at launch if either is missing)
4. Select your physical iOS/iPadOS device as the build target
5. Build and run (`⌘R`)

---

## Usage

| Action | How |
|---|---|
| Place APU | Tap **Place APU** at the bottom |
| Move APU | 1-finger drag on the model |
| Scale APU | Pinch on the model |
| Rotate (Yaw) | Drag the horizontal slider at the bottom |
| Rotate (Pitch) | Drag the vertical slider on the right |
| Tap-to-place on surface | Tap any detected plane in the scene |
| View part info | Menu → **Show Info**, then tap the APU model |
| View manual | Menu → **Show Manuals** (drag the card to reposition) |
| Reset scene | Tap **Reset** (removes model, zeroes sliders) |

---

## Configuration

Key tunables in `ARViewContainer.swift`:

```swift
private let modelName      = "converted"  // USDZ base name — rename to match your asset
private let scaleValue: Float = 0.004     // Initial display scale
private let placeDistance: Float = 1.2    // Meters in front of camera on placement

// If your model imports lying on its side, this upright-fix rotation corrects it
private let orientationFix = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(1, 0, 0))
```

---

## Known Limitations

- **Demo data only** — the info card uses hardcoded part rows. Wire `ContentView.demoRows` to a real database or API for production use.
- **Single-page manual** — the PDF viewer renders one page at a time. Extend `PDFKitSinglePageView` with scroll support for multi-page manuals.
- **No occlusion** — the model always renders on top of real-world geometry by design. Re-enable via `arView.environment.sceneUnderstanding.options.insert(.occlusion)` if needed (requires LiDAR).

---

## Future Work

- Integration with real-time maintenance databases
- Voice-enabled commands for hands-free operation in the field
- Multi-user collaborative AR sessions
- Guided repair workflows with step-by-step overlays

---

## Author and Creator

**Umang Goel**  
B.S. Computer Science, Arizona State University

---

*This project was developed as part of the AIMX initiative to explore AR-driven maintenance solutions.*

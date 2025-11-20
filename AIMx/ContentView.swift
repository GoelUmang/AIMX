import SwiftUI
import RealityKit
import ARKit
import PDFKit

// MARK: - ContentView
struct ContentView: View {
    // ---- AR controls / sliders state ----
    @State private var placeRequest = 0
    @State private var resetRequest = 0
    @State private var yawDeg: Double = 0
    @State private var pitchDeg: Double = 0

    // ---- Menu / overlays ----
    @State private var showMenu = false
    @State private var showManual = false

    // "Show Info" is your mode toggle; the card appears when APU is tapped
    @State private var showInfoCard = false
    // Set by ARViewContainer when the APU model is tapped (we toggle this every tap)
    @State private var lastAPUTapped = false

    // ---- Manual drag offset ----
    @State private var manualOffset: CGSize = .zero
    @GestureState private var dragOffset = CGSize.zero

    // ============================================================
    // MARK: Demo data for "Show Info" card (from your screenshot)
    // ============================================================
    struct PartRow: Identifiable {
        let id = UUID()
        let item: String
        let pn: String
        let lifeLimit: String
        let apuCyclesRemaining: String
    }

    // Any row will do for the demo; we rotate randomly on each tap
    private let demoRows: [PartRow] = [
        .init(item: "Comp. Rotor EC",          pn: "3822391-6", lifeLimit: "29,065", apuCyclesRemaining: "27,245"),
        .init(item: "1st Stage Turbine Disk",  pn: "3840310-3", lifeLimit: "29,065", apuCyclesRemaining: "18,461"),
        .init(item: "2nd Stage Turbine Disk",  pn: "3840165-4", lifeLimit: "29,065", apuCyclesRemaining: "18,461"),
        .init(item: "Turbine Shaft",           pn: "3822504-3", lifeLimit: "29,065", apuCyclesRemaining: "18,461")
    ]

    // The row currently shown in the info card
    @State private var currentInfoRow: PartRow? = nil

    var body: some View {
        ZStack {
            // ====================================================
            // MARK: AR view container (no UI/layout changes here)
            // ====================================================
            ARViewContainer(
                placeRequest: $placeRequest,
                resetRequest: $resetRequest,
                yawDegrees: $yawDeg,
                pitchDegrees: $pitchDeg,
                aputapped: $lastAPUTapped
            )
            .ignoresSafeArea()
            // When the APU is tapped (value toggles each time), if "Show Info" mode is ON,
            // pick a new random row for the card. This *only* changes the card contents.
            .onChange(of: lastAPUTapped) { _ in
                guard showInfoCard else { return }
                guard !demoRows.isEmpty else { currentInfoRow = nil; return }
                var next = demoRows.randomElement()!
                if let current = currentInfoRow, demoRows.count > 1 {
                    // Avoid showing the same row twice in a row if possible
                    while next.id == current.id { next = demoRows.randomElement()! }
                }
                currentInfoRow = next
            }

            // ===========================================
            // MARK: Top-left Menu button (unchanged UI)
            // ===========================================
            VStack {
                HStack {
                    Button {
                        withAnimation(.spring()) { showMenu.toggle() }
                    } label: {
                        HStack {
                            Text("Menu")
                            Image(systemName: showMenu ? "chevron.down" : "chevron.right")
                        }
                        .font(.footnote.bold())
                        .padding(8)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                    .padding(.leading, 10)

                    Spacer()
                }
                .padding(.top, 12)
                Spacer()
            }

            // =====================================================
            // MARK: Compact left-side menu (anchored under "Menu")
            // =====================================================
            if showMenu {
                VStack(spacing: 8) {
                    Button {
                        showManual = true
                        withAnimation { showMenu = false }
                    } label: {
                        Label("Show Manuals", systemImage: "book")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        // Enter "Show Info" mode. The card appears when you tap the APU.
                        showInfoCard = true
                        withAnimation { showMenu = false }
                    } label: {
                        Label("Show Info", systemImage: "info.circle")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 8)
                .frame(width: 200) // keep narrow; only two options
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, 52)     // sits just below the Menu chip
                .padding(.leading, 12) // small left inset
                .transition(.move(edge: .leading).combined(with: .opacity))
                .zIndex(5)
            }

            // ==========================================
            // MARK: Draggable manual card (single page)
            // ==========================================
            if showManual {
                PDFDraggableCard(
                    showManual: $showManual,
                    manualOffset: $manualOffset,
                    dragOffset: dragOffset
                )
                .gesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in
                            state = value.translation
                        }
                        .onEnded { value in
                            manualOffset.width  += value.translation.width
                            manualOffset.height += value.translation.height
                        }
                )
                .transition(.scale)
                .zIndex(10)
            }

            // =====================================================
            // MARK: Info Card — shown when Show Info is ON *and*
            //       the APU has just been tapped in AR
            // =====================================================
            if showInfoCard && lastAPUTapped {
                VStack {
                    Spacer()
                    APUInfoCard(showInfoCard: $showInfoCard, row: currentInfoRow)
                        .padding(.bottom, 40)
                }
                .transition(.opacity)
            }

            // ==========================================
            // MARK: Rotation sliders (exact same UI)
            // ==========================================
            RotationSliders(
                yawDeg: $yawDeg,
                pitchDeg: $pitchDeg,
                placeRequest: $placeRequest,
                resetRequest: $resetRequest
            )
        }
    }
}

// MARK: - Compact Sliders (no UI changes)
struct RotationSliders: View {
    @Binding var yawDeg: Double
    @Binding var pitchDeg: Double
    @Binding var placeRequest: Int
    @Binding var resetRequest: Int

    var body: some View {
        ZStack {
            // Bottom Horizontal slider - controls Y-axis rotation (Yaw)
            VStack {
                Spacer()

                // Place & Reset buttons centered above horizontal slider
                HStack(spacing: 12) {
                    Button("Place APU") {
                        placeRequest += 1
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Reset") {
                        resetRequest += 1
                        yawDeg = 0
                        pitchDeg = 0
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.bottom, 8)

                // Horizontal Yaw Slider
                HStack(spacing: 8) {
                    Image(systemName: "arrow.left.and.right")
                        .font(.caption)
                    Slider(value: $yawDeg, in: -180...180, step: 1)
                        .frame(width: 450)
                        .controlSize(.regular)
                    Text("\(Int(yawDeg))°")
                        .font(.footnote.monospacedDigit())
                        .frame(width: 40)
                }
                .padding(12)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.bottom, 20)
            }

            // Right-side Vertical slider - controls X-axis rotation (Pitch)
            HStack {
                Spacer()
                VStack {
                    Spacer()

                    // Tweak these two numbers only:
                    let length: CGFloat   = 400 // vertical travel distance
                    let thickness: CGFloat = 40 // visual thickness of the slider/card

                    VStack(spacing: 8) {
                        Image(systemName: "arrow.up.and.down")
                            .font(.caption)

                        // Wrapper keeps the card narrow; slider rotates inside
                        ZStack {
                            Slider(value: $pitchDeg, in: -180...180, step: 1)
                                .rotationEffect(.degrees(-90))
                                .frame(width: length, height: thickness) // pre-rotation size
                                .controlSize(.regular)
                        }
                        .frame(width: thickness, height: length) // what the parent sees
                        .clipped()                                // trim overflow

                        Text("\(Int(pitchDeg))°")
                            .font(.footnote.monospacedDigit())
                    }
                    .padding(8) // slimmer card
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                    .padding(.trailing, 10)
                    .padding(.bottom, 140)

                    Spacer()
                }
            }
        }
    }
}

// MARK: - Manual Viewer (Single-page, draggable)
struct PDFDraggableCard: View {
    @Binding var showManual: Bool
    @Binding var manualOffset: CGSize
    var dragOffset: CGSize

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("APU Manual (Single Page)")
                    .font(.headline)
                Spacer()
                Button {
                    withAnimation { showManual = false }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                }
            }
            .padding()
            Divider()

            // NOTE: Put Manual_APU.pdf in your app bundle
            PDFKitSinglePageView(
                url: Bundle.main.url(forResource: "Manual_APU", withExtension: "pdf")!
            )
            .background(Color.black.opacity(0.9))
        }
        .frame(width: 500, height: 350)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 20)
        .offset(
            x: manualOffset.width + dragOffset.width,
            y: manualOffset.height + dragOffset.height
        )
        .zIndex(10)
    }
}

// MARK: - Single-page PDFKit wrapper
struct PDFKitSinglePageView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(url: url)
        pdfView.displayMode = .singlePageContinuous
        pdfView.autoScales = true
        pdfView.backgroundColor = .clear
        return pdfView
    }
    func updateUIView(_ uiView: PDFView, context: Context) {}
}

// MARK: - Info Card (random row with markers)
struct APUInfoCard: View {
    @Binding var showInfoCard: Bool
    let row: ContentView.PartRow?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("APU Info")
                    .font(.headline)
                Spacer()
                Button {
                    withAnimation { showInfoCard = false }
                } label: {
                    Image(systemName: "xmark.circle.fill").font(.title2)
                }
            }
            Divider()

            // Four fields only; each line has a tiny dot "marker"
            if let r = row {
                LabeledLine(label: "Item", value: r.item)
                LabeledLine(label: "P/N", value: r.pn)
                LabeledLine(label: "Life Limit", value: r.lifeLimit)
                LabeledLine(label: "APU Cycles Remaining", value: r.apuCyclesRemaining)
            } else {
                // First time before a tap
                Text("Tap the APU to view life-limited part details.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }

            Spacer(minLength: 4)
            HStack {
                Spacer()
                Text("Created by Team6 AIMX")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(width: 280, height: 180) // unchanged size
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 10)
    }
}

// Small helper: a row with a dot “marker” and bold label
private struct LabeledLine: View {
    let label: String
    let value: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "circle.fill").font(.system(size: 6)) // marker
            Text(label + ":").font(.subheadline.weight(.semibold))
            Text(value).font(.subheadline).lineLimit(1)
            Spacer()
        }
    }
}

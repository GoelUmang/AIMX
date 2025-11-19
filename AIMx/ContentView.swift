import SwiftUI
import RealityKit
import ARKit

struct ContentView: View {
    @State private var placeRequest = 0
    @State private var resetRequest = 0

    var body: some View {
        ZStack {
            ARViewContainer(placeRequest: $placeRequest, resetRequest: $resetRequest)
                .ignoresSafeArea()

            VStack {
                // Status text (top left)
                HStack {
                    Text("Tap 'Place APU' to drop in front of you")
                        .font(.callout)
                        .padding(8)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Spacer()
                }
                .padding([.top, .leading])

                Spacer()

                // Bottom control buttons
                HStack(spacing: 12) {
                    Button {
                        placeRequest += 1
                    } label: {
                        Label("Place APU", systemImage: "arkit")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }

                    Button(role: .destructive) {
                        resetRequest += 1
                    } label: {
                        Label("Reset", systemImage: "trash")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                }
                .padding(.bottom, 24)
            }
        }
    }
}

import SwiftOBD2
/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * SwiftUI grid view for live gauge tiles
 *
 * Displays enabled gauges in an adaptive grid (2-4 columns based on width).
 * Each tile shows a ring gauge visualization with current value and units.
 * Uses demand-driven polling to request only visible gauge data.
 * Tapping a tile navigates to detailed statistics view.
 */
import SwiftUI
import UIKit
import UniformTypeIdentifiers

@MainActor
struct GaugesView: View {

  // Stable observable view model instance
  @State private var viewModel: GaugesViewModel
  @State private var selectedDetailViewModel: GaugeDetailViewModel?
  @State private var isShowingDetail = false
  @State private var draggedTileID: UUID?

  // Adaptive layout: 2–4 columns depending on device width
  private let columns = [
    GridItem(.adaptive(minimum: 160, maximum: 240), spacing: 16, alignment: .top)
  ]

  @MainActor
  init() {
    _viewModel = State(initialValue: GaugesViewModel())
  }

  // Injectable initializer for testing/mocking
  @MainActor
  init(viewModel: GaugesViewModel) {
    _viewModel = State(initialValue: viewModel)
  }


  var body: some View {
    ScrollView {
      LazyVGrid(columns: columns, spacing: 16) {
        ForEach(viewModel.displayTiles) { tile in
          GaugeTile(tile: tile, isBeingDragged: draggedTileID == tile.id)
          .contentShape(RoundedRectangle(cornerRadius: 12))
          .onTapGesture {
            selectedDetailViewModel = tile.detailViewModel
            isShowingDetail = true
          }
          .onDrag {
            draggedTileID = tile.id
            return NSItemProvider(object: tile.id.uuidString as NSString)
          }
          .onDrop(
            of: [UTType.plainText],
            delegate: GaugeTileDropDelegate(
              tile: tile,
              viewModel: viewModel,
              draggedTileID: $draggedTileID
            )
          )
          .accessibilityIdentifier(tile.tileAccessibilityIdentifier)
        }
      }
      .padding()
    }
    .navigationDestination(isPresented: $isShowingDetail) {
      if let selectedDetailViewModel {
        GaugeDetailView(viewModel: selectedDetailViewModel)
      }
    }
    .onAppear {
      viewModel.onAppear()
    }
    .onDisappear {
      viewModel.onDisappear()
    }
  }
}

private struct GaugeTile: View {
  let tile: GaugesViewModel.DisplayTile
  let isBeingDragged: Bool

  var body: some View {
    VStack(spacing: 8) {


      RingGaugeView(model: tile.ring)
        .frame(width: 120, height: 96)

      Text(tile.shortTitle)
        .font(.headline)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
    .padding(12)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color(UIColor.secondarySystemBackground))
    )
    .opacity(isBeingDragged ? 0.7 : 1)
  }
}

private struct GaugeTileDropDelegate: DropDelegate {
  let tile: GaugesViewModel.DisplayTile
  let viewModel: GaugesViewModel
  @Binding var draggedTileID: UUID?

  func dropEntered(_: DropInfo) {
    guard let draggedTileID, draggedTileID != tile.id else { return }

    withAnimation {
      viewModel.reorderTile(withID: draggedTileID, to: tile.id)
    }
  }

  func dropUpdated(_: DropInfo) -> DropProposal? {
    DropProposal(operation: .move)
  }

  func performDrop(info: DropInfo) -> Bool {
    draggedTileID = nil
    return true
  }

  func dropExited(_: DropInfo) {}
}

#Preview {
  NavigationStack {
    GaugesView()
  }
}

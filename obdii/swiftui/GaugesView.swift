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
  fileprivate static let gridCoordinateSpaceName = "GaugesGrid"

  // Stable observable view model instance
  @State private var viewModel: GaugesViewModel
  @State private var selectedDetailViewModel: GaugeDetailViewModel?
  @State private var isShowingDetail = false
  @State private var draggedTileID: UUID?
  @State private var tileFrames: [UUID: CGRect] = [:]

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
      .coordinateSpace(name: Self.gridCoordinateSpaceName)
      .onPreferenceChange(GaugeTileFramePreferenceKey.self) { tileFrames = $0 }
      .background(
        Rectangle()
          .fill(Color.black.opacity(0.001))
          .onDrop(
            of: [UTType.plainText],
            delegate: GaugeGridDropDelegate(
              viewModel: viewModel,
              draggedTileID: $draggedTileID,
              tileOrder: viewModel.displayTiles.map(\.id),
              tileFrames: tileFrames
            )
          )
      )
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
    .background(
      GeometryReader { proxy in
        Color.clear.preference(
          key: GaugeTileFramePreferenceKey.self,
          value: [tile.id: proxy.frame(in: .named(GaugesView.gridCoordinateSpaceName))]
        )
      }
    )
    .opacity(isBeingDragged ? 0.7 : 1)
  }
}

private struct GaugeTileFramePreferenceKey: PreferenceKey {
  static var defaultValue: [UUID: CGRect] = [:]

  static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
    value.merge(nextValue(), uniquingKeysWith: { _, new in new })
  }
}

private struct GaugeTileDropDelegate: DropDelegate {
  let tile: GaugesViewModel.DisplayTile
  let viewModel: GaugesViewModel
  @Binding var draggedTileID: UUID?

  func dropEntered(_: DropInfo) {
    /* Reorder on drop completion so a successful drop always commits the move. */
  }

  func dropUpdated(_: DropInfo) -> DropProposal? {
    DropProposal(operation: .move)
  }

  func performDrop(info _: DropInfo) -> Bool {
    if let draggedTileID, draggedTileID != tile.id {
      withAnimation {
        viewModel.reorderTile(withID: draggedTileID, to: tile.id)
      }
    }
    draggedTileID = nil
    return true
  }

  func dropExited(_: DropInfo) {
    /* Drag lifecycle hook not needed; reorder happens in dropEntered. */
  }
}

private struct GaugeGridDropDelegate: DropDelegate {
  let viewModel: GaugesViewModel
  @Binding var draggedTileID: UUID?
  let tileOrder: [UUID]
  let tileFrames: [UUID: CGRect]

  func dropUpdated(_: DropInfo) -> DropProposal? {
    DropProposal(operation: .move)
  }

  func performDrop(info: DropInfo) -> Bool {
    defer { draggedTileID = nil }

    guard let draggedTileID else { return false }
    guard let targetIndex = insertionIndex(for: info.location, excluding: draggedTileID) else {
      return false
    }

    withAnimation {
      viewModel.reorderTile(withID: draggedTileID, toIndex: targetIndex)
    }
    return true
  }

  private func insertionIndex(for location: CGPoint, excluding draggedID: UUID) -> Int? {
    let orderedFrames = tileOrder.compactMap { id -> (UUID, CGRect)? in
      guard id != draggedID, let frame = tileFrames[id] else { return nil }
      return (id, frame)
    }

    guard !orderedFrames.isEmpty else { return 0 }

    let slotAnchors = makeSlotAnchors(for: orderedFrames)
    guard let bestMatch = slotAnchors.min(by: {
      location.distanceSquared(to: $0.point) < location.distanceSquared(to: $1.point)
    }) else {
      return nil
    }

    return bestMatch.index
  }

  private func makeSlotAnchors(for orderedFrames: [(UUID, CGRect)]) -> [(index: Int, point: CGPoint)] {
    let centers = orderedFrames.map { $0.1.center }
    var anchors: [(index: Int, point: CGPoint)] = []

    if let firstFrame = orderedFrames.first?.1 {
      anchors.append((0, CGPoint(x: firstFrame.minX - 24, y: firstFrame.midY)))
    }

    for index in 1..<centers.count {
      let previous = centers[index - 1]
      let current = centers[index]
      anchors.append((
        index,
        CGPoint(
          x: (previous.x + current.x) / 2,
          y: (previous.y + current.y) / 2
        )
      ))
    }

    if let lastFrame = orderedFrames.last?.1 {
      anchors.append((orderedFrames.count, CGPoint(x: lastFrame.maxX + 24, y: lastFrame.midY)))
    }

    return anchors
  }
}

private extension CGRect {
  var center: CGPoint {
    CGPoint(x: midX, y: midY)
  }
}

private extension CGPoint {
  func distanceSquared(to other: CGPoint) -> CGFloat {
    let dx = x - other.x
    let dy = y - other.y
    return (dx * dx) + (dy * dy)
  }
}

#Preview {
  NavigationStack {
    GaugesView()
  }
}

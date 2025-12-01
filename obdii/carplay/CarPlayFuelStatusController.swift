/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * CarPlay template for Fuel System Status
 *
 * Displays the current fuel system status for Bank 1 and Bank 2 (if applicable).
 * Shows status codes indicating whether the fuel system is in open loop, closed loop,
 * or other operational states.
 *
 * Uses a snapshot pattern to avoid unnecessary UI updates when data hasn't changed.
 */

import CarPlay
import Observation
import SwiftOBD2
import UIKit

@MainActor
class CarPlayFuelStatusController: CarPlayBaseTemplateController<FuelStatusViewModel> {
  // Optional snapshot to match ViewModel.status optionality
  private var previousFuelStatus: [StatusCodeMetadata?]?

  init() {
    super.init(viewModel: FuelStatusViewModel())
  }

  // Ensure demand-driven streaming includes fuel status while this tab is visible
  override func registerVisiblePIDs() {
    PIDInterestRegistry.shared.replace(pids: [.mode1(.fuelStatus)], for: controllerToken)
  }

  private func makeItem(_ text: String, detailText: String) -> CPListItem {
    let item = CPListItem(text: text, detailText: detailText)
    item.handler = { _, completion in completion() }
    return item
  }

  private func buildInformationItems() -> [CPInformationItem] {
    var items: [CPInformationItem] = []

    // Waiting state
    if viewModel.status == nil {
      items.append(CPInformationItem(title: "Waiting for data…", detail: ""))
      return items
    }

    if let b1 = viewModel.bank1 {
      let item = CPInformationItem(
        title: "Bank 1",
        detail: b1.description
      )
      items.append(item)
    }
    if let b2 = viewModel.bank2 {
      let item = CPInformationItem(
        title: "Bank 2",
        detail: b2.description
      )
      items.append(item)
    }
    if items.isEmpty {
      items.append(CPInformationItem(title: "No Fuel System Status Codes", detail: ""))
    }
    return items
  }

  override func makeRootTemplate() -> CPInformationTemplate {
    let items = buildInformationItems()
    let template = CPInformationTemplate(
      title: "Fuel Control Status", layout: .leading, items: items, actions: [])
    template.tabTitle = "FC"
    template.tabImage = symbolImage(named: "wrench.and.screwdriver")
    currentTemplate = template
    // Initialize previous snapshot to match what we just rendered
    previousFuelStatus = viewModel.status ?? []
    return template
  }

  // Unified refresh method name
  private func refreshSection() {
    guard let template = currentTemplate as? CPInformationTemplate else { return }

    let current = viewModel.status ?? []

    // Early exit if nothing changed
    if let previous = previousFuelStatus, previous == current {
      return
    }

    // Update UI and remember last shown state
    let items = buildInformationItems()
    previousFuelStatus = current
    template.items = items
  }

  // Hook for base class visibility refresh
  override func performRefresh() {
    refreshSection()
  }
}

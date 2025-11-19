/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * CarPlay detail view for a single PID (gauge)
 *
 * Displays detailed statistics for a single parameter, including:
 * - Current value with units
 * - Minimum and maximum observed values
 * - Sample count
 * - Typical operating range
 *
 * This controller is created dynamically when a user taps on a gauge tile
 * in the main gauges view. It registers interest for only the specific PID
 * being displayed to minimize data polling overhead.
 */

import Foundation
import CarPlay
import Combine
import SwiftOBD2

@MainActor
final class CarPlayGaugeDetailController: CarPlayBaseTemplateController<GaugeDetailViewModel> {
    private let pid: OBDPID

    init(pid: OBDPID) {
        // Initialize own stored properties first
        self.pid = pid

        // Prepare the view model locally
        let vm = GaugeDetailViewModel(pid: pid)

        // Then call super.init with required VM
        super.init(viewModel: vm)
    }

    // Register interest for just this PID while this template is visible
    override func registerVisiblePIDs() {
        PIDInterestRegistry.shared.replace(pids: [pid.pid], for: controllerToken)
    }

    // Create the root information template for this PID
    override func makeRootTemplate() -> CPTemplate {
        let items = buildItems(for: viewModel.pid, stats: viewModel.stats)
        let title = viewModel.pid.name
        let info = CPInformationTemplate(title: title, layout: .twoColumn, items: items, actions: [])
        self.currentTemplate = info
        return info
    }

    // Rebuild from the current snapshot
    override func performRefresh() {
        guard let info = currentTemplate as? CPInformationTemplate else { return }
        let items = buildItems(for: viewModel.pid, stats: viewModel.stats)
        info.items = items
    }

    private func buildItems(for pid: OBDPID, stats: OBDConnectionManager.PIDStats?) -> [CPInformationItem] {
        var items: [CPInformationItem] = []

        if let s = stats {
            let currentStr = pid.formatted(measurement: s.latest, includeUnits: true)
            items.append(CPInformationItem(title: "Current", detail: currentStr))
        } else {
            items.append(CPInformationItem(title: "Current", detail: "— \(pid.displayUnits)"))
        }

        if let s = stats {
            let minStr = pid.formatted(measurement: MeasurementResult(value: s.min, unit: s.latest.unit), includeUnits: true)
            let maxStr = pid.formatted(measurement: MeasurementResult(value: s.max, unit: s.latest.unit), includeUnits: true)
            items.append(CPInformationItem(title: "Min", detail: minStr))
            items.append(CPInformationItem(title: "Max", detail: maxStr))
            items.append(CPInformationItem(title: "Samples", detail: "\(s.sampleCount)"))
        }

        items.append(CPInformationItem(title: "Typical Range", detail: pid.displayRange))

        return items
    }
}


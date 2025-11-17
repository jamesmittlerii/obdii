/**
 
 * __Final Project__
 * Jim Mittler
 * 14 November 2025
 
 
CarPlay template for PID details
 
 _Italic text__
 __Bold text__
 ~~Strikethrough text~~
 
 */

import Foundation
import CarPlay
import Combine
import SwiftOBD2

@MainActor
final class CarPlayGaugeDetailController: CarPlayBaseTemplateController {
    private let viewModel: GaugeDetailViewModel
    private let connectionManager: OBDConnectionManager
    private let pid: OBDPID

    init(pid: OBDPID, connectionManager: OBDConnectionManager) {
        self.connectionManager = connectionManager
        self.pid = pid
        // Use GaugeDetailViewModel for data and formatting
        self.viewModel = GaugeDetailViewModel(pid: pid, connectionManager: connectionManager)

       
    }

    // Wire the simple callback if/when the interface controller gets set (idempotent)
    override func setInterfaceController(_ interfaceController: CPInterfaceController) {
        super.setInterfaceController(interfaceController)
        viewModel.onChanged = { [weak self] in
            self?.performRefresh()
        }
    
    }

    // Register interest for just this PID while this template is visible
    override func registerVisiblePIDs() {
        PIDInterestRegistry.shared.replace(pids: [pid.pid], for: controllerToken)
    }

    // Create the root information template for this PID
    override func makeRootTemplate() -> CPTemplate {
        let items = buildItems(for: viewModel.pid, stats: viewModel.stats)
        let info = CPInformationTemplate(title: viewModel.pid.name, layout: .twoColumn, items: items, actions: [])
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

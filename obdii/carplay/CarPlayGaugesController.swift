/**
 
 * __Final Project__
 * Jim Mittler
 * 14 November 2025
 
 
CarPlay template for Gauges
 
 _Italic text__
 __Bold text__
 ~~Strikethrough text~~
 
 */

import CarPlay
import Combine
import SwiftOBD2
import SwiftUI // For Color
import UIKit   // For UIImage

@MainActor
class CarPlayGaugesController: CarPlayBaseTemplateController<GaugesViewModel> {
    private var sensorItems: [CPInformationItem] = []
    
    // Detail screen controller (manages template and live updates)
    private var detailController: CarPlayGaugeDetailController?

   
     
     init() {
        super.init(viewModel: GaugesViewModel())
    }

    override func registerVisiblePIDs() {
        // Register interest for the corresponding commands
        let visiblePIDs: Set<OBDCommand> = Set(viewModel.tiles.map { $0.pid.pid })
        PIDInterestRegistry.shared.replace(pids: visiblePIDs, for: controllerToken)
    }

    /// Creates the root template for the Gauges tab.
    override func makeRootTemplate() -> CPListTemplate {
        let section = buildSections()
        let template = CPListTemplate(title: "Gauges", sections: section)
        template.tabTitle = "Gauges"
        template.tabImage = symbolImage(named: "gauge")

        self.currentTemplate = template
        return template
    }

    private func refreshSection() {
        guard let template = currentTemplate as? CPListTemplate else { return }
        let sections = buildSections()
        template.updateSections(sections)
    }

    private func makeItem(_ text: String, detailText: String?) -> CPListItem {
        let item = CPListItem(text: text, detailText: detailText)
        item.handler = { _, completion in completion() }
        return item
    }
    
    private func buildSections() -> [CPListSection]  {
        let tiles = viewModel.tiles
        
        if tiles.isEmpty {
            let item = makeItem("No Enabled Gauges", detailText: nil)
            let section = CPListSection(items: [item])
            return [section]
        }

        let rowElements: [CPListImageRowItemRowElement] = tiles.map { tile in
            let pid = tile.pid
            let measurement = tile.measurement
            let image = drawGaugeImage(for: pid, measurement: measurement, size: CPListImageRowItemElement.maximumImageSize)
            let subtitle = measurement.map { pid.formatted(measurement: $0, includeUnits: true) } ??  "— \(pid.displayUnits)"
            return CPListImageRowItemRowElement(image: image, title: pid.label, subtitle: subtitle)
        }

        let item = CPListImageRowItem(text: "", elements: rowElements, allowsMultipleLines: true)
        item.handler = { _, completion in completion() }

        item.listImageRowHandler = { [weak self] _, index, completion in
            guard let self = self else {
                completion()
                return
            }
            let tiles = self.viewModel.tiles
            guard index >= 0 && index < tiles.count else {
                completion()
                return
            }
            let tappedPID = tiles[index].pid

            self.presentSensorTemplate(for: tappedPID)
            completion()
        }

        return [CPListSection(items: [item])]
    }

    private func presentSensorTemplate(for pid: OBDPID) {
        // Releasing the old controller cancels its subscriptions automatically
        detailController = nil

        // Create a new self-contained detail controller
        let controller = CarPlayGaugeDetailController(pid: pid)
        detailController = controller

        // IMPORTANT: give the detail controller the same CPInterfaceController so it can wire callbacks and tokens
        if let ic = self.interfaceController {
            controller.setInterfaceController(ic)
        }

        // Ensure its root template is created
        let detailTemplate = controller.makeRootTemplate()

        // Register ownership with the scene delegate so appear/disappear are forwarded
        if let sceneDelegate = interfaceController?.delegate as? CarPlaySceneDelegate {
            sceneDelegate.register(template: detailTemplate, owner: controller)
        }

        // Push its template
        interfaceController?.pushTemplate(detailTemplate, animated: false, completion: { [weak self] success, error in
            _ = self
        })
    }

    override func performRefresh() {
        // Update the UI for any tiles change
        refreshSection()
        // Also (re)register interest for whatever tiles are currently visible.
        // This ensures newly added gauges start streaming immediately while the tab is visible.
        registerVisiblePIDs()
    }
}


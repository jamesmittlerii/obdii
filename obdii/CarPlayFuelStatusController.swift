import CarPlay
import UIKit
import SwiftOBD2
import Combine

let bytes: [UInt8] = [0x41, 0x03, 0x02, 0x04]


struct FuelSystemStatus {
    let system1: Status
    let system2: Status

    enum Status: UInt8, CustomStringConvertible {
        case openLoopCold = 0x01
        case closedLoop = 0x02
        case openLoopLoad = 0x04
        case openLoopFailure = 0x08
        case closedLoopAlt = 0x10
        case unknown = 0x00

        var description: String {
            switch self {
            case .openLoopCold:
                return "Open Loop (cold engine)"
            case .closedLoop:
                return "Closed Loop (normal operation)"
            case .openLoopLoad:
                return "Open Loop (load/fuel cut)"
            case .openLoopFailure:
                return "Open Loop (system failure)"
            case .closedLoopAlt:
                return "Closed Loop (alternate feedback)"
            case .unknown:
                return "Unknown"
            }
        }
    }

    /// Decode from raw OBD-II response bytes like [0x41, 0x03, 0x02, 0x04]
    init(from bytes: [UInt8]) {
        guard bytes.count >= 4 else {
            system1 = .unknown
            system2 = .unknown
            return
        }
        system1 = Status(rawValue: bytes[2]) ?? .unknown
        system2 = Status(rawValue: bytes[3]) ?? .unknown
    }
}

@MainActor
class CarPlayFuelStatusController {
    private weak var interfaceController: CPInterfaceController?
    private var currentTemplate: CPListTemplate?
    private let connectionManager: OBDConnectionManager
    private var cancellables = Set<AnyCancellable>()
    
    init(connectionManager: OBDConnectionManager) {
        self.connectionManager = connectionManager
        
       
    }

    func setInterfaceController(_ interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        
        // Observe connection state changes to keep the UI in sync
        OBDConnectionManager.shared.$fuelStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshSection()
            }
            .store(in: &cancellables)
    }
    
    private func makeItem(_ text: String, detailText: String) -> CPListItem {
        let item = CPListItem(text: text, detailText: detailText)
        item.handler = { _, completion in completion() }
        return item
    }
    
    private func buildSections() -> [CPListSection] {
        //let status = FuelSystemStatus(from: bytes)
        
        var items = [] as [CPListItem]
        
        if (OBDConnectionManager.shared.fuelStatus.count >= 1 && OBDConnectionManager.shared.fuelStatus[0] != nil)
        {
            items.append(makeItem("Fuel System 1" , detailText:  OBDConnectionManager.shared.fuelStatus[0]!.description))
        }
        if (OBDConnectionManager.shared.fuelStatus.count >= 2 && OBDConnectionManager.shared.fuelStatus[1] != nil)
        {
            items.append(makeItem("Fuel System 2" , detailText:  OBDConnectionManager.shared.fuelStatus[1]!.description))
        }
        if (OBDConnectionManager.shared.fuelStatus.count == 0)
        {
            items.append(makeItem("No Fuel System Status Codes" , detailText: ""))
        }

            
        let section = CPListSection(items: items)
       return [section]
        

    }

    private func refreshSection() {
        guard let template = currentTemplate else { return }
        let sections = buildSections()
        template.updateSections(sections)
    }

    /// Creates the root template for the Settings tab.
    func makeRootTemplate() -> CPListTemplate {
        let sections = buildSections()
        let template = CPListTemplate(title: "FuelStatus", sections: sections)
        template.tabTitle = "FI"
        template.tabImage = symbolImage(named: "wrench.and.screwdriver")
        self.currentTemplate = template
        return template
    }
    
    

    // MARK: - Helpers

    private func symbolImage(named name: String) -> UIImage? {
        return UIImage(systemName: name)
    }

    private func imageName(for severity: CodeSeverity) -> String {
        switch severity {
        case .low:       return "exclamationmark.circle"
        case .moderate:  return "exclamationmark.triangle"
        case .high:      return "bolt.trianglebadge.exclamationmark"
        case .critical:  return "xmark.octagon"
        }
    }

    private func severityColor(_ severity: CodeSeverity) -> UIColor {
        switch severity {
        case .low:
            return .systemYellow
        case .moderate:
            return .systemOrange
        case .high:
            return .systemRed
        case .critical:
            return UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    // A brighter red for dark mode for better visibility
                    return UIColor(red: 1.0, green: 0.3, blue: 0.25, alpha: 1.0)
                } else {
                    // The original dark red for light mode
                    return UIColor(red: 0.85, green: 0.0, blue: 0.0, alpha: 1.0)
                }
            }
        }
    }

    private func tintedSymbol(named name: String, severity: CodeSeverity) -> UIImage? {
        guard let img = symbolImage(named: name) else { return nil }
        return img.withTintColor(severityColor(severity), renderingMode: .alwaysOriginal)
    }

    private func severitySectionTitle(_ severity: CodeSeverity) -> String {
        switch severity {
        case .critical: return "Critical"
        case .high:     return "High Severity"
        case .moderate: return "Moderate"
        case .low:      return "Low"
        }
    }
}

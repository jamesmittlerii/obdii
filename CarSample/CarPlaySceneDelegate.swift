//
//  CarPlaySceneDelegate.swift
//  CarPlay
//
//  Created by Alexander v. Below on 24.06.20.
//

import UIKit
// CarPlay App Lifecycle

import CarPlay
import os.log

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    var interfaceController: CPInterfaceController?
    let logger = Logger()
    
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
            didConnect interfaceController: CPInterfaceController) {

        self.interfaceController = interfaceController
        
        let gridButton = CPGridButton(titleVariants: ["Albums"],
                                      image: UIImage(systemName: "list.triangle")!)
        { button in
            interfaceController.pushTemplate(self.listTemplate(),
                                             animated: true,
                                             completion: nil)

        }
        
        let gridTemplate = CPGridTemplate(title: "A Grid Interface", gridButtons:  [gridButton])
        
        // SwiftC apparently requires the explicit inclusion of the completion parameter,
        // otherwise it will throw a warning
        interfaceController.setRootTemplate(gridTemplate,
                                            animated: true,
                                            completion: nil)
    }

    func listTemplate() -> CPListTemplate {
        let albums: [(title: String, detail: String)] = [
            ("Rubber Soul", "The Beatles • $12.99"),
            ("Kind of Blue", "Miles Davis • $10.99"),
            ("Rumours", "Fleetwood Mac • $11.49"),
            ("The Dark Side of the Moon", "Pink Floyd • $13.99")
        ]
        
        var items: [CPListItem] = []
        for (title, detail) in albums {
            let item = CPListItem(text: title, detailText: detail)
            item.handler = { [weak self] _, completion in
                self?.logger.info("Item selected: \(title, privacy: .public)")
                completion()
            }
            items.append(item)
        }
        
        let section = CPListSection(items: items)
        return CPListTemplate(title: "Albums", sections: [section])
    }
    
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        self.interfaceController = nil
    }
}

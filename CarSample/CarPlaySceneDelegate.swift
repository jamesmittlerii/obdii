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
    
    // MARK: - Album model and UI state
    struct Album {
        var title: String
        var artist: String
        var price: Double
    }
    
    // Mutable data source
    private var albums: [Album] = [
        Album(title: "Rubber Soul", artist: "The Beatles", price: 12.99),
        Album(title: "Kind of Blue", artist: "Miles Davis", price: 10.99),
        Album(title: "Rumours", artist: "Fleetwood Mac", price: 11.49),
        Album(title: "The Dark Side of the Moon", artist: "Pink Floyd", price: 13.99)
    ]
    
    // Keep references to update UI efficiently
    private var listItems: [CPListItem] = []
    private var albumsListTemplate: CPListTemplate?
    
    // Background task to update prices
    private var priceUpdateTask: Task<Void, Never>?
    
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
            didConnect interfaceController: CPInterfaceController) {

        self.interfaceController = interfaceController
        
        let gridButton = CPGridButton(titleVariants: ["Albums"],
                                      image: UIImage(systemName: "list.triangle")!)
        { [weak self] _ in
            guard let self else { return }
            let listTemplate = self.listTemplate()
            interfaceController.pushTemplate(listTemplate,
                                             animated: true,
                                             completion: nil)
        }
        
        let gridTemplate = CPGridTemplate(title: "A Grid Interface", gridButtons:  [gridButton])
        
        // SwiftC apparently requires the explicit inclusion of the completion parameter,
        // otherwise it will throw a warning
        interfaceController.setRootTemplate(gridTemplate,
                                            animated: true,
                                            completion: nil)
        
        // Start background price updates when CarPlay connects
        startPriceUpdates()
    }

    func listTemplate() -> CPListTemplate {
        // Build CPListItems from current albums and keep references
        listItems = albums.map { album in
            let item = CPListItem(text: album.title,
                                  detailText: "\(album.artist) • $\(String(format: "%.2f", album.price))")
            // Set playbackProgress as price percentage of $20 (clamped 0...1)
            let progress = min(1.0, max(0.0, album.price / 20.0))
            item.playbackProgress = CGFloat(progress)
            item.handler = { [weak self] _, completion in
                self?.logger.info("Item selected: \(album.title, privacy: .public)")
                completion()
            }
            return item
        }
        
        let section = CPListSection(items: listItems)
        let template = CPListTemplate(title: "Albums", sections: [section])
        albumsListTemplate = template
        return template
    }
    
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        self.interfaceController = nil
        // Stop background updates when CarPlay disconnects
        priceUpdateTask?.cancel()
        priceUpdateTask = nil
    }
    
    // MARK: - Background price updates
    
    private func startPriceUpdates() {
        // Avoid multiple tasks
        priceUpdateTask?.cancel()
        priceUpdateTask = Task.detached { [weak self] in
            guard let self else { return }
            // Randomly update prices while connected
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                await self.randomlyAdjustPrices()
                await self.refreshAlbumListIfVisible()
            }
        }
    }
    
    @MainActor
    private func refreshAlbumListIfVisible() {
        guard let currentTemplate = albumsListTemplate else { return }
        
        // Rebuild CPListItems to reflect new prices (CPListItem text is read-only)
        listItems = albums.map { album in
            let item = CPListItem(text: album.title,
                                  detailText: "\(album.artist) • $\(String(format: "%.2f", album.price))")
            // Update playbackProgress to match the latest price
            let progress = min(1.0, max(0.0, album.price / 20.0))
            item.playbackProgress = CGFloat(progress)
            item.handler = { [weak self] _, completion in
                self?.logger.info("Item selected: \(album.title, privacy: .public)")
                completion()
            }
            return item
        }
        
        // Update the section in place (iOS 14+)
        let newSection = CPListSection(items: listItems)
        currentTemplate.updateSections([newSection])
    }
    
    @MainActor
    private func randomlyAdjustPrices() {
        // Adjust each price by +/- up to 50 cents, then clamp between $0.00 and $20.00
        for i in albums.indices {
            let delta = Double.random(in: -0.5...0.5)
            let unclamped = albums[i].price + delta
            let clamped = min(20.0, max(0.0, unclamped))
            albums[i].price = (clamped * 100).rounded() / 100 // round to cents
        }
        logger.debug("Prices updated in background")
    }
}

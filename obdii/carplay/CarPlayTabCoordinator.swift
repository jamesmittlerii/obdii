//
//  CarPlayTabCoordinator.swift
//  obdii
//
//  Created by cisstudent on 11/15/25.
//
import CarPlay
import UIKit
import Combine
import SwiftUI

final class CarPlayTabCoordinator: NSObject, CPTabBarTemplateDelegate {

    /// Track the currently selected tab index
    @AppStorage("selectedCarPlayTab") var selectedIndex: Int = 0

    // Combine publisher for selected tab index
    private let selectedIndexSubject = PassthroughSubject<Int, Never>()
    var selectedIndexPublisher: AnyPublisher<Int, Never> {
        selectedIndexSubject.eraseToAnyPublisher()
    }

    override init() {
        super.init()
        // Emit the persisted initial value so subscribers get an initial state
        selectedIndexSubject.send(selectedIndex)
    }

    func tabBarTemplate(_ tabBarTemplate: CPTabBarTemplate, didSelect template: CPTemplate) {
        if let index = tabBarTemplate.templates.firstIndex(of: template) {
            selectedIndex = index
            selectedIndexSubject.send(index)
        } 
    }
}

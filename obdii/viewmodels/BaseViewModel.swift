/**
 
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 
 
Base Class for View Models so all the ViewModels  have  a standard onChanged hook.
 
 We use this hook on the CarPlay side to trigger refreshes because CarPlay doesn't support the full two-way binding like SwiftUI
 
 _Italic text__
 __Bold text__
 ~~Strikethrough text~~
 
 */
@MainActor
class BaseViewModel {
    var onChanged: (() -> Void)?
}

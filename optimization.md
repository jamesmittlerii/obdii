**Optimization**

Talking to the car via OBDII is somewhat expensive. There is no true notification pattern - the app must "poll" for updates and more frequent calls can overwhelm the adapter and car leading to increased error rates.

To help alleviate the amount of data exchanged, the app optimizes which PIDs it requests to just what are displayed on the current screen or tab. This is somewhat challenging as there are CarPlay templates and SwiftUI views to manage and the opportunity to have both visible at the same time showing shared PIDs.

CarPlay and SwiftUI have different semantics for revealing their visibility so the app incorporates different techniques.

The key is a PIDInterestRegistry class. It maintains which PIDs are current "of interest" and the polling loop creates a subset of PIDs that are enabled and of interest.

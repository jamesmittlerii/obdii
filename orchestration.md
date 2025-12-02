**Basic Orchestration**

* The user calls [Connect](https://github.com/jamesmittlerii/obdii/blob/main/obdii/core/OBDConnectionManager.swift#L228) in OBDConnectionManager. This intiates a call to [OBDService.startContinuousUpdates](https://github.com/jamesmittlerii/SwiftOBD2/blob/main/Sources/SwiftOBD2/obd2service.swift#L230) in the SwiftOBD2 library.
* The SwiftOBD2 library requests the list of PIDs (Parameter Ids) every sec to refresh the latest stats.
* The data is saved in a Model, [PIDStats](https://github.com/jamesmittlerii/obdii/blob/main/obdii/core/OBDConnectionManager.swift#L64) which is an array of PIDs + stats.
* The Gauge View Model subscribes to updates of PIDStats and in turn creates an [array of Tiles](https://github.com/jamesmittlerii/obdii/blob/main/obdii/viewmodels/GaugesViewModel.swift#L56) for the UI.
* The Gauge View subscribes to Tile updates via @State and [redraws the gauges](https://github.com/jamesmittlerii/obdii/blob/main/obdii/swiftui/GaugesView.swift#L60) when they change.

<img width="960" height="540" alt="Basic Orchestration" src="https://github.com/user-attachments/assets/b006e4a0-6fec-4b75-8dd1-4830a637522d" />

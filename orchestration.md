**Basic Orchestration**

* The user calls Connect in OBDConnectionManager. This intiates a call to OBDService.startUpdates in the SwiftOBD2 library.
* The SwiftOBD2 library requests the list of PIDs (Parameter Ids) every sec to refresh the latest stats.
* The data is saved in a Model, PIDStats which is an array of PIDs + stats.
* The Gauge View Model subscribes to updates of PIDStats and in turn creates a Array of Tiles for the UI.
* The Gauge View subscribes to Tile updates via @State and redraws the gauges when they change.

<img width="960" height="540" alt="Basic Orchestration" src="https://github.com/user-attachments/assets/b006e4a0-6fec-4b75-8dd1-4830a637522d" />

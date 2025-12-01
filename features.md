**Features**

The application exercises several features...

* SwiftUI and UIKit/CarPlay screens. Multiple use of HStack/VStack/ZStack container views.
* MVVM architecture with shared view models utilizing @State/@Observable constructs.
* Tabbed Navigation and NavigationLink/NavigationStack organization.
* Gauges can be considered an "enhanced" progress view with limits and color indicators for ranges.
* Settings saved via [@AppStorage](https://www.hackingwithswift.com/quick-start/swiftui/what-is-the-appstorage-property-wrapper).
* PIDs are loaded and logs exported via JSON APIs.
* Dynamic support for Metric/Imperial units.
* Support for Bluetooth, Wifi and demo mode OBDII adapters.

The SwiftOBD2 library was a good start for abstracting OBD2 communications but needed significant work to fix bugs and extend capabilities to meet the needs of this app.

The demo mode was extended to provide more lifelike values for the sensors that change over time.

The app makes heavy use of [@Published/Subscription](https://www.hackingwithswift.com/quick-start/swiftui/what-is-the-published-property-wrapper) semantics to update the screens in real-time in response to changing data.

The app supports a full list of [OBD2 mode1](https://www.dashlogic.com/docs/technical/obdii_pids) sensors with expected ranges and data types.

The app includes a full list of [DTCs](https://www.edmunds.com/obd-dtc/) with explanation, cause and corrections.

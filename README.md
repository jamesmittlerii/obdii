**Rheosoft OBD2**

Rheosoft OBD2 is a CarPlay-enabled [OBD-II](./obd2.md) viewer focused on reporting diagnostic trouble codes, readiness monitors, and live sensor data.

The application is designed to run on iPhone and connect to a car's OBD-II port via an ELM327 adapter.

**Explore**

- [Features](./features.md)
- [Architecture](./architecture.md)
- [Optimizations](./optimization.md)

**Implementation**

The Application is built in Swift for IOS 26. It produces Swift Views and CarPlay templates.

The OBD2 interface uses a [forked](https://github.com/jamesmittlerii/SwiftOBD2) version of the Swift OBD2 library by [kkonteh97](https://github.com/kkonteh97/SwiftOBD2).

The CarPlay user interface builds on Apple’s CarSample from the WWDC20 session “[Accelerate your app with CarPlay](https://github.com/below/CarSample),” and was extensively rewritten to support the OBD-II functionality.

**Demo Video**

https://github.com/user-attachments/assets/c0161120-6394-471f-b81d-d7e4da525f36


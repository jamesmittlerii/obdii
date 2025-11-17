**OBD-II**

What is OBD-II?

OBD-II (On-Board Diagnostics, second generation) is a protocol standard for communicating with the car's ECU (electronic control unit). The ECU reports quite a bit of data through OBD-II related to engine metrics, diagnostic faults and sensor data.

OBD-II is simply a protocol - since 1996 all new cars have provided a standard port to facilitate the communication. Typically the port is under the dash on the driver's side.

<img width="390" height="219" alt="obd2" src="https://github.com/user-attachments/assets/e59103a0-e671-4a2e-9dc4-acf4f1a76e34" />

To communicate through the port we need an adapter (that plugs into the port) that can communicate with an iPhone. You can purchase these on Amazon or Ebay - they support Bluetooth or Wifi (which is how the iPhone connects to the adapter). The adapter adds an other protocol, ELM327. iPhone speaks ELM327 to the adapter; the adapter translates between ELM327 and OBD-II through the port to the ECU.

<img width="518" height="268" alt="image" src="https://github.com/user-attachments/assets/7ed7dccc-ffb0-4e08-b895-7db836e7c1c6" />

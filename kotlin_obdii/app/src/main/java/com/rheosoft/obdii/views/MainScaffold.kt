package com.rheosoft.obdii.views

class MainScaffold(
    selectedIndex: Int = 0,
) {
    companion object {
        val destinations = listOf("Settings", "Gauges", "Fuel", "MIL", "DTCs")
    }

    var selectedIndex: Int = selectedIndex
        private set

    val selectedDestination: String
        get() = destinations[selectedIndex]

    fun onDestinationSelected(index: Int) {
        if (index in destinations.indices) selectedIndex = index
    }

    fun pageActivityFlags(): Map<String, Boolean> = mapOf(
        "Gauges" to (selectedIndex == 1),
        "Fuel" to (selectedIndex == 2),
        "MIL" to (selectedIndex == 3),
        "DTCs" to (selectedIndex == 4),
    )
}

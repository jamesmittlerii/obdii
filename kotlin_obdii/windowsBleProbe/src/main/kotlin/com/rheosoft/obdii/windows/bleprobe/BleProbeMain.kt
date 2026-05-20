package com.rheosoft.obdii.windows.bleprobe

import com.rheosoft.obdii.core.LibraryConnectionType
import com.rheosoft.obdii.core.LogCategory
import com.rheosoft.obdii.core.ObdLogger
import com.rheosoft.obdii.core.ObdService
import com.rheosoft.obdii.core.communication.ble.BleCharacteristic
import com.rheosoft.obdii.core.communication.ble.BlePeripheral
import com.rheosoft.obdii.core.communication.ble.commonObdDeviceNames
import com.rheosoft.obdii.core.communication.ble.supportedBleServiceUuids
import com.rheosoft.obdii.core.obdInfo
import com.rheosoft.obdii.windows.ble.SimpleBlePlatformAdapter
import com.rheosoft.obdii.windows.ble.forceWindowsProcessExit
import kotlinx.coroutines.runBlocking
import org.simplejavable.Adapter
import kotlin.system.exitProcess

/**
 * Staged Windows BLE exit repro. Finds which step leaves non-daemon WinRT threads behind.
 *
 * Examples:
 *   `./gradlew :windowsBleProbe:run --args="--stop-after=enabled --exit-mode=soft"`
 *   `./gradlew :windowsBleProbe:run --args="--stop-after=scan --exit-mode=soft"`
 *   `./gradlew :windowsBleProbe:run --args="--stop-after=connect --exit-mode=soft"`
 *   `./gradlew :windowsBleProbe:run --args="--stop-after=notify --exit-mode=soft"`
 *   `./gradlew :windowsBleProbe:run --args="--stop-after=full --exit-mode=soft"`
 *   `./gradlew :windowsBleProbe:run`  (defaults: full + force)
 */
fun main(args: Array<String>) {
    val config = parseProbeArgs(args) ?: return
    runBlocking {
        installConsoleLogging()
        ObdLogger.verboseBleComms = true
        println("[probe] stop-after=${config.stopAfter.raw} exit-mode=${config.exitMode.raw}")

        var adapter: SimpleBlePlatformAdapter? = null
        val obdService = if (config.stopAfter == StopAfter.FULL) {
            adapter = SimpleBlePlatformAdapter()
            ObdService(LibraryConnectionType.bluetooth, bleAdapter = adapter!!)
        } else {
            null
        }
        var peripheralId: String? = null
        var didConnect = false

        try {
            logStep("bluetooth-enabled-check") {
                if (!Adapter.isBluetoothEnabled()) {
                    error("Bluetooth is disabled on this PC.")
                }
            }
            if (config.stopAfter == StopAfter.ENABLED) {
                logMilestone(StopAfter.ENABLED)
                return@runBlocking
            }

            adapter = SimpleBlePlatformAdapter()
            val ble = adapter!!

            when (config.stopAfter) {
                StopAfter.FULL -> {
                    val service = obdService!!
                    logStep("obd-startConnection (scan+connect+notify+ATZ)") {
                        service.startConnection(timeoutMs = 30_000)
                    }
                    val name = service.connectedPeripheral?.name
                        ?: service.connectedPeripheral?.id
                        ?: "adapter"
                    println("Hello OK — connected to $name")
                    logMilestone(StopAfter.FULL)
                }
                else -> {
                    val target = logStep("scan") {
                        scanForObd(ble)
                    }
                    if (config.stopAfter == StopAfter.SCAN) {
                        logMilestone(StopAfter.SCAN)
                        return@runBlocking
                    }

                    peripheralId = target.id
                    logStep("connect") {
                        println("Connecting to ${target.name ?: target.id} …")
                        ble.connect(target.id, timeoutMs = 15_000)
                    }
                    didConnect = true
                    if (config.stopAfter == StopAfter.CONNECT) {
                        logMilestone(StopAfter.CONNECT)
                        return@runBlocking
                    }

                    logStep("gatt-notify-subscribe") {
                        subscribeFirstNotifyCharacteristic(ble, target.id)
                    }
                    logMilestone(StopAfter.NOTIFY)
                }
            }
        } catch (t: Throwable) {
            System.err.println("Probe failed: ${t.message}")
            t.printStackTrace(System.err)
            exitProcess(1)
        } finally {
            if (config.stopAfter == StopAfter.FULL) {
                logStep("obd-stopConnection") {
                    obdService?.stopConnection()
                }
            } else if (didConnect && peripheralId != null) {
                logStep("ble-disconnect") {
                    adapter!!.disconnect(peripheralId!!)
                }
            }
            adapter?.let { a ->
                logStep("simpleble-shutdown") {
                    a.shutdown()
                }
            }
            logNonDaemonThreads("after-teardown")
        }

        finishProbe(config)
    }
}

private enum class StopAfter(val raw: String) {
    ENABLED("enabled"),
    SCAN("scan"),
    CONNECT("connect"),
    NOTIFY("notify"),
    FULL("full"),
    ;

    companion object {
        fun fromRaw(raw: String): StopAfter? = entries.firstOrNull { it.raw == raw.lowercase() }
    }
}

private enum class ExitMode(val raw: String) {
    /** Normal JVM exit — hangs if WinRT threads remain. */
    SOFT("soft"),
    /** Runtime.halt(0) only. */
    HALT("halt"),
    /** taskkill + halt (default for day-to-day runs). */
    FORCE("force"),
    ;

    companion object {
        fun fromRaw(raw: String): ExitMode? = entries.firstOrNull { it.raw == raw.lowercase() }
    }
}

private data class ProbeConfig(
    val stopAfter: StopAfter,
    val exitMode: ExitMode,
)

private fun parseProbeArgs(args: Array<String>): ProbeConfig? {
    if (args.contains("--help") || args.contains("-h")) {
        printUsage()
        return null
    }

    var stopAfter: StopAfter? = null
    var exitMode = ExitMode.FORCE

    for (arg in args) {
        when {
            arg == "--ble-only" -> stopAfter = StopAfter.CONNECT
            arg.startsWith("--stop-after=") -> {
                val raw = arg.substringAfter("=")
                stopAfter = StopAfter.fromRaw(raw) ?: run {
                    System.err.println("Unknown stop-after stage: $raw")
                    printUsage()
                    return null
                }
            }
            arg.startsWith("--exit-mode=") -> {
                exitMode = ExitMode.fromRaw(arg.substringAfter("=")) ?: run {
                    System.err.println("Unknown exit mode: ${arg.substringAfter("=")}")
                    printUsage()
                    return null
                }
            }
        }
    }

    if (stopAfter == null) {
        stopAfter = StopAfter.FULL
    }

    return ProbeConfig(stopAfter = stopAfter, exitMode = exitMode)
}

private fun printUsage() {
    println(
        """
        |BLE exit probe — staged stop + exit experiment
        |
        |  --stop-after=<stage>   Where to stop before teardown (default: full)
        |    enabled   JNI load + isBluetoothEnabled only
        |    scan      + BLE scan (then endScan)
        |    connect   + GATT connect (no notify, no AT commands)
        |    notify    + discover GATT + notify subscribe (no AT commands)
        |    full      + ObdService.startConnection (notify + ELM ATZ…)
        |
        |  --exit-mode=<mode>     How to terminate the JVM (default: force)
        |    soft      System.exit(0) — use to test if Gradle hangs
        |    halt      Runtime.halt(0)
        |    force     taskkill self + halt
        |
        |  --ble-only             Alias for --stop-after=connect
        |  --help, -h
        |
        |Examples:
        |  ./gradlew :windowsBleProbe:run --args="--stop-after=enabled --exit-mode=soft"
        |  ./gradlew :windowsBleProbe:run --args="--stop-after=notify --exit-mode=soft"
        """.trimMargin(),
    )
}

private suspend fun scanForObd(adapter: SimpleBlePlatformAdapter): BlePeripheral {
    val found = adapter.scan(timeoutMs = 12_000, serviceUuids = supportedBleServiceUuids)
    println("Found ${found.size} peripheral(s): ${found.joinToString { "${it.name ?: "?"} (${it.id})" }}")
    return pickObdPeripheral(found) ?: error("No OBD BLE peripheral found")
}

private suspend fun subscribeFirstNotifyCharacteristic(
    adapter: SimpleBlePlatformAdapter,
    peripheralId: String,
) {
    val notifyChar = findNotifyCharacteristic(adapter, peripheralId)
        ?: error("No notifiable characteristic found")
    println("[probe] notify char=${notifyChar.uuid}")
    adapter.setNotificationListener(peripheralId, notifyChar.uuid) { payload ->
        if (ObdLogger.verboseBleComms) {
            println("[probe] notify rx ${payload.size} bytes")
        }
    }
    adapter.enableNotifications(peripheralId, notifyChar.uuid)
}

private suspend fun findNotifyCharacteristic(
    adapter: SimpleBlePlatformAdapter,
    peripheralId: String,
): BleCharacteristic? {
    for (service in adapter.discoverServices(peripheralId)) {
        val chars = adapter.discoverCharacteristics(peripheralId, service.uuid)
        chars.firstOrNull { it.canNotify }?.let { return it }
    }
    return null
}

private fun logMilestone(stage: StopAfter) {
    logNonDaemonThreads("milestone-$stage")
    println("[probe] Stopped after stage: ${stage.raw} (teardown runs next, then exit attempt).")
}

private fun finishProbe(config: ProbeConfig) {
    logNonDaemonThreads("before-exit")
    println("Probe finished cleanly.")
    if (config.exitMode == ExitMode.SOFT && config.stopAfter.ordinal >= StopAfter.SCAN.ordinal) {
        println("[probe] Expect Gradle hang here if WinRT scan threads block JVM exit.")
    }
    println("[probe] Attempting exit via ${config.exitMode.raw} …")
    when (config.exitMode) {
        ExitMode.SOFT -> exitProcess(0)
        ExitMode.HALT -> Runtime.getRuntime().halt(0)
        ExitMode.FORCE -> forceWindowsProcessExit()
    }
}

private fun pickObdPeripheral(found: List<BlePeripheral>): BlePeripheral? =
    found.firstOrNull { p ->
        val n = p.name?.uppercase().orEmpty()
        commonObdDeviceNames.any { n.contains(it) }
    } ?: found.firstOrNull { !it.name.isNullOrBlank() }

private fun logNonDaemonThreads(label: String) {
    val live = Thread.getAllStackTraces().keys
        .filter { it.isAlive && !it.isDaemon }
        .sortedBy { it.name }
    println("[probe] non-daemon threads ($label): ${live.size}")
    live.forEach { thread ->
        println("[probe]   ${thread.name} (${thread.state})")
    }
}

private inline fun <T> logStep(label: String, block: () -> T): T {
    val started = System.nanoTime()
    println("[probe] $label …")
    return try {
        block().also {
            val ms = (System.nanoTime() - started) / 1_000_000
            println("[probe] $label done (${ms}ms)")
        }
    } catch (t: Throwable) {
        val ms = (System.nanoTime() - started) / 1_000_000
        System.err.println("[probe] $label FAILED after ${ms}ms: ${t.message}")
        throw t
    }
}

private fun installConsoleLogging() {
    ObdLogger.platformLogDelegate = { message, tag, level ->
        val marker = when (level.lowercase()) {
            "error" -> "ERROR"
            "warning" -> "WARN"
            "info" -> "INFO"
            "debug" -> "DEBUG"
            else -> level.uppercase()
        }
        val line = "[$marker $tag] $message"
        if (level.equals("error", ignoreCase = true) || level.equals("warning", ignoreCase = true)) {
            System.err.println(line)
        } else {
            println(line)
        }
    }
    ObdLogger.mutesConsole = true
    obdInfo("BLE probe logging enabled.", LogCategory.Bluetooth)
}

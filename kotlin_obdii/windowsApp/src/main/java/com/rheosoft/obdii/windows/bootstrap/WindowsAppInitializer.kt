package com.rheosoft.obdii.windows.bootstrap

import com.rheosoft.obdii.core.OBDConnectionManager
import com.rheosoft.obdii.core.ObdLogger
import com.rheosoft.obdii.core.LogCategory
import com.rheosoft.obdii.core.obdError
import com.rheosoft.obdii.core.obdInfo
import com.rheosoft.obdii.windows.ble.SimpleBlePlatformAdapter
import org.simplejavable.Adapter

object WindowsAppInitializer {
    private var bleReady = false
    private var bleAdapter: SimpleBlePlatformAdapter? = null

    fun initialize() {
        if (bleReady) return
        bleReady = true
        initializeConsoleLogging()
        ObdLogger.verboseBleComms = true

        runCatching {
            if (!Adapter.isBluetoothEnabled()) {
                obdError("Bluetooth is disabled on this PC.", LogCategory.Bluetooth)
                return
            }
            val adapter = SimpleBlePlatformAdapter()
            bleAdapter = adapter
            OBDConnectionManager.setBleAdapter(adapter)
            obdInfo("Windows BLE adapter ready (SimpleJavaBLE).", LogCategory.Bluetooth)
        }.onFailure { error ->
            obdError(
                "Windows BLE unavailable: ${error.message ?: error.javaClass.simpleName}",
                LogCategory.Bluetooth,
            )
        }
    }

    fun isBluetoothEnabled(): Boolean = runCatching { Adapter.isBluetoothEnabled() }.getOrDefault(false)

    fun shutdown() {
        bleAdapter?.shutdown()
        bleAdapter = null
    }

    private fun initializeConsoleLogging() {
        ObdLogger.platformLogDelegate = { message, tag, level ->
            val marker = when (level.lowercase()) {
                "error" -> "ERROR"
                "warning" -> "WARN"
                "info" -> "INFO"
                "debug" -> "DEBUG"
                else -> level.uppercase()
            }
            val formatted = "[$marker $tag] ${message.toConsoleSafeAscii()}"
            when (level.lowercase()) {
                "error", "warning" -> System.err.println(formatted)
                else -> println(formatted)
            }
        }
        ObdLogger.mutesConsole = true
    }

    private fun String.toConsoleSafeAscii(): String =
        replace("\u2192", "->")
            .replace("\u2190", "<-")
            .map { ch -> if (ch.code in 32..126 || ch == '\r' || ch == '\n' || ch == '\t') ch else '?' }
            .joinToString("")

}

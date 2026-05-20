package com.rheosoft.obdii.windows.ble

/**
 * Terminates the JVM on Windows when SimpleBLE/WinRT leaves non-daemon threads
 * that prevent normal exit. Repro shows this begins after [Adapter.scanStart], not only notify.
 */
fun forceWindowsProcessExit(): Nothing {
    val os = System.getProperty("os.name").orEmpty().lowercase()
    if (os.contains("win")) {
        // SimpleBLE WinRT leaves non-daemon JNI threads (Thread-3..N); halt alone may not return.
        runCatching {
            val pid = ProcessHandle.current().pid()
            ProcessBuilder("taskkill", "/F", "/PID", pid.toString())
                .redirectError(ProcessBuilder.Redirect.DISCARD)
                .redirectOutput(ProcessBuilder.Redirect.DISCARD)
                .start()
        }
    }
    Runtime.getRuntime().halt(0)
    error("unreachable")
}

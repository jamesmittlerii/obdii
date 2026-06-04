package com.rheosoft.obdii.screenmodels

enum class OnboardingPageKind {
    Welcome,
    TabTour,
    GaugePicker,
    Connect,
    Demo,
}

data class OnboardingPage(
    val title: String,
    val body: String,
    val kind: OnboardingPageKind,
    /** When set, onboarding switches the main app to this tab so the real screen shows behind the scrim. */
    val previewTabIndex: Int? = null,
)

object OnboardingScreenModel {
    const val SETTINGS_TAB_INDEX: Int = 0
    const val GAUGES_TAB_INDEX: Int = 1

    val welcomeSummaryPoints: List<String> = listOf(
        "Settings — connect your adapter, units, and gauge selection",
        "Gauges — live PID values as rings or a list; tap for detail",
        "Fuel — fuel-system and O2 injector feedback by bank",
        "MIL — malfunction indicator (check engine) lamp and readiness",
        "DTCs — stored and pending diagnostic trouble codes",
    )

    val pages: List<OnboardingPage> = listOf(
        OnboardingPage(
            title = "Welcome to Rheosoft OBDII",
            body = "Read live OBD-II data from your vehicle on your phone or PC. Use an ELM327-compatible adapter on your OBD-II port (Bluetooth or Wi‑Fi), or Demo mode to explore without hardware.",
            kind = OnboardingPageKind.Welcome,
        ),
        OnboardingPage(
            title = "Settings",
            body = "Connect an ELM327 adapter to your OBD-II port on your vehicle, then configure Bluetooth or Wi‑Fi here. See your adapter for details. If you don't have an adapter, choose Demo mode to see the app in action.",
            kind = OnboardingPageKind.TabTour,
            previewTabIndex = SETTINGS_TAB_INDEX,
        ),
        OnboardingPage(
            title = "Gauges dashboard",
            body = "Live PID values on the dashboard. Switch ring or list layout at the top, and drag gauges to reorder.",
            kind = OnboardingPageKind.TabTour,
            previewTabIndex = GAUGES_TAB_INDEX,
        ),
        OnboardingPage(
            title = "Gauge selection",
            body = "Choose which PIDs appear on the dashboard. Changes apply to both ring and list views.",
            kind = OnboardingPageKind.GaugePicker,
            previewTabIndex = SETTINGS_TAB_INDEX,
        ),
        OnboardingPage(
            title = "Fuel Control Status",
            body = "Fuel-system status per bank—injector O2 closed-loop feedback and trim from the ECU.",
            kind = OnboardingPageKind.TabTour,
            previewTabIndex = 2,
        ),
        OnboardingPage(
            title = "MIL",
            body = "MIL (Malfunction Indicator Lamp), aka CEL (Check Engine Light). Lamp on/off status and OBD readiness monitors.",
            kind = OnboardingPageKind.TabTour,
            previewTabIndex = 3,
        ),
        OnboardingPage(
            title = "DTCs",
            body = "Stored and pending trouble codes. Tap a code for more detail.",
            kind = OnboardingPageKind.TabTour,
            previewTabIndex = 4,
        ),
        OnboardingPage(
            title = "Connect when you're ready",
            body = "When you have an adapter, stay on Settings, choose Bluetooth or Wi‑Fi, and tap Connect.",
            kind = OnboardingPageKind.Connect,
            previewTabIndex = SETTINGS_TAB_INDEX,
        ),
        OnboardingPage(
            title = "Try Demo mode",
            body = "Demo simulates a connected vehicle with live gauge updates—no adapter required. We'll open Gauges for you.",
            kind = OnboardingPageKind.Demo,
            previewTabIndex = GAUGES_TAB_INDEX,
        ),
    )

    val DEMO_PAGE_INDEX: Int = pages.lastIndex
    val GAUGE_PICKER_PAGE_INDEX: Int = pages.indexOfFirst { it.kind == OnboardingPageKind.GaugePicker }

    fun previewTabIndex(pageIndex: Int): Int? = pages.getOrNull(pageIndex)?.previewTabIndex

    fun highlightedNavTab(pageIndex: Int): Int? =
        if (showGaugePicker(pageIndex)) null else previewTabIndex(pageIndex)

    fun showGaugePicker(pageIndex: Int): Boolean =
        pages.getOrNull(pageIndex)?.kind == OnboardingPageKind.GaugePicker

    fun usesCompactScrim(pageIndex: Int): Boolean =
        showGaugePicker(pageIndex) || isGaugesDashboardPage(pageIndex)

    fun isGaugesDashboardPage(pageIndex: Int): Boolean {
        val page = pages.getOrNull(pageIndex) ?: return false
        return page.kind == OnboardingPageKind.TabTour && page.previewTabIndex == GAUGES_TAB_INDEX
    }

    fun isDemoPage(pageIndex: Int): Boolean = pages.getOrNull(pageIndex)?.kind == OnboardingPageKind.Demo

    fun isLastPage(pageIndex: Int): Boolean = pageIndex == pages.lastIndex

    fun showWelcomeSummary(pageIndex: Int): Boolean =
        pages.getOrNull(pageIndex)?.kind == OnboardingPageKind.Welcome
}

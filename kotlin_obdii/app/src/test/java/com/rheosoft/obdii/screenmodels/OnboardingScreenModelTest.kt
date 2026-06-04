package com.rheosoft.obdii.screenmodels

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class OnboardingScreenModelTest {
    @Test
    fun `has nine intro pages ending with demo`() {
        assertEquals(9, OnboardingScreenModel.pages.size)
        assertEquals(OnboardingPageKind.Demo, OnboardingScreenModel.pages.last().kind)
    }

    @Test
    fun `demo page is last and highlights gauges tab`() {
        assertTrue(OnboardingScreenModel.isDemoPage(OnboardingScreenModel.DEMO_PAGE_INDEX))
        assertEquals(
            OnboardingScreenModel.GAUGES_TAB_INDEX,
            OnboardingScreenModel.previewTabIndex(OnboardingScreenModel.DEMO_PAGE_INDEX),
        )
    }

    @Test
    fun `gauge picker page opens picker and hides nav highlight`() {
        val idx = OnboardingScreenModel.GAUGE_PICKER_PAGE_INDEX
        assertTrue(OnboardingScreenModel.showGaugePicker(idx))
        assertTrue(OnboardingScreenModel.usesCompactScrim(idx))
        assertNull(OnboardingScreenModel.highlightedNavTab(idx))
    }

    @Test
    fun `gauges dashboard page uses compact scrim`() {
        val idx = OnboardingScreenModel.pages.indexOfFirst {
            it.kind == OnboardingPageKind.TabTour && it.previewTabIndex == OnboardingScreenModel.GAUGES_TAB_INDEX
        }
        assertTrue(OnboardingScreenModel.isGaugesDashboardPage(idx))
        assertTrue(OnboardingScreenModel.usesCompactScrim(idx))
        assertEquals(OnboardingScreenModel.GAUGES_TAB_INDEX, OnboardingScreenModel.highlightedNavTab(idx))
    }

    @Test
    fun `welcome has no live tab preview and shows summary`() {
        assertNull(OnboardingScreenModel.previewTabIndex(0))
        assertTrue(OnboardingScreenModel.showWelcomeSummary(0))
        assertEquals(5, OnboardingScreenModel.welcomeSummaryPoints.size)
    }

    @Test
    fun `last page detection`() {
        assertFalse(OnboardingScreenModel.isLastPage(0))
        assertTrue(OnboardingScreenModel.isLastPage(OnboardingScreenModel.pages.lastIndex))
    }
}

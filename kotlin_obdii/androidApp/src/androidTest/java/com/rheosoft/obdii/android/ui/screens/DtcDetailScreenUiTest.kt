package com.rheosoft.obdii.android.ui.screens

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.v2.createComposeRule
import com.rheosoft.obdii.core.TroubleCodeMetadata
import com.rheosoft.obdii.screenmodels.DtcDetailScreenModel
import org.junit.Rule
import org.junit.Test

class DtcDetailScreenUiTest {
    @get:Rule
    val composeRule = createComposeRule()

    private fun dtc(code: String, severity: String = "Moderate") = TroubleCodeMetadata(
        code = code,
        title = "Title $code",
        description = "Description $code",
        severity = severity,
        causes = listOf("Cause 1", "Cause 2"),
        remedies = listOf("Remedy 1")
    )

    @Test
    fun testRendersDtcDetailSectionHeaders() {
        val model = DtcDetailScreenModel(dtc("P0300"))
        
        composeRule.setContent {
            DtcDetailScreen(detail = model, onClose = {})
        }

        composeRule.assertTextVisible("Overview")
        composeRule.assertTextVisible("Description")
        composeRule.assertTextVisibleAfterScroll("Potential causes")
        composeRule.assertTextVisibleAfterScroll("Possible remedies")
    }

    @Test
    fun testNavigationTitleIsCode() {
        val model = DtcDetailScreenModel(dtc("P0300"))
        
        composeRule.setContent {
            DtcDetailScreen(detail = model, onClose = {})
        }

        composeRule.onAllNodesWithText("P0300").assertCountEquals(2)
    }

    @Test
    fun testOverviewSectionContainsLabeledContent() {
        val model = DtcDetailScreenModel(dtc("P0300", "High"))
        
        composeRule.setContent {
            DtcDetailScreen(detail = model, onClose = {})
        }

        composeRule.assertTextVisible("Code")
        composeRule.onAllNodesWithText("P0300").assertCountEquals(2)
        composeRule.assertTextVisible("Title")
        composeRule.assertTextVisible("Title P0300")
        composeRule.assertTextVisible("Severity")
        composeRule.assertTextVisible("High")
    }

    @Test
    fun testDescriptionTextIsPresent() {
        val model = DtcDetailScreenModel(dtc("P0300"))
        
        composeRule.setContent {
            DtcDetailScreen(detail = model, onClose = {})
        }

        composeRule.onNodeWithText("Description P0300").assertIsDisplayed()
    }

    @Test
    fun testCausesAndRemediesArePresent() {
        val model = DtcDetailScreenModel(dtc("P0300"))
        
        composeRule.setContent {
            DtcDetailScreen(detail = model, onClose = {})
        }

        composeRule.assertTextVisibleAfterScroll("Cause 1")
        composeRule.assertTextVisibleAfterScroll("Cause 2")
        composeRule.assertTextVisibleAfterScroll("Remedy 1")
    }
}

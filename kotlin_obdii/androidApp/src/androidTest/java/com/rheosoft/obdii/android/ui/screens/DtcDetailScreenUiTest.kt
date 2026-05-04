package com.rheosoft.obdii.android.ui.screens

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
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

        composeRule.onNodeWithText("Overview").assertIsDisplayed()
        composeRule.onNodeWithText("Description").assertIsDisplayed()
        composeRule.onNodeWithText("Potential causes").assertIsDisplayed()
        composeRule.onNodeWithText("Possible remedies").assertIsDisplayed()
    }

    @Test
    fun testNavigationTitleIsCode() {
        val model = DtcDetailScreenModel(dtc("P0300"))
        
        composeRule.setContent {
            DtcDetailScreen(detail = model, onClose = {})
        }

        composeRule.onNodeWithText("P0300").assertIsDisplayed()
    }

    @Test
    fun testOverviewSectionContainsLabeledContent() {
        val model = DtcDetailScreenModel(dtc("P0300", "High"))
        
        composeRule.setContent {
            DtcDetailScreen(detail = model, onClose = {})
        }

        composeRule.onNodeWithText("Code: P0300").assertIsDisplayed()
        composeRule.onNodeWithText("Title: Title P0300").assertIsDisplayed()
        composeRule.onNodeWithText("Severity: High").assertIsDisplayed()
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

        composeRule.onNodeWithText("• Cause 1").assertIsDisplayed()
        composeRule.onNodeWithText("• Cause 2").assertIsDisplayed()
        composeRule.onNodeWithText("• Remedy 1").assertIsDisplayed()
    }
}

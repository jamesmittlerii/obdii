package com.rheosoft.obdii.views

import com.rheosoft.obdii.core.TroubleCodeMetadata
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class DtcDetailViewTest {
    @Test
    fun `detail view exposes overview and optional sections`() {
        val detail = DtcDetailView(
            TroubleCodeMetadata(
                code = "P0420",
                title = "Catalyst System Efficiency Below Threshold",
                description = "Bank 1",
                severity = "Moderate",
                causes = listOf("Exhaust leak"),
                remedies = listOf("Inspect catalytic converter"),
            ),
        )
        assertEquals("P0420", detail.title)
        assertTrue(detail.sectionHeaders.contains("OVERVIEW"))
        assertTrue(detail.sectionHeaders.contains("DESCRIPTION"))
        assertTrue(detail.sectionHeaders.contains("POTENTIAL CAUSES"))
        assertTrue(detail.sectionHeaders.contains("POSSIBLE REMEDIES"))
        assertEquals(listOf("Code", "Title", "Severity"), detail.overviewRows.map { it.first })
    }
}

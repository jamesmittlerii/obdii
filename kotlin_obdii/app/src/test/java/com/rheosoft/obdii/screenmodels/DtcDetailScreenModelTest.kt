package com.rheosoft.obdii.screenmodels

import com.rheosoft.obdii.core.TroubleCodeMetadata
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class DtcDetailViewTest {
    @Test
    fun `detail view exposes overview and optional sections`() {
        val detail = DtcDetailScreenModel(
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
        assertTrue(detail.sectionHeaders.contains("Overview"))
        assertTrue(detail.sectionHeaders.contains("Description"))
        assertTrue(detail.sectionHeaders.contains("Potential causes"))
        assertTrue(detail.sectionHeaders.contains("Possible remedies"))
        assertEquals(listOf("Code", "Title", "Severity"), detail.overviewRows.map { it.first })
    }
}

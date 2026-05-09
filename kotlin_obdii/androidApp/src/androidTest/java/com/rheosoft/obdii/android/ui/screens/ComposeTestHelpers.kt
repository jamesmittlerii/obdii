package com.rheosoft.obdii.android.ui.screens

import androidx.compose.ui.test.SemanticsNodeInteraction
import androidx.compose.ui.test.SemanticsNodeInteractionsProvider
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo

fun SemanticsNodeInteractionsProvider.onText(
    text: String,
    ignoreCase: Boolean = true,
): SemanticsNodeInteraction = onAllNodesWithText(text, ignoreCase = ignoreCase)[0]

fun SemanticsNodeInteractionsProvider.assertTextVisible(
    text: String,
    ignoreCase: Boolean = true,
) {
    onText(text, ignoreCase).assertIsDisplayed()
}

fun SemanticsNodeInteractionsProvider.scrollToText(
    text: String,
    ignoreCase: Boolean = true,
) {
    onText(text, ignoreCase).performScrollTo()
}

fun SemanticsNodeInteractionsProvider.assertTextVisibleAfterScroll(
    text: String,
    ignoreCase: Boolean = true,
) {
    scrollToText(text, ignoreCase)
    assertTextVisible(text, ignoreCase)
}

fun SemanticsNodeInteractionsProvider.clickFirstText(text: String) {
    onAllNodesWithText(text, ignoreCase = true)[0].performClick()
}

fun SemanticsNodeInteractionsProvider.clickLastText(text: String) {
    val nodes = onAllNodesWithText(text, ignoreCase = true)
    val lastIndex = nodes.fetchSemanticsNodes().lastIndex
    if (lastIndex < 0) throw AssertionError("No node found with text '$text'")
    nodes[lastIndex].performClick()
}

fun SemanticsNodeInteractionsProvider.assertTextExists(text: String) {
    onAllNodesWithText(text, ignoreCase = true).fetchSemanticsNodes().firstOrNull()
        ?: throw AssertionError("No node found with text '$text'")
}

/**
 * Wait for a node with the given text to exist and be displayed.
 */
fun androidx.compose.ui.test.junit4.ComposeTestRule.waitForText(
    text: String,
    ignoreCase: Boolean = true,
    substring: Boolean = false,
    timeoutMillis: Long = 5000
) {
    this.waitUntil(timeoutMillis) {
        this.onAllNodesWithText(text, ignoreCase = ignoreCase, substring = substring)
            .fetchSemanticsNodes().isNotEmpty()
    }
}

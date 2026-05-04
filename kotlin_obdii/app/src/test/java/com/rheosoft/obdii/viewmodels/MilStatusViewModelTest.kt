package com.rheosoft.obdii.viewmodels

import com.rheosoft.obdii.core.MilStatusProviding
import com.rheosoft.obdii.core.PidInterestRegistry
import com.rheosoft.obdii.core.ReadinessMonitor
import com.rheosoft.obdii.core.Status
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.test.*
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.BeforeEach
import kotlin.test.*

@OptIn(ExperimentalCoroutinesApi::class)
private class MockMilProvider : MilStatusProviding {
    private val flow = MutableStateFlow<Status?>(null)
    override val milStatus: Status? get() = flow.value
    override val milStatusStream: StateFlow<Status?> = flow
    fun send(status: Status?) { flow.value = status }
}

@OptIn(ExperimentalCoroutinesApi::class)
class MilStatusViewModelTest {
    private lateinit var mockProvider: MockMilProvider
    private lateinit var interestRegistry: PidInterestRegistry
    private lateinit var viewModel: MilStatusViewModel
    private val testDispatcher = UnconfinedTestDispatcher()
    private val testScope = TestScope(testDispatcher)

    @BeforeEach
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        mockProvider = MockMilProvider()
        interestRegistry = PidInterestRegistry()
        viewModel = MilStatusViewModel(mockProvider, interestRegistry, testScope)
    }

    @AfterEach
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `testInitializationStatusNullHasStatusFalse`() {
        assertNotNull(viewModel)
        assertNull(viewModel.status)
        assertFalse(viewModel.hasStatus)
    }

    @Test
    fun `testHasstatusFalseWhenNil`() {
        assertNull(viewModel.status)
        assertFalse(viewModel.hasStatus)
    }

    @Test
    fun `testStatusUpdatesFromProvider`() = runTest {
        val monitors = listOf(
            ReadinessMonitor("Misfire", supported = true, ready = true),
            ReadinessMonitor("Fuel System", supported = true, ready = false)
        )
        val status = Status(milOn = true, dtcCount = 2, monitors = monitors)
        mockProvider.send(status)
        
        assertNotNull(viewModel.status)
        assertTrue(viewModel.hasStatus)
        assertEquals("MIL: On (2 DTCs)", viewModel.headerText)
    }

    @Test
    fun `testSortedsupportedmonitorsInitiallyEmpty`() {
        assertTrue(viewModel.sortedSupportedMonitors.isEmpty())
    }

    @Test
    fun `testMonitorSortingNotReadyFirstThenReadyFilteredBySupported`() = runTest {
        val monitors = listOf(
            ReadinessMonitor("B Monitor", supported = true, ready = true),
            ReadinessMonitor("A Monitor", supported = true, ready = false),
            ReadinessMonitor("C Monitor", supported = true, ready = false),
            ReadinessMonitor("Z Unsupported", supported = false, ready = true)
        )
        mockProvider.send(Status(milOn = false, dtcCount = 0, monitors = monitors))

        val sorted = viewModel.sortedSupportedMonitors
        
        // Z Unsupported must be excluded
        assertFalse(sorted.any { it.name == "Z Unsupported" })

        // Not-ready first (A, C), then ready (B)
        val names = sorted.map { it.name }
        assertEquals(listOf("A Monitor", "C Monitor", "B Monitor"), names)
    }

    @Test
    fun `testHeadertextWhenNoStatus`() {
        assertEquals("No MIL Status", viewModel.headerText)
    }

    @Test
    fun `testHeadertextFormattingOff0DTCs`() = runTest {
        mockProvider.send(Status(milOn = false, dtcCount = 0, monitors = emptyList()))
        assertEquals("MIL: Off (0 DTCs)", viewModel.headerText)
    }

    @Test
    fun `testHeadertextFormattingOn1DTCSingular`() = runTest {
        mockProvider.send(Status(milOn = true, dtcCount = 1, monitors = emptyList()))
        assertEquals("MIL: On (1 DTC)", viewModel.headerText)
    }

    @Test
    fun `testHeadertextFormattingOn3DTCs`() = runTest {
        mockProvider.send(Status(milOn = true, dtcCount = 3, monitors = emptyList()))
        assertEquals("MIL: On (3 DTCs)", viewModel.headerText)
    }

    @Test
    fun `testHeadertextFormattingOff5DTCs`() = runTest {
        mockProvider.send(Status(milOn = false, dtcCount = 5, monitors = emptyList()))
        assertEquals("MIL: Off (5 DTCs)", viewModel.headerText)
    }

    @Test
    fun `testAllSupportedMonitorsHaveNonEmptyNames`() = runTest {
        val monitors = listOf(
            ReadinessMonitor("Alpha", supported = true, ready = true),
            ReadinessMonitor("Beta", supported = true, ready = false)
        )
        mockProvider.send(Status(milOn = true, dtcCount = 0, monitors = monitors))

        for (m in viewModel.sortedSupportedMonitors) {
            assertTrue(m.name.isNotEmpty())
        }
    }

    @Test
    fun `testOnchangedCallbackFiresWhenStatusUpdates`() = runTest {
        var callbackFired = false
        viewModel.onChanged = { callbackFired = true }

        mockProvider.send(Status(milOn = true, dtcCount = 0, monitors = emptyList()))
        assertTrue(callbackFired)
    }

    @Test
    fun `testSetvisibleTrueRegistersMILStatusPIDInterest`() = runTest {
        viewModel.setVisible(true)
        assertTrue(interestRegistry.interested.contains("0101"))
    }

    @Test
    fun `testSetvisibleFalseClearsMILStatusPIDInterest`() = runTest {
        viewModel.setVisible(true)
        assertTrue(interestRegistry.interested.contains("0101"))

        viewModel.setVisible(false)
        advanceUntilIdle()
        assertFalse(interestRegistry.interested.contains("0101"))
    }

    @Test
    fun `testSortedsupportedmonitorsExcludesUnsupportedEntries`() = runTest {
        mockProvider.send(
            Status(
                milOn = false,
                dtcCount = 0,
                monitors = listOf(
                    ReadinessMonitor("Supported", supported = true, ready = true),
                    ReadinessMonitor("Unsupported", supported = false, ready = false)
                )
            )
        )
        assertFalse(viewModel.sortedSupportedMonitors.any { it.name == "Unsupported" })
        assertTrue(viewModel.sortedSupportedMonitors.any { it.name == "Supported" })
    }

    @Test
    fun `testHeadertextRemainsStableWhenSameStatusResent`() = runTest {
        val status = Status(milOn = true, dtcCount = 1, monitors = emptyList())
        mockProvider.send(status)
        val first = viewModel.headerText

        mockProvider.send(status)
        val second = viewModel.headerText
        assertEquals(first, second)
    }

    @Test
    fun `testHasstatusReturnsFalseAfterProviderSendsNull`() = runTest {
        mockProvider.send(Status(milOn = true, dtcCount = 2, monitors = emptyList()))
        assertTrue(viewModel.hasStatus)

        mockProvider.send(null)
        assertFalse(viewModel.hasStatus)
    }
}

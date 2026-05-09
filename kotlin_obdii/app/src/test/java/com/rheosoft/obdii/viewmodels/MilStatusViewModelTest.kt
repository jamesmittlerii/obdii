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
    private lateinit var registry: PidInterestRegistry
    private lateinit var viewModel: MilStatusViewModel
    private val testDispatcher = StandardTestDispatcher()
    private val testScope = TestScope(testDispatcher)

    @BeforeTest
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        mockProvider = MockMilProvider()
        registry = PidInterestRegistry()
        viewModel = MilStatusViewModel(mockProvider, registry, testScope)
        testDispatcher.scheduler.runCurrent()
    }

    @AfterTest
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `testInitialization`() {
        assertNull(viewModel.status)
        assertEquals("Waiting for data...", viewModel.uiStateStream.value.headerText)
        assertTrue(viewModel.uiStateStream.value.monitorRows.isEmpty())
    }

    @Test
    fun `testStatusUpdate`() = runTest {
        val status = Status(milOn = true, dtcCount = 1, monitors = emptyList())
        mockProvider.send(status)
        runCurrent()
        assertEquals(status, viewModel.status)
        assertEquals("MIL: On (1 DTC)", viewModel.headerText)
        assertEquals("MIL: On (1 DTC)", viewModel.uiStateStream.value.headerText)
    }

    @Test
    fun `testStatusUpdateWithMultipleDTCs`() = runTest {
        val status = Status(milOn = false, dtcCount = 5, monitors = emptyList())
        mockProvider.send(status)
        runCurrent()
        assertEquals("MIL: Off (5 DTCs)", viewModel.headerText)
    }

    @Test
    fun `testSortedSupportedMonitors`() = runTest {
        val status = Status(
            milOn = false,
            dtcCount = 0,
            monitors = listOf(
                ReadinessMonitor("A", true, true),
                ReadinessMonitor("B", true, false),
                ReadinessMonitor("C", false, false),
                ReadinessMonitor("D", true, true),
            )
        )
        mockProvider.send(status)
        runCurrent()
        val sorted = viewModel.sortedSupportedMonitors
        assertEquals(3, sorted.size)
        assertEquals("B", sorted[0].name) // Not ready first
        assertEquals("A", sorted[1].name) // Then ready, sorted by name
        assertEquals("D", sorted[2].name)
    }

    @Test
    fun `testSetVisible`() = runTest {
        viewModel.setVisible(true)
        runCurrent()
        assertTrue(registry.interested.contains("0101"))

        viewModel.setVisible(false)
        runCurrent()
        assertTrue(registry.interested.isEmpty())
        
        viewModel.setVisible(false) // Redundant
        runCurrent()
        assertTrue(registry.interested.isEmpty())
    }
}

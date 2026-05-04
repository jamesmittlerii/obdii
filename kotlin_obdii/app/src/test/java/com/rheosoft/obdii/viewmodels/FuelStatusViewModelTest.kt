package com.rheosoft.obdii.viewmodels

import com.rheosoft.obdii.core.FuelStatusProviding
import com.rheosoft.obdii.core.PidInterestRegistry
import com.rheosoft.obdii.core.StatusCodeMetadata
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.test.*
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.BeforeEach
import kotlin.test.*

@OptIn(ExperimentalCoroutinesApi::class)
private class MockFuelProvider : FuelStatusProviding {
    private val flow = MutableStateFlow<List<StatusCodeMetadata?>?>(null)
    override val fuelStatus: List<StatusCodeMetadata?>? get() = flow.value
    override val fuelStatusStream: StateFlow<List<StatusCodeMetadata?>?> = flow
    fun send(status: List<StatusCodeMetadata?>?) { flow.value = status }
}

@OptIn(ExperimentalCoroutinesApi::class)
class FuelStatusViewModelTest {
    private lateinit var mockProvider: MockFuelProvider
    private lateinit var interestRegistry: PidInterestRegistry
    private lateinit var viewModel: FuelStatusViewModel
    private val testDispatcher = UnconfinedTestDispatcher()
    private val testScope = TestScope(testDispatcher)

    @BeforeEach
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        mockProvider = MockFuelProvider()
        interestRegistry = PidInterestRegistry()
        viewModel = FuelStatusViewModel(mockProvider, interestRegistry, testScope)
    }

    @AfterEach
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `testInitializationStatusBank1Bank2AllNull`() {
        assertNotNull(viewModel)
        assertNull(viewModel.status)
        assertNull(viewModel.bank1)
        assertNull(viewModel.bank2)
    }

    @Test
    fun `testHasanystatusFalseWhenStatusIsNull`() {
        assertFalse(viewModel.hasAnyStatus)
    }

    @Test
    fun `testHasanystatusFalseWithEmptyStatusList`() = runTest {
        mockProvider.send(emptyList())
        assertFalse(viewModel.hasAnyStatus)
    }

    @Test
    fun `testFuelStatusUpdatesBank1AndBank2`() = runTest {
        val bank1 = StatusCodeMetadata("OK", "Closed loop")
        mockProvider.send(listOf(bank1, null))
        
        assertEquals("OK", viewModel.bank1?.code)
        assertNull(viewModel.bank2)
        assertTrue(viewModel.hasAnyStatus)
    }

    @Test
    fun `testBank1AndBank2AreIndependent`() = runTest {
        val bank1 = StatusCodeMetadata("A", "")
        val bank2 = StatusCodeMetadata("B", "")
        mockProvider.send(listOf(bank1, bank2))

        assertEquals("A", viewModel.bank1?.code)
        assertEquals("B", viewModel.bank2?.code)
    }

    @Test
    fun `testHasanystatusIsTrueWhenAtLeastOneBankHasData`() = runTest {
        val bank1 = StatusCodeMetadata("X", "")
        mockProvider.send(listOf(bank1))
        assertTrue(viewModel.hasAnyStatus)
    }

    @Test
    fun `testSetvisibleTrueRegistersFuelStatusPIDInterest`() = runTest {
        viewModel.setVisible(true)
        assertTrue(interestRegistry.interested.contains("0103"))
    }

    @Test
    fun `testSetvisibleFalseClearsFuelStatusPIDInterest`() = runTest {
        viewModel.setVisible(true)
        assertTrue(interestRegistry.interested.contains("0103"))

        viewModel.setVisible(false)
        // Note: setVisible(false) launches a coroutine to clear interest in this implementation
        advanceUntilIdle()
        assertFalse(interestRegistry.interested.contains("0103"))
    }

    @Test
    fun `testBank1RemainsNullWhenOnlySecondSlotIsProvided`() = runTest {
        val bank2 = StatusCodeMetadata("B2", "Second")
        mockProvider.send(listOf(null, bank2))
        assertNull(viewModel.bank1)
        assertEquals("B2", viewModel.bank2?.code)
    }

    @Test
    fun `testHasanystatusFalseWhenAllBankValuesAreNull`() = runTest {
        mockProvider.send(listOf(null, null))
        assertFalse(viewModel.hasAnyStatus)
    }

    @Test
    fun `testStatusPropertyMirrorsLatestProviderArrayLength`() = runTest {
        mockProvider.send(listOf(StatusCodeMetadata("A", "")))
        assertEquals(1, viewModel.status?.size)

        mockProvider.send(listOf(StatusCodeMetadata("A", ""), StatusCodeMetadata("B", "")))
        assertEquals(2, viewModel.status?.size)
    }
}

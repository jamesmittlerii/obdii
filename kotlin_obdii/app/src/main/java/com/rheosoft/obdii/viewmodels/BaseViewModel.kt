package com.rheosoft.obdii.viewmodels

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

open class BaseViewModel {
    var onChanged: (() -> Unit)? = null

    private val _changeVersion = MutableStateFlow(0)
    val changeVersion: StateFlow<Int> = _changeVersion.asStateFlow()

    protected fun notifyChanged() {
        _changeVersion.value += 1
        onChanged?.invoke()
    }
}

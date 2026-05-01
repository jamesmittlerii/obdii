package com.rheosoft.obdii.viewmodels

open class BaseViewModel {
    var onChanged: (() -> Unit)? = null
    protected fun notifyChanged() {
        onChanged?.invoke()
    }
}

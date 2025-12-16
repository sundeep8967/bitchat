package com.bitchat.android.service

import android.content.Context
import android.content.SharedPreferences

object MeshServicePreferences {
    private const val PREFS_NAME = "bitchat_mesh_service_prefs"
    private const val KEY_AUTO_START = "auto_start_on_boot"
    private const val KEY_BACKGROUND_ENABLED = "background_enabled"

    private var prefs: SharedPreferences? = null
    private var isInitialized = false

    fun init(context: Context) {
        if (!isInitialized) {
            prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            isInitialized = true
        }
    }

    fun isAutoStartEnabled(default: Boolean = true): Boolean {
        return prefs?.getBoolean(KEY_AUTO_START, default) ?: default
    }

    fun setAutoStartEnabled(enabled: Boolean) {
        prefs?.edit()?.putBoolean(KEY_AUTO_START, enabled)?.apply()
    }

    fun isBackgroundEnabled(default: Boolean = true): Boolean {
        return prefs?.getBoolean(KEY_BACKGROUND_ENABLED, default) ?: default
    }

    fun setBackgroundEnabled(enabled: Boolean) {
        prefs?.edit()?.putBoolean(KEY_BACKGROUND_ENABLED, enabled)?.apply()
    }
}


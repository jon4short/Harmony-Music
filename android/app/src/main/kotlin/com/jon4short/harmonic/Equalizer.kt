package com.jon4short.harmonic

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.audiofx.AudioEffect
import androidx.annotation.Keep

@Keep
class Equalizer {
    fun openEqualizer(sessionId: Int, context: Context, activity: Activity): Boolean {
        println("Equalizer: Attempting to open with session ID: $sessionId")
        
        // Method 1: Try standard Android audio effect control panel
        if (tryStandardEqualizer(sessionId, context, activity)) {
            println("Equalizer: Standard equalizer opened successfully")
            return true
        }
        
        // Method 2: Try manufacturer-specific equalizers
        if (tryManufacturerEqualizer(sessionId, context, activity)) {
            println("Equalizer: Manufacturer equalizer opened successfully")
            return true
        }
        
        // Method 3: Try generic music apps with equalizer
        if (tryThirdPartyEqualizers(context, activity)) {
            println("Equalizer: Third-party equalizer opened successfully")
            return true
        }
        
        // Method 4: Open sound settings as last resort
        if (openSoundSettings(activity)) {
            println("Equalizer: Sound settings opened as fallback")
            return true
        }
        
        println("Equalizer: All methods failed")
        return false
    }
    
    private fun tryStandardEqualizer(sessionId: Int, context: Context, activity: Activity): Boolean {
        return try {
            val intent = Intent(AudioEffect.ACTION_DISPLAY_AUDIO_EFFECT_CONTROL_PANEL).apply {
                putExtra(AudioEffect.EXTRA_PACKAGE_NAME, context.packageName)
                putExtra(AudioEffect.EXTRA_AUDIO_SESSION, sessionId)
                putExtra(AudioEffect.EXTRA_CONTENT_TYPE, AudioEffect.CONTENT_TYPE_MUSIC)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            
            if (intent.resolveActivity(context.packageManager) != null) {
                activity.startActivity(intent)
                true
            } else {
                false
            }
        } catch (e: Exception) {
            println("Equalizer: Standard equalizer failed: ${e.message}")
            false
        }
    }

    fun initAudioEffect(sessionId: Int, context: Context) {
        sendAudioEffectIntent(
            sessionId,
            AudioEffect.ACTION_OPEN_AUDIO_EFFECT_CONTROL_SESSION,
            context
        )
        println("Sent AudioEffect intent for opening")
    }

    fun endAudioEffect(sessionId: Int, context: Context) {
        sendAudioEffectIntent(
            sessionId,
            AudioEffect.ACTION_CLOSE_AUDIO_EFFECT_CONTROL_SESSION,
            context
        )
        println("Sent AudioEffect intent for closure")
    }

    private fun sendAudioEffectIntent(sessionId: Int, action: String, context: Context) {
        val intent = Intent(action).apply {
            putExtra(AudioEffect.EXTRA_PACKAGE_NAME, context.packageName)
            putExtra(AudioEffect.EXTRA_AUDIO_SESSION, sessionId)
            putExtra(AudioEffect.EXTRA_CONTENT_TYPE, AudioEffect.CONTENT_TYPE_MUSIC)
        }
        context.sendBroadcast(intent)
    }

    private fun tryManufacturerEqualizer(
        sessionId: Int,
        context: Context,
        activity: Activity
    ): Boolean {
        val equalizerPackages = listOf(
            "com.android.settings.Settings\$SoundSettingsActivity", // Generic Android
            "com.android.settings.EqualizerSettings",
            "com.samsung.android.soundalive", // Samsung
            "com.samsung.android.app.soundalive", // Samsung alternative
            "com.miui.audioeffect", // Xiaomi
            "com.oneplus.sound.tuner", // OnePlus
            "com.htc.music", // HTC
            "com.sonyericsson.music", // Sony
            "com.android.music" // AOSP Music
        )

        for (packageName in equalizerPackages) {
            try {
                val intent = context.packageManager.getLaunchIntentForPackage(packageName)
                if (intent != null) {
                    intent.apply {
                        putExtra(AudioEffect.EXTRA_AUDIO_SESSION, sessionId)
                        putExtra(AudioEffect.EXTRA_PACKAGE_NAME, context.packageName)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    activity.startActivity(intent)
                    return true
                }
            } catch (e: Exception) {
                println("Equalizer: Failed to open $packageName: ${e.message}")
            }
        }
        return false
    }
    
    private fun tryThirdPartyEqualizers(context: Context, activity: Activity): Boolean {
        val equalizerApps = listOf(
            "com.devdnua.equalizer.free", // Equalizer FX
            "com.smartandroidapps.equalizer", // Music Volume EQ
            "com.effects.bassbooster.volumebooster.equalizer", // Bass Booster
            "com.h6ah4i.android.compat.audiofx", // Compatible Audio Effects
            "com.maxmpz.equalizer" // Poweramp Equalizer
        )
        
        for (packageName in equalizerApps) {
            try {
                val intent = context.packageManager.getLaunchIntentForPackage(packageName)
                if (intent != null) {
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    activity.startActivity(intent)
                    return true
                }
            } catch (e: Exception) {
                println("Equalizer: Failed to open third-party app $packageName: ${e.message}")
            }
        }
        return false
    }

    private fun openSoundSettings(activity: Activity): Boolean {
        return try {
            val intent = Intent(android.provider.Settings.ACTION_SOUND_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            activity.startActivity(intent)
            println("Equalizer: Sound settings opened successfully")
            true
        } catch (e: Exception) {
            println("Equalizer: Failed to open sound settings: ${e.message}")
            e.printStackTrace()
            false
        }
    }
}
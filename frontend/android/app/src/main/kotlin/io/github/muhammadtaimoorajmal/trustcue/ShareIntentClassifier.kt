package io.github.muhammadtaimoorajmal.trustcue

import android.content.Intent

enum class ShareIntentKind {
    IGNORE,
    PROCESS_SINGLE,
    UNSUPPORTED_MULTIPLE,
    UNSUPPORTED_ACTION
}

object ShareIntentClassifier {
    /**
     * Pure classification based on action and whether share extras / mime type are present.
     * Decoupled to allow direct testing without requiring mock Android Intent framework instances.
     */
    fun classify(
        action: String?,
        hasShareExtras: Boolean = false,
        hasMimeType: Boolean = false
    ): ShareIntentKind {
        if (action == null || action == Intent.ACTION_MAIN || action == Intent.ACTION_VIEW) {
            return ShareIntentKind.IGNORE
        }
        if (action == Intent.ACTION_SEND_MULTIPLE) {
            return ShareIntentKind.UNSUPPORTED_MULTIPLE
        }
        if (action == Intent.ACTION_SEND) {
            return ShareIntentKind.PROCESS_SINGLE
        }
        // Only report unsupported if the intent was targeted as an incoming share
        if (hasShareExtras || hasMimeType) {
            return ShareIntentKind.UNSUPPORTED_ACTION
        }
        return ShareIntentKind.IGNORE
    }

    /**
     * Overload accepting an [Intent].
     */
    fun classify(intent: Intent?): ShareIntentKind {
        if (intent == null || intent.action == null) {
            return ShareIntentKind.IGNORE
        }
        val hasShareExtras = intent.hasExtra(Intent.EXTRA_TEXT) || intent.hasExtra(Intent.EXTRA_STREAM)
        val hasMime = intent.type != null
        return classify(intent.action, hasShareExtras, hasMime)
    }
}


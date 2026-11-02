package io.github.muhammadtaimoorajmal.trustcue

import org.junit.Assert.assertEquals
import org.junit.Test

class ShareIntentClassifierTest {

    @Test
    fun `null action is ignored`() {
        assertEquals(ShareIntentKind.IGNORE, ShareIntentClassifier.classify(action = null))
    }

    @Test
    fun `ACTION_MAIN is ignored as standard launcher start`() {
        assertEquals(
            ShareIntentKind.IGNORE,
            ShareIntentClassifier.classify("android.intent.action.MAIN")
        )
    }

    @Test
    fun `ACTION_VIEW auth callback deep link is ignored by incoming share channel`() {
        assertEquals(
            ShareIntentKind.IGNORE,
            ShareIntentClassifier.classify("android.intent.action.VIEW")
        )
        // Even if extras or mime type are present on the VIEW intent
        assertEquals(
            ShareIntentKind.IGNORE,
            ShareIntentClassifier.classify(
                "android.intent.action.VIEW",
                hasShareExtras = true,
                hasMimeType = true
            )
        )
    }

    @Test
    fun `ACTION_SEND is classified as PROCESS_SINGLE`() {
        assertEquals(
            ShareIntentKind.PROCESS_SINGLE,
            ShareIntentClassifier.classify("android.intent.action.SEND")
        )
        assertEquals(
            ShareIntentKind.PROCESS_SINGLE,
            ShareIntentClassifier.classify(
                "android.intent.action.SEND",
                hasShareExtras = true,
                hasMimeType = true
            )
        )
    }

    @Test
    fun `ACTION_SEND_MULTIPLE is classified as UNSUPPORTED_MULTIPLE`() {
        assertEquals(
            ShareIntentKind.UNSUPPORTED_MULTIPLE,
            ShareIntentClassifier.classify("android.intent.action.SEND_MULTIPLE")
        )
    }

    @Test
    fun `unexpected action with share extras is classified as UNSUPPORTED_ACTION`() {
        assertEquals(
            ShareIntentKind.UNSUPPORTED_ACTION,
            ShareIntentClassifier.classify("android.intent.action.EDIT", hasShareExtras = true)
        )
        assertEquals(
            ShareIntentKind.UNSUPPORTED_ACTION,
            ShareIntentClassifier.classify("custom.share.action", hasMimeType = true)
        )
    }

    @Test
    fun `benign system action without share extras is ignored`() {
        assertEquals(
            ShareIntentKind.IGNORE,
            ShareIntentClassifier.classify("android.intent.action.LOCALE_CHANGED")
        )
        assertEquals(
            ShareIntentKind.IGNORE,
            ShareIntentClassifier.classify("android.intent.action.BOOT_COMPLETED")
        )
    }
}


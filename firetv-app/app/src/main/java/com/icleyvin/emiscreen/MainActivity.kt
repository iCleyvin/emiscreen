package com.icleyvin.emiscreen

import android.annotation.SuppressLint
import android.app.AlertDialog
import android.content.Context
import android.net.http.SslError
import android.os.Bundle
import android.view.KeyEvent
import android.view.View
import android.webkit.*
import android.widget.EditText
import android.widget.FrameLayout
import androidx.appcompat.app.AppCompatActivity

class MainActivity : AppCompatActivity() {

    private lateinit var webView: WebView
    private val prefsName = "emiscreen_prefs"
    private val prefIp = "server_ip"

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Fullscreen immersive
        window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                or View.SYSTEM_UI_FLAG_FULLSCREEN
                or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
        )

        // WebView fills the screen
        webView = WebView(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        }
        setContentView(webView)

        // WebView settings
        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            mediaPlaybackRequiresUserGesture = false
            cacheMode = WebSettings.LOAD_DEFAULT
            useWideViewPort = true
            loadWithOverviewMode = true
        }

        webView.webViewClient = object : WebViewClient() {
            override fun onReceivedSslError(
                view: WebView?,
                handler: SslErrorHandler?,
                error: SslError?
            ) {
                // Trust self-signed certificate automatically
                handler?.proceed()
            }

            override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
                return false
            }
        }

        webView.webChromeClient = WebChromeClient()

        // Load server URL or ask for it
        val ip = getSavedIp()
        if (ip.isNullOrBlank()) {
            showIpDialog()
        } else {
            loadServer(ip)
        }
    }

    private fun getSavedIp(): String? {
        return getSharedPreferences(prefsName, Context.MODE_PRIVATE).getString(prefIp, null)
    }

    private fun saveIp(ip: String) {
        getSharedPreferences(prefsName, Context.MODE_PRIVATE)
            .edit()
            .putString(prefIp, ip)
            .apply()
    }

    private fun loadServer(ip: String) {
        val url = "https://$ip:8445"
        webView.loadUrl(url)
    }

    private fun showIpDialog() {
        val input = EditText(this).apply {
            hint = "192.168.1.100"
            setText(getSavedIp() ?: "")
        }
        AlertDialog.Builder(this)
            .setTitle("Emiscreen Server")
            .setMessage("Enter your PC's IP address:")
            .setView(input)
            .setCancelable(false)
            .setPositiveButton("Connect") { _, _ ->
                val ip = input.text.toString().trim()
                if (ip.isNotEmpty()) {
                    saveIp(ip)
                    loadServer(ip)
                } else {
                    showIpDialog()
                }
            }
            .show()
    }

    // Inject key events into the WebView so viewer.js receives them
    private fun injectKeyEvent(type: String, key: String, code: String, keyCode: Int) {
        val js = """
            (function(){
                var ev = new KeyboardEvent('$type', {
                    key: '$key',
                    code: '$code',
                    keyCode: $keyCode,
                    which: $keyCode,
                    bubbles: true,
                    cancelable: true
                });
                document.dispatchEvent(ev);
            })();
        """.trimIndent()
        runOnUiThread {
            webView.evaluateJavascript(js, null)
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent?): Boolean {
        if (event == null) return super.dispatchKeyEvent(event)

        // Fire TV remote keys → inject to WebView JS
        when (event.keyCode) {
            KeyEvent.KEYCODE_DPAD_UP -> {
                if (event.action == KeyEvent.ACTION_DOWN) {
                    injectKeyEvent("keydown", "ArrowUp", "ArrowUp", 38)
                } else {
                    injectKeyEvent("keyup", "ArrowUp", "ArrowUp", 38)
                }
                return true
            }
            KeyEvent.KEYCODE_DPAD_DOWN -> {
                if (event.action == KeyEvent.ACTION_DOWN) {
                    injectKeyEvent("keydown", "ArrowDown", "ArrowDown", 40)
                } else {
                    injectKeyEvent("keyup", "ArrowDown", "ArrowDown", 40)
                }
                return true
            }
            KeyEvent.KEYCODE_DPAD_LEFT -> {
                if (event.action == KeyEvent.ACTION_DOWN) {
                    injectKeyEvent("keydown", "ArrowLeft", "ArrowLeft", 37)
                } else {
                    injectKeyEvent("keyup", "ArrowLeft", "ArrowLeft", 37)
                }
                return true
            }
            KeyEvent.KEYCODE_DPAD_RIGHT -> {
                if (event.action == KeyEvent.ACTION_DOWN) {
                    injectKeyEvent("keydown", "ArrowRight", "ArrowRight", 39)
                } else {
                    injectKeyEvent("keyup", "ArrowRight", "ArrowRight", 39)
                }
                return true
            }
            KeyEvent.KEYCODE_DPAD_CENTER,
            KeyEvent.KEYCODE_ENTER -> {
                if (event.action == KeyEvent.ACTION_DOWN) {
                    injectKeyEvent("keydown", "Enter", "Enter", 13)
                } else {
                    injectKeyEvent("keyup", "Enter", "Enter", 13)
                }
                return true
            }
            KeyEvent.KEYCODE_BACK -> {
                if (event.action == KeyEvent.ACTION_DOWN) {
                    injectKeyEvent("keydown", "Escape", "Escape", 27)
                } else {
                    injectKeyEvent("keyup", "Escape", "Escape", 27)
                }
                // Allow WebView back navigation if possible, otherwise consume
                if (webView.canGoBack()) {
                    webView.goBack()
                }
                return true
            }
            KeyEvent.KEYCODE_MENU -> {
                if (event.action == KeyEvent.ACTION_DOWN) {
                    showIpDialog()
                }
                return true
            }
        }

        // Pass-through other keys (volume, etc.)
        return super.dispatchKeyEvent(event)
    }

    override fun onResume() {
        super.onResume()
        window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                or View.SYSTEM_UI_FLAG_FULLSCREEN
                or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
        )
    }

    override fun onDestroy() {
        webView.destroy()
        super.onDestroy()
    }
}

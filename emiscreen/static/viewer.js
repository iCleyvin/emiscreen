/**
 * Emiscreen Viewer - WebRTC Client for FireTV / Browser
 *
 * Sprint 1: Auto-reconnect, Status overlay, Error handling, Bitrate adaptation
 */
(function () {
    'use strict';

    // ========== DOM Elements ==========
    const video = document.getElementById('remote-video');
    const statusOverlay = document.getElementById('status-overlay');
    const statusText = document.getElementById('status-text');
    const statusSubtext = document.getElementById('status-subtext');
    const errorOverlay = document.getElementById('error-overlay');
    const errorIcon = document.getElementById('error-icon');
    const errorTitle = document.getElementById('error-title');
    const errorMessage = document.getElementById('error-message');
    const errorRetry = document.getElementById('error-retry');
    const reconnectBtn = document.getElementById('reconnect-btn');
    const reconnectNowBtn = document.getElementById('reconnect-now-btn');
    const sslOverlay = document.getElementById('ssl-overlay');
    const sslRetryBtn = document.getElementById('ssl-retry-btn');
    const statsOverlay = document.getElementById('stats-overlay');
    const statStatus = document.getElementById('stat-status');
    const statBitrate = document.getElementById('stat-bitrate');
    const statPing = document.getElementById('stat-ping');
    const statResolution = document.getElementById('stat-resolution');
    const statFps = document.getElementById('stat-fps');
    const toast = document.getElementById('toast');
    const controlsHint = document.getElementById('controls-hint');

    // ========== State ==========
    let peerConnection = null;
    let ws = null;
    let connected = false;
    let reconnectAttempts = 0;
    let reconnectTimer = null;
    let reconnectCountdownTimer = null;
    let statsInterval = null;
    let frameCount = 0;
    let lastStatsTime = Date.now();
    let pingInterval = null;
    let lastPongTime = Date.now();
    let isSslError = false;
    let currentBitrate = '8M';
    let statsVisible = false;
    let videoPlaying = false;

    // ========== Config ==========
    const IS_FIRETV_APP = navigator.userAgent.includes('wv') || navigator.userAgent.includes('WebView');
    const RECONNECT_BASE_DELAY = 1000;
    const RECONNECT_MAX_DELAY = 30000;
    const MAX_RECONNECT_ATTEMPTS = 5;
    const STATS_INTERVAL_MS = 2000;
    const PING_INTERVAL_MS = 2000;
    const PONG_TIMEOUT_MS = 8000;
    const DPAD_STEP = 20;

    // ========== Error Messages (Spanish) ==========
    const ERROR_MESSAGES = {
        SERVER_TIMEOUT: {
            icon: '🌐',
            title: 'Servidor no responde',
            message: 'No se pudo conectar al servidor. Verifica la IP y que el servidor esté corriendo.',
        },
        CERT_INVALID: {
            icon: '🔒',
            title: 'Error de certificado',
            message: 'El certificado SSL no es válido. Usa la app nativa o confía el certificado en tu navegador.',
        },
        NETWORK_LOST: {
            icon: '📡',
            title: 'Conexión perdida',
            message: 'Conexión de red perdida. Revisa que tu WiFi esté activo.',
        },
        SERVER_CLOSED: {
            icon: '🔌',
            title: 'Servidor desconectado',
            message: 'El servidor cerró la conexión. Reiniciando...',
        },
        WEBRTC_FAILED: {
            icon: '⚠️',
            title: 'Error de transmisión',
            message: 'No se pudo establecer la transmisión de video. Intenta reiniciar la app.',
        },
        UNKNOWN: {
            icon: '❌',
            title: 'Error desconocido',
            message: 'Ocurrió un error inesperado. Intenta de nuevo.',
        },
    };

    // ========== Key Map ==========
    const KEY_MAP = {
        // Legacy keyCodes
        38: 'dpad_up', 40: 'dpad_down', 37: 'dpad_left', 39: 'dpad_right',
        13: 'dpad_center', 27: 'back', 8: 'backspace', 46: 'delete',
        32: 'space', 9: 'tab', 36: 'home', 35: 'end',
        33: 'page_up', 34: 'page_down',
        179: 'play_pause', 177: 'prev', 176: 'next',
        174: 'volume_down', 175: 'volume_up', 173: 'mute',
        // Android / Fire TV keyCodes
        19: 'dpad_up', 20: 'dpad_down', 21: 'dpad_left', 22: 'dpad_right',
        23: 'dpad_center', 4: 'back', 82: 'menu',
        // e.code / e.key strings
        'arrowup': 'dpad_up', 'arrowdown': 'dpad_down', 'arrowleft': 'dpad_left', 'arrowright': 'dpad_right',
        'enter': 'dpad_center', 'escape': 'back', 'backspace': 'backspace', 'delete': 'delete',
        'space': 'space', 'tab': 'tab', 'home': 'home', 'end': 'end',
        'pageup': 'page_up', 'pagedown': 'page_down',
        'playpause': 'play_pause', 'mediaplaypause': 'play_pause',
        'mediatrackprevious': 'prev', 'mediatracknext': 'next',
        'volumedown': 'volume_down', 'volumeup': 'volume_up', 'volumemute': 'mute',
    };

    function normalizeKey(e) {
        if (e.code) {
            const m = KEY_MAP[e.code.toLowerCase()];
            if (m) return m;
        }
        if (e.key) {
            const m = KEY_MAP[e.key.toLowerCase()];
            if (m) return m;
        }
        if (e.keyCode) {
            const m = KEY_MAP[e.keyCode];
            if (m) return m;
        }
        if (e.key && e.key.length === 1) return e.key;
        return null;
    }

    // ========== Init ==========
    function init() {
        setupEventListeners();
        showControlsHint();
        connect();
    }

    function setupEventListeners() {
        reconnectBtn.addEventListener('click', () => {
            reconnectAttempts = 0;
            connect();
        });
        reconnectNowBtn.addEventListener('click', () => {
            clearTimeout(reconnectTimer);
            reconnectTimer = null;
            connect();
        });
        sslRetryBtn.addEventListener('click', () => {
            hideSsl();
            reconnectAttempts = 0;
            connect();
        });

        document.addEventListener('keydown', handleKeyDown, true);
        document.addEventListener('keyup', handleKeyUp, true);
        document.addEventListener('mousemove', handleMouseMove);
        document.addEventListener('mousedown', handleMouseDown);
        document.addEventListener('mouseup', handleMouseUp);
        document.addEventListener('wheel', handleWheel, { passive: false });
        document.addEventListener('touchstart', handleTouchStart, { passive: false });
        document.addEventListener('touchmove', handleTouchMove, { passive: false });
        document.addEventListener('touchend', handleTouchEnd);

        video.addEventListener('playing', onVideoPlaying);
        video.addEventListener('waiting', onVideoWaiting);
        video.addEventListener('error', onVideoError);

        document.addEventListener('visibilitychange', () => {
            if (!document.hidden && !connected && !isSslError) {
                scheduleReconnect(1000);
            }
        });

        window.addEventListener('online', () => {
            showToast('Conexión de red restaurada', 'success');
            if (!connected) scheduleReconnect(1000);
        });
        window.addEventListener('offline', () => {
            showToast('Conexión de red perdida', 'error');
            if (connected && peerConnection) {
                peerConnection.close();
            }
        });
    }

    function showControlsHint() {
        controlsHint.classList.remove('hidden');
        setTimeout(() => controlsHint.classList.add('hidden'), 10000);
    }

    // ========== WebRTC ==========
    async function connect() {
        if (connected) return;
        cleanupConnection();
        showStatus('Conectando...');
        hideError();
        hideSsl();
        isSslError = false;

        try {
            peerConnection = new RTCPeerConnection({
                iceServers: [
                    { urls: 'stun:stun.l.google.com:19302' },
                    { urls: 'stun:stun1.l.google.com:19302' },
                ],
            });

            peerConnection.addEventListener('track', (event) => {
                if (event.track.kind === 'video') {
                    video.srcObject = event.streams[0];
                    try {
                        const receiver = event.receiver;
                        const params = receiver.getParameters();
                        if (params.degradationPreference !== undefined) {
                            params.degradationPreference = 'maintain-framerate';
                            receiver.setParameters(params).catch(() => {});
                        }
                    } catch (e) {}
                }
            });

            peerConnection.onconnectionstatechange = () => {
                const state = peerConnection.connectionState;
                updateStatStatus(state);
                if (state === 'connected') {
                    onConnected();
                } else if (state === 'disconnected' || state === 'failed' || state === 'closed') {
                    onDisconnected(state);
                }
            };

            peerConnection.oniceconnectionstatechange = () => {
                if (peerConnection.iceConnectionState === 'failed') {
                    onDisconnected('failed', 'WEBRTC_FAILED');
                }
            };

            const offer = await peerConnection.createOffer({
                offerToReceiveVideo: true,
                offerToReceiveAudio: false,
            });
            await peerConnection.setLocalDescription(offer);

            const response = await fetch('/offer', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ sdp: offer.sdp }),
            });

            if (!response.ok) {
                throw new Error(`Server error: ${response.status}`);
            }

            const answer = await response.json();
            await peerConnection.setRemoteDescription(new RTCSessionDescription(answer));
            connectWebSocket();

        } catch (error) {
            console.error('Connection failed:', error);
            handleConnectionError(error);
        }
    }

    function handleConnectionError(error) {
        if (IS_FIRETV_APP) {
            // Fire TV app auto-trusts certs via WebViewClient, so SSL is never the issue
            showStatus('Conectando...');
            scheduleReconnect();
            return;
        }
        if (location.protocol === 'https:' && (error.name === 'TypeError' || error.message.includes('Failed to fetch'))) {
            showSsl();
            isSslError = true;
        } else if (error.message.includes('NetworkError') || error.message.includes('NETWORK') || !navigator.onLine) {
            showError('NETWORK_LOST');
            scheduleReconnect();
        } else if (error.message.includes('timeout') || error.message.includes('408')) {
            showError('SERVER_TIMEOUT');
            scheduleReconnect();
        } else {
            showError('UNKNOWN');
            scheduleReconnect();
        }
    }

    function onConnected() {
        connected = true;
        reconnectAttempts = 0;
        hideStatus();
        document.body.classList.add('viewing');
        startStats();
        startPing();
        tryEnterFullscreen();
        showToast('Conectado', 'success');
        console.log('Emiscreen connected');
    }

    function onDisconnected(state, errorType) {
        if (!connected && !errorType) return;
        connected = false;
        videoPlaying = false;
        document.body.classList.remove('viewing');
        stopStats();
        stopPing();

        if (state === 'failed') {
            showError(errorType || 'WEBRTC_FAILED');
        } else if (state === 'closed') {
            showError('SERVER_CLOSED');
        } else {
            showError('NETWORK_LOST');
        }
        scheduleReconnect();
    }

    function cleanupConnection() {
        stopPing();
        stopStats();
        if (ws) {
            ws.close();
            ws = null;
        }
        if (peerConnection) {
            peerConnection.close();
            peerConnection = null;
        }
        clearTimeout(reconnectTimer);
        reconnectTimer = null;
        clearInterval(reconnectCountdownTimer);
        reconnectCountdownTimer = null;
    }

    function tryEnterFullscreen() {
        const el = document.documentElement;
        if (el.requestFullscreen && !document.fullscreenElement) {
            el.requestFullscreen().catch(() => {});
        }
    }

    // ========== WebSocket Input + Ping/Pong ==========
    function connectWebSocket() {
        const protocol = location.protocol === 'https:' ? 'wss:' : 'ws:';
        const wsUrl = `${protocol}//${location.host}/input`;

        ws = new WebSocket(wsUrl);

        ws.onopen = () => {
            console.log('Input WebSocket connected');
            lastPongTime = Date.now();
        };

        ws.onmessage = (msg) => {
            try {
                const data = JSON.parse(msg.data);
                if (data.type === 'pong') {
                    lastPongTime = Date.now();
                } else if (data.type === 'bitrate') {
                    currentBitrate = data.value;
                }
            } catch (e) {}
        };

        ws.onclose = () => {
            console.log('Input WebSocket closed');
        };

        ws.onerror = (error) => {
            console.error('WebSocket error:', error);
        };
    }

    function sendInput(event) {
        if (ws && ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify(event));
        }
    }

    function startPing() {
        if (pingInterval) clearInterval(pingInterval);
        pingInterval = setInterval(() => {
            if (ws && ws.readyState === WebSocket.OPEN) {
                ws.send(JSON.stringify({ type: 'ping' }));
            }
            if (Date.now() - lastPongTime > PONG_TIMEOUT_MS) {
                console.warn('Ping timeout, forcing reconnect');
                if (peerConnection) {
                    peerConnection.close();
                }
            }
        }, PING_INTERVAL_MS);
    }

    function stopPing() {
        if (pingInterval) {
            clearInterval(pingInterval);
            pingInterval = null;
        }
    }

    // ========== Reconnection (Story 1-1) ==========
    function scheduleReconnect(delay) {
        if (reconnectTimer || isSslError) return;
        if (reconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
            showError('SERVER_TIMEOUT');
            errorRetry.textContent = 'Máximo de intentos alcanzado. Reintenta manualmente.';
            reconnectNowBtn.classList.add('hidden');
            return;
        }

        const actualDelay = delay || Math.min(
            RECONNECT_BASE_DELAY * Math.pow(2, reconnectAttempts),
            RECONNECT_MAX_DELAY
        );
        reconnectAttempts++;

        statusText.textContent = 'Reconectando...';
        statusSubtext.classList.remove('hidden');
        statusSubtext.textContent = `Intento ${reconnectAttempts}/${MAX_RECONNECT_ATTEMPTS} en ${Math.round(actualDelay / 1000)}s`;
        showStatus(statusText.textContent);

        // Countdown
        let remaining = Math.round(actualDelay / 1000);
        clearInterval(reconnectCountdownTimer);
        reconnectCountdownTimer = setInterval(() => {
            remaining--;
            if (remaining <= 0) {
                clearInterval(reconnectCountdownTimer);
                reconnectCountdownTimer = null;
            } else {
                statusSubtext.textContent = `Intento ${reconnectAttempts}/${MAX_RECONNECT_ATTEMPTS} en ${remaining}s`;
            }
        }, 1000);

        reconnectTimer = setTimeout(() => {
            reconnectTimer = null;
            connect();
        }, actualDelay);

        reconnectNowBtn.classList.remove('hidden');
    }

    // ========== Error Handling (Story 1-3) ==========
    function showError(errorType) {
        const error = ERROR_MESSAGES[errorType] || ERROR_MESSAGES.UNKNOWN;
        errorIcon.textContent = error.icon;
        errorTitle.textContent = error.title;
        errorMessage.textContent = error.message;

        if (reconnectAttempts > 0 && reconnectAttempts < MAX_RECONNECT_ATTEMPTS) {
            errorRetry.textContent = `Intento ${reconnectAttempts} de ${MAX_RECONNECT_ATTEMPTS}`;
        } else if (reconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
            errorRetry.textContent = 'Máximo de intentos alcanzado';
        } else {
            errorRetry.textContent = '';
        }

        errorOverlay.classList.remove('hidden');
        hideStatus();
        hideSsl();
    }

    function hideError() {
        errorOverlay.classList.add('hidden');
    }

    function showSsl() {
        sslOverlay.classList.remove('hidden');
        hideStatus();
        hideError();
    }

    function hideSsl() {
        sslOverlay.classList.add('hidden');
    }

    function showStatus(text) {
        statusText.textContent = text;
        statusOverlay.classList.remove('hidden');
    }

    function hideStatus() {
        statusOverlay.classList.add('hidden');
        statusSubtext.classList.add('hidden');
    }

    function showToast(message, type) {
        toast.textContent = message;
        toast.className = `toast ${type}`;
        toast.classList.add('show');
        setTimeout(() => toast.classList.remove('show'), 3000);
    }

    // ========== Stats Overlay (Story 1-2) ==========
    function updateStatStatus(state) {
        const statusMap = {
            'new': { text: 'Nuevo', class: 'status-connecting' },
            'connecting': { text: 'Conectando', class: 'status-connecting' },
            'connected': { text: 'Transmitiendo', class: 'status-streaming' },
            'disconnected': { text: 'Desconectado', class: 'status-reconnecting' },
            'failed': { text: 'Error', class: 'status-error' },
            'closed': { text: 'Cerrado', class: 'status-reconnecting' },
        };
        const s = statusMap[state] || statusMap['new'];
        statStatus.textContent = s.text;
        statStatus.className = `stat-value ${s.class}`;
    }

    function startStats() {
        frameCount = 0;
        lastStatsTime = Date.now();
        videoPlaying = true;

        function countFrame() {
            frameCount++;
            if (videoPlaying) requestAnimationFrame(countFrame);
        }
        requestAnimationFrame(countFrame);

        statsInterval = setInterval(() => {
            const now = Date.now();
            const elapsed = (now - lastStatsTime) / 1000;
            const fps = Math.round(frameCount / elapsed);
            statFps.textContent = `${fps} fps`;

            if (video.readyState >= 2) {
                statResolution.textContent = `${video.videoWidth}x${video.videoHeight}`;
            }

            statBitrate.textContent = currentBitrate;

            if (peerConnection && peerConnection.getStats) {
                peerConnection.getStats().then(stats => {
                    let rtt = null;
                    let jitter = 0;
                    stats.forEach(report => {
                        if (report.type === 'candidate-pair' && report.state === 'succeeded') {
                            rtt = report.currentRoundTripTime;
                        }
                        if (report.type === 'inbound-rtp' && report.kind === 'video') {
                            jitter = report.jitter || 0;
                        }
                    });
                    if (rtt !== null) {
                        statPing.textContent = `${Math.round(rtt * 1000)} ms`;
                    } else {
                        const est = Math.round(jitter * 1000 + 30);
                        statPing.textContent = `~${est} ms`;
                    }
                }).catch(() => {});
            }

            frameCount = 0;
            lastStatsTime = now;
        }, STATS_INTERVAL_MS);

        if (statsVisible) statsOverlay.classList.remove('hidden');
    }

    function stopStats() {
        videoPlaying = false;
        if (statsInterval) {
            clearInterval(statsInterval);
            statsInterval = null;
        }
        statsOverlay.classList.add('hidden');
    }

    function toggleStats() {
        statsVisible = !statsVisible;
        if (statsVisible && connected) {
            statsOverlay.classList.remove('hidden');
        } else {
            statsOverlay.classList.add('hidden');
        }
    }

    // ========== Input Handlers ==========
    function handleKeyDown(e) {
        const keyName = normalizeKey(e);
        if (!keyName) return;

        if (keyName === 'back') {
            e.preventDefault();
        }
        if (keyName === 'menu') {
            e.preventDefault();
            toggleStats();
            return;
        }

        sendInput({ type: 'keydown', key: keyName, code: e.code, keyCode: e.keyCode });

        if (['dpad_up','dpad_down','dpad_left','dpad_right','dpad_center','back','space','tab'].includes(keyName)) {
            e.preventDefault();
        }
    }

    function handleKeyUp(e) {
        const keyName = normalizeKey(e);
        if (!keyName) return;
        if (keyName === 'menu') return;
        sendInput({ type: 'keyup', key: keyName, code: e.code, keyCode: e.keyCode });
    }

    function handleMouseMove(e) {
        sendInput({ type: 'mousemove', x: e.clientX, y: e.clientY, screenX: e.screenX, screenY: e.screenY });
    }

    function handleMouseDown(e) {
        sendInput({ type: 'mousedown', button: e.button, x: e.clientX, y: e.clientY });
    }

    function handleMouseUp(e) {
        sendInput({ type: 'mouseup', button: e.button, x: e.clientX, y: e.clientY });
    }

    function handleWheel(e) {
        sendInput({ type: 'wheel', deltaX: e.deltaX, deltaY: e.deltaY });
        e.preventDefault();
    }

    function handleTouchStart(e) {
        if (e.touches.length === 1) {
            const t = e.touches[0];
            sendInput({ type: 'touchstart', x: t.clientX, y: t.clientY });
        }
        e.preventDefault();
    }

    function handleTouchMove(e) {
        if (e.touches.length === 1) {
            const t = e.touches[0];
            sendInput({ type: 'touchmove', x: t.clientX, y: t.clientY });
        }
        e.preventDefault();
    }

    function handleTouchEnd(e) {
        sendInput({ type: 'touchend' });
    }

    // ========== Video Events ==========
    function onVideoPlaying() {
        video.classList.remove('loading');
        hideStatus();
    }

    function onVideoWaiting() {
        video.classList.add('loading');
    }

    function onVideoError(e) {
        console.error('Video error:', e);
        showToast('Error de reproducción de video', 'error');
    }

    // ========== Start ==========
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();

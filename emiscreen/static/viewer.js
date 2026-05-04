/**
 * Emiscreen Viewer - WebRTC Client for FireTV / Browser
 *
 * Handles:
 * - WebRTC connection with auto-reconnect
 * - Cross-platform input: D-Pad, keyboard, mouse, touch
 * - WebSocket ping/pong for connection health
 * - Stats overlay (FPS, resolution, estimated latency)
 * - Fullscreen & UI overlays
 */
(function () {
    'use strict';

    // DOM Elements
    const video = document.getElementById('remote-video');
    const statusOverlay = document.getElementById('status-overlay');
    const statusText = document.getElementById('status-text');
    const errorOverlay = document.getElementById('error-overlay');
    const errorText = document.getElementById('error-text');
    const reconnectBtn = document.getElementById('reconnect-btn');
    const sslOverlay = document.getElementById('ssl-overlay');
    const sslRetryBtn = document.getElementById('ssl-retry-btn');
    const statsOverlay = document.getElementById('stats-overlay');
    const statsFps = document.getElementById('stats-fps');
    const statsResolution = document.getElementById('stats-resolution');
    const statsLatency = document.getElementById('stats-latency');
    const controlsHint = document.getElementById('controls-hint');

    // State
    let peerConnection = null;
    let ws = null;
    let connected = false;
    let reconnectAttempts = 0;
    let reconnectTimer = null;
    let statsInterval = null;
    let frameCount = 0;
    let lastStatsTime = Date.now();
    let pingInterval = null;
    let lastPongTime = Date.now();
    let isSslError = false;

    // Config
    const RECONNECT_BASE_DELAY = 1000;
    const RECONNECT_MAX_DELAY = 30000;
    const STATS_INTERVAL_MS = 2000;
    const PING_INTERVAL_MS = 5000;
    const PONG_TIMEOUT_MS = 15000;
    const DPAD_STEP = 20;

    // Unified key map: supports e.code (string), e.key (string), e.keyCode (number)
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

    // Initialize
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
        sslRetryBtn.addEventListener('click', () => {
            hideSsl();
            reconnectAttempts = 0;
            connect();
        });

        // Single keydown handler for everything
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
            if (!document.hidden && !connected) {
                connect();
            }
        });
    }

    function showControlsHint() {
        // Only show on first load, hide after 10s
        controlsHint.classList.remove('hidden');
        setTimeout(() => controlsHint.classList.add('hidden'), 10000);
    }

    // ========== WebRTC ==========
    async function connect() {
        if (connected) return;
        showStatus('Connecting...');
        hideError();
        hideSsl();
        isSslError = false;

        try {
            // Create peer connection with low-latency tuning
            peerConnection = new RTCPeerConnection({
                iceServers: [
                    { urls: 'stun:stun.l.google.com:19302' },
                    { urls: 'stun:stun1.l.google.com:19302' },
                ],
            });

            // Set low-latency parameters on the video receiver
            peerConnection.addEventListener('track', (event) => {
                if (event.track.kind === 'video') {
                    video.srcObject = event.streams[0];
                    // Try to minimize playout delay
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
                if (state === 'connected') {
                    onConnected();
                } else if (state === 'disconnected' || state === 'failed' || state === 'closed') {
                    onDisconnected(state);
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
            await peerConnection.setRemoteDescription(
                new RTCSessionDescription(answer)
            );

            connectWebSocket();

        } catch (error) {
            console.error('Connection failed:', error);
            // Detect self-signed cert block
            if (location.protocol === 'https:' && (error.name === 'TypeError' || error.message.includes('Failed to fetch'))) {
                showSsl();
                isSslError = true;
            } else {
                showError(`Connection failed: ${error.message}`);
            }
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
        console.log('Emiscreen connected');
    }

    function onDisconnected(state) {
        if (!connected) return;
        connected = false;
        document.body.classList.remove('viewing');
        stopStats();
        stopPing();
        if (state === 'failed') {
            showError('Connection failed');
        } else {
            showError('Connection lost');
        }
        scheduleReconnect();
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
                }
            } catch (e) {}
        };

        ws.onclose = () => {
            console.log('Input WebSocket closed');
            setTimeout(() => {
                if (connected) connectWebSocket();
            }, 2000);
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
            // If no pong in a while, force reconnect
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

    // ========== Input Handlers ==========
    function handleKeyDown(e) {
        const keyName = normalizeKey(e);
        if (!keyName) return;

        // Back / Escape should not close the app/page
        if (keyName === 'back') {
            e.preventDefault();
        }

        sendInput({ type: 'keydown', key: keyName, code: e.code, keyCode: e.keyCode });

        // Prevent default for navigation keys we consume
        if (['dpad_up','dpad_down','dpad_left','dpad_right','dpad_center','back','space','tab'].includes(keyName)) {
            e.preventDefault();
        }
    }

    function handleKeyUp(e) {
        const keyName = normalizeKey(e);
        if (!keyName) return;
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
        showError('Video playback error');
    }

    // ========== Stats ==========
    function startStats() {
        frameCount = 0;
        lastStatsTime = Date.now();

        function countFrame() {
            frameCount++;
            if (connected) requestAnimationFrame(countFrame);
        }
        requestAnimationFrame(countFrame);

        statsInterval = setInterval(() => {
            const now = Date.now();
            const elapsed = (now - lastStatsTime) / 1000;
            const fps = Math.round(frameCount / elapsed);
            statsFps.textContent = `${fps} fps`;

            if (video.readyState >= 2) {
                statsResolution.textContent = `${video.videoWidth}x${video.videoHeight}`;
            }

            // Estimate latency from getStats (if available)
            if (peerConnection && peerConnection.getStats) {
                peerConnection.getStats().then(stats => {
                    stats.forEach(report => {
                        if (report.type === 'inbound-rtp' && report.kind === 'video') {
                            // jitter + some constant as rough latency estimate
                            const jitter = report.jitter || 0;
                            const est = Math.round(jitter * 1000 + 30);
                            statsLatency.textContent = `~${est} ms`;
                        }
                    });
                }).catch(() => {});
            }

            frameCount = 0;
            lastStatsTime = now;
        }, STATS_INTERVAL_MS);

        statsOverlay.classList.remove('hidden');
    }

    function stopStats() {
        if (statsInterval) {
            clearInterval(statsInterval);
            statsInterval = null;
        }
        statsOverlay.classList.add('hidden');
    }

    // ========== Reconnection ==========
    function scheduleReconnect() {
        if (reconnectTimer || isSslError) return;

        const delay = Math.min(
            RECONNECT_BASE_DELAY * Math.pow(2, reconnectAttempts),
            RECONNECT_MAX_DELAY
        );
        reconnectAttempts++;
        statusText.textContent = `Reconnecting in ${Math.round(delay / 1000)}s...`;
        showStatus(statusText.textContent);

        reconnectTimer = setTimeout(() => {
            reconnectTimer = null;
            connect();
        }, delay);
    }

    // ========== UI Helpers ==========
    function showStatus(text) {
        statusText.textContent = text;
        statusOverlay.classList.remove('hidden');
    }

    function hideStatus() {
        statusOverlay.classList.add('hidden');
    }

    function showError(text) {
        errorText.textContent = text;
        errorOverlay.classList.remove('hidden');
        hideStatus();
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

    // Start
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();

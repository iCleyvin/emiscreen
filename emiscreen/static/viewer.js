/**
 * Emiscreen Viewer - WebRTC Client for FireTV Browser
 *
 * Handles:
 * - WebRTC connection to Emiscreen server
 * - Video stream playback
 * - Input capture (D-Pad, keyboard, mouse)
 * - Auto-reconnection with exponential backoff
 * - Stats overlay (FPS, latency, resolution)
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
    const statsOverlay = document.getElementById('stats-overlay');
    const statsFps = document.getElementById('stats-fps');
    const statsLatency = document.getElementById('stats-latency');
    const statsResolution = document.getElementById('stats-resolution');

    // State
    let peerConnection = null;
    let ws = null;
    let connected = false;
    let reconnectAttempts = 0;
    let reconnectTimer = null;
    let statsInterval = null;
    let frameCount = 0;
    let lastFrameTime = 0;
    let currentFps = 0;
    let lastStatsTime = Date.now();

    // Configuration
    const RECONNECT_BASE_DELAY = 1000;
    const RECONNECT_MAX_DELAY = 30000;
    const STATS_INTERVAL = 2000;
    const DPAD_STEP = 20;

    // FireTV D-Pad key code mapping
    const KEY_MAP = {
        38: 'dpad_up',       // Arrow Up
        40: 'dpad_down',     // Arrow Down
        37: 'dpad_left',     // Arrow Left
        39: 'dpad_right',    // Arrow Right
        13: 'dpad_center',   // Enter/Select
        27: 'back',          // Escape/Back
        179: 'play_pause',   // Play/Pause (FireTV remote)
        177: 'next',         // Next
        176: 'prev',         // Previous
        174: 'volume_down',  // Volume Down
        175: 'volume_up',    // Volume Up
        173: 'mute',         // Mute
        32: 'space',         // Space
        9: 'tab',            // Tab
        8: 'backspace',      // Backspace
        46: 'delete',        // Delete
        36: 'home',          // Home
        35: 'end',           // End
        33: 'page_up',       // Page Up
        34: 'page_down',     // Page Down
    };

    // Initialize
    function init() {
        setupEventListeners();
        connect();
    }

    function setupEventListeners() {
        // Reconnect button
        reconnectBtn.addEventListener('click', () => {
            reconnectAttempts = 0;
            connect();
        });

        // Keyboard input (FireTV remote sends key events)
        document.addEventListener('keydown', handleKeyDown);
        document.addEventListener('keyup', handleKeyUp);

        // Mouse input (for devices with mouse support)
        document.addEventListener('mousemove', handleMouseMove);
        document.addEventListener('mousedown', handleMouseDown);
        document.addEventListener('mouseup', handleMouseUp);
        document.addEventListener('wheel', handleWheel);

        // Touch input
        document.addEventListener('touchstart', handleTouchStart, { passive: false });
        document.addEventListener('touchmove', handleTouchMove, { passive: false });
        document.addEventListener('touchend', handleTouchEnd);

        // Video events
        video.addEventListener('playing', onVideoPlaying);
        video.addEventListener('waiting', onVideoWaiting);
        video.addEventListener('error', onVideoError);

        // Visibility change - reconnect when page becomes visible
        document.addEventListener('visibilitychange', () => {
            if (!document.hidden && !connected) {
                connect();
            }
        });

        // Prevent default FireTV behaviors that interfere
        document.addEventListener('keydown', (e) => {
            // Prevent back button from closing the app
            if (e.keyCode === 27 || e.keyCode === 4) {
                e.preventDefault();
                sendInput({ type: 'key', key: 'back' });
            }
        }, true);
    }

    // WebRTC Connection
    async function connect() {
        if (connected) return;

        showStatus('Connecting...');
        hideError();

        try {
            // Create peer connection
            peerConnection = new RTCPeerConnection({
                iceServers: [
                    { urls: 'stun:stun.l.google.com:19302' },
                    { urls: 'stun:stun1.l.google.com:19302' },
                ],
            });

            // Handle incoming video track
            peerConnection.ontrack = (event) => {
                if (event.track.kind === 'video') {
                    video.srcObject = event.streams[0];
                }
            };

            // Handle connection state changes
            peerConnection.onconnectionstatechange = () => {
                const state = peerConnection.connectionState;
                console.log('WebRTC state:', state);

                if (state === 'connected') {
                    onConnected();
                } else if (state === 'disconnected' || state === 'failed' || state === 'closed') {
                    onDisconnected(state);
                }
            };

            // Handle ICE connection state
            peerConnection.oniceconnectionstatechange = () => {
                console.log('ICE state:', peerConnection.iceConnectionState);
            };

            // Create offer
            const offer = await peerConnection.createOffer({
                offerToReceiveVideo: true,
                offerToReceiveAudio: false,
            });
            await peerConnection.setLocalDescription(offer);

            // Send offer to server
            const response = await fetch('/offer', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ sdp: offer.sdp }),
            });

            if (!response.ok) {
                throw new Error(`Server error: ${response.status}`);
            }

            const answer = await response.json();

            // Set remote description
            await peerConnection.setRemoteDescription(
                new RTCSessionDescription(answer)
            );

            // Connect WebSocket for input
            connectWebSocket();

        } catch (error) {
            console.error('Connection failed:', error);
            showError(`Connection failed: ${error.message}`);
            scheduleReconnect();
        }
    }

    function onConnected() {
        connected = true;
        reconnectAttempts = 0;
        hideStatus();
        document.body.classList.add('viewing');
        startStats();
        console.log('Emiscreen connected');
    }

    function onDisconnected(state) {
        if (!connected) return;
        connected = false;
        document.body.classList.remove('viewing');
        stopStats();

        if (state === 'failed') {
            showError('Connection failed');
        } else {
            showError('Connection lost');
        }

        scheduleReconnect();
    }

    // WebSocket Input Relay
    function connectWebSocket() {
        const protocol = location.protocol === 'https:' ? 'wss:' : 'ws:';
        const wsUrl = `${protocol}//${location.host}/input`;

        try {
            ws = new WebSocket(wsUrl);

            ws.onopen = () => {
                console.log('Input WebSocket connected');
            };

            ws.onclose = () => {
                console.log('Input WebSocket closed');
                // Don't trigger full reconnect, just try to reconnect WS
                setTimeout(() => {
                    if (connected) connectWebSocket();
                }, 2000);
            };

            ws.onerror = (error) => {
                console.error('WebSocket error:', error);
            };
        } catch (error) {
            console.error('Failed to create WebSocket:', error);
        }
    }

    function sendInput(event) {
        if (ws && ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify(event));
        }
    }

    // Input Handlers
    function handleKeyDown(e) {
        const keyName = KEY_MAP[e.keyCode] || e.key;
        sendInput({ type: 'keydown', key: keyName, keyCode: e.keyCode });

        // Prevent default for navigation keys (we handle them)
        if (KEY_MAP[e.keyCode]) {
            e.preventDefault();
        }
    }

    function handleKeyUp(e) {
        const keyName = KEY_MAP[e.keyCode] || e.key;
        sendInput({ type: 'keyup', key: keyName, keyCode: e.keyCode });
    }

    function handleMouseMove(e) {
        sendInput({
            type: 'mousemove',
            x: e.clientX,
            y: e.clientY,
            screenX: e.screenX,
            screenY: e.screenY,
        });
    }

    function handleMouseDown(e) {
        sendInput({
            type: 'mousedown',
            button: e.button,
            x: e.clientX,
            y: e.clientY,
        });
    }

    function handleMouseUp(e) {
        sendInput({
            type: 'mouseup',
            button: e.button,
            x: e.clientX,
            y: e.clientY,
        });
    }

    function handleWheel(e) {
        sendInput({
            type: 'wheel',
            deltaX: e.deltaX,
            deltaY: e.deltaY,
        });
        e.preventDefault();
    }

    function handleTouchStart(e) {
        if (e.touches.length === 1) {
            const touch = e.touches[0];
            sendInput({
                type: 'touchstart',
                x: touch.clientX,
                y: touch.clientY,
            });
        }
        e.preventDefault();
    }

    function handleTouchMove(e) {
        if (e.touches.length === 1) {
            const touch = e.touches[0];
            sendInput({
                type: 'touchmove',
                x: touch.clientX,
                y: touch.clientY,
            });
        }
        e.preventDefault();
    }

    function handleTouchEnd(e) {
        sendInput({ type: 'touchend' });
    }

    // Video Event Handlers
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

    // Stats
    function startStats() {
        frameCount = 0;
        lastFrameTime = 0;
        lastStatsTime = Date.now();

        // Count frames via requestAnimationFrame
        function countFrame() {
            frameCount++;
            if (connected) {
                requestAnimationFrame(countFrame);
            }
        }
        requestAnimationFrame(countFrame);

        // Update stats display
        statsInterval = setInterval(() => {
            const now = Date.now();
            const elapsed = (now - lastStatsTime) / 1000;
            currentFps = Math.round(frameCount / elapsed);

            statsFps.textContent = `${currentFps} fps`;

            // Estimate latency from video element
            if (video.readyState >= 2) {
                statsResolution.textContent = `${video.videoWidth}x${video.videoHeight}`;
            }

            frameCount = 0;
            lastStatsTime = now;
        }, STATS_INTERVAL);

        statsOverlay.classList.remove('hidden');
    }

    function stopStats() {
        if (statsInterval) {
            clearInterval(statsInterval);
            statsInterval = null;
        }
        statsOverlay.classList.add('hidden');
    }

    // Reconnection
    function scheduleReconnect() {
        if (reconnectTimer) return;

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

    // UI Helpers
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

    // Start
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();

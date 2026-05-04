"""
Emiscreen WebRTC Module

Handles WebRTC peer connections, SDP offer/answer exchange,
ICE candidate management, video stream track creation, and
network quality monitoring for bitrate adaptation.
"""

import asyncio
import json
import logging
from typing import Optional, Dict, Any

from aiortc import RTCPeerConnection, RTCSessionDescription, VideoStreamTrack
from aiortc.contrib.media import MediaRelay

from emiscreen.capture.base import CaptureSource
from emiscreen.config import CaptureConfig

logger = logging.getLogger(__name__)


class EmiscreenWebRTC:
    """Manages WebRTC peer connections for screen streaming."""

    def __init__(self, capture_config: CaptureConfig):
        self.capture_config = capture_config
        self._capture: Optional[CaptureSource] = None
        self._relay = MediaRelay()
        self._peers: dict[str, RTCPeerConnection] = {}
        self._running = False

    async def start(self):
        """Initialize the capture source and start streaming."""
        self._capture = CaptureSource.create(self.capture_config)
        await self._capture.start()
        self._running = True
        logger.info(f"WebRTC initialized with {self.capture_config.codec} codec")

    async def stop(self):
        """Stop all peer connections and capture."""
        self._running = False
        for pc in list(self._peers.values()):
            await pc.close()
        self._peers.clear()
        if self._capture:
            await self._capture.stop()
        logger.info("WebRTC stopped")

    async def handle_offer(self, sdp_offer: str) -> str:
        """
        Handle an SDP offer from a client.
        Creates a new peer connection, adds the video track, and returns the answer.
        """
        offer = RTCSessionDescription(sdp=sdp_offer, type="offer")

        # Create peer connection
        pc = RTCPeerConnection()
        peer_id = str(id(pc))

        @pc.on("connectionstatechange")
        async def on_connection_state_change():
            logger.info(f"Peer {peer_id} connection state: {pc.connectionState}")
            if pc.connectionState in ("failed", "closed"):
                await pc.close()
                self._peers.pop(peer_id, None)

        @pc.on("icecandidate")
        async def on_ice_candidate(candidate):
            if candidate:
                logger.debug(f"Peer {peer_id} ICE candidate: {candidate}")

        # Add video track
        video_track = self._relay.subscribe(self._capture.video_track)
        pc.addTrack(video_track)

        # Add audio track if available (Story 1-7)
        if self._capture._audio_track:
            audio_track = self._relay.subscribe(self._capture._audio_track)
            pc.addTrack(audio_track)
            logger.info(f"Audio track added for peer {peer_id}")

        # Set remote description (offer)
        await pc.setRemoteDescription(offer)

        # Create answer
        answer = await pc.createAnswer()
        await pc.setLocalDescription(answer)

        self._peers[peer_id] = pc
        logger.info(f"Peer {peer_id} connected, sending answer")

        return pc.localDescription.sdp, pc.localDescription.type

    def is_connected(self) -> bool:
        """Check if any peer is connected."""
        return any(
            pc.connectionState == "connected"
            for pc in self._peers.values()
        )

    def peer_count(self) -> int:
        """Return the number of active peer connections."""
        return len(self._peers)

    async def get_network_stats(self) -> Dict[str, Any]:
        """
        Read network quality stats from all connected peers.
        Returns: {rtt_ms, packet_loss_percent, jitter_ms, bitrate_estimate}
        """
        stats_agg = {
            "rtt_ms": None,
            "packet_loss_percent": 0.0,
            "jitter_ms": 0.0,
            "bitrate_kbps": None,
        }

        for peer_id, pc in self._peers.items():
            if pc.connectionState != "connected":
                continue
            try:
                stats = await pc.getStats()
                for report in stats.values():
                    if report.type == "candidate-pair" and getattr(report, "state", None) == "succeeded":
                        if hasattr(report, "currentRoundTripTime"):
                            stats_agg["rtt_ms"] = report.currentRoundTripTime * 1000
                    if report.type == "inbound-rtp":
                        if hasattr(report, "packetsLost") and hasattr(report, "packetsReceived"):
                            total = report.packetsLost + report.packetsReceived
                            if total > 0:
                                stats_agg["packet_loss_percent"] = (report.packetsLost / total) * 100
                        if hasattr(report, "jitter"):
                            stats_agg["jitter_ms"] = report.jitter * 1000
                        if hasattr(report, "bytesReceived"):
                            # Rough bitrate estimate (needs delta calculation for accuracy)
                            stats_agg["bitrate_kbps"] = getattr(report, "bitrateMean", 0) / 1000
            except Exception as e:
                logger.debug(f"Failed to get stats for peer {peer_id}: {e}")

        return stats_agg

    async def change_bitrate(self, new_bitrate: str):
        """Change capture bitrate dynamically."""
        if self._capture:
            await self._capture.change_bitrate(new_bitrate)

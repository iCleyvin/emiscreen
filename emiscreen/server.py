"""
Emiscreen - Main Server

aiohttp-based HTTPS server that handles:
- Static file serving (viewer.html, viewer.js, viewer.css)
- WebRTC signaling (POST /offer, GET /answer)
- WebSocket input relay (/input)
- Health check endpoint
"""

import argparse
import asyncio
import json
import logging
import os
import pathlib
import ssl
import sys
from typing import Optional

import aiohttp
from aiohttp import web

from emiscreen.config import (
    ADBConfig,
    CaptureConfig,
    RelayConfig,
    ServerConfig,
    SOURCES,
    get_source,
    load_from_env,
)
from emiscreen.relay.adb import ADBController
from emiscreen.relay.input import InputRelay
from emiscreen.webrtc import EmiscreenWebRTC

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("emiscreen.server")


class EmiscreenServer:
    """Main Emiscreen application server."""

    def __init__(
        self,
        server_config: ServerConfig,
        capture_config: CaptureConfig,
        adb_config: ADBConfig,
        relay_config: RelayConfig,
    ):
        self.server_config = server_config
        self.capture_config = capture_config
        self.adb_config = adb_config
        self.relay_config = relay_config

        self.app = web.Application()
        self.webrtc: Optional[EmiscreenWebRTC] = None
        self.adb: Optional[ADBController] = None
        self.input_relay: Optional[InputRelay] = None
        self._runner: Optional[web.AppRunner] = None

        self._setup_routes()

    def _setup_routes(self):
        """Configure HTTP routes."""
        # Static files
        static_dir = pathlib.Path(__file__).parent / "static"
        self.app.router.add_static("/static/", path=static_dir, name="static")

        # Main page
        self.app.router.add_get("/", self._handle_index)

        # WebRTC signaling
        self.app.router.add_post("/offer", self._handle_offer)

        # WebSocket input relay
        self.app.router.add_get("/input", self._handle_input_ws)

        # Health check
        self.app.router.add_get("/health", self._handle_health)

        # Status
        self.app.router.add_get("/status", self._handle_status)

    async def _handle_index(self, request: web.Request) -> web.Response:
        """Serve the main viewer page."""
        viewer_path = pathlib.Path(__file__).parent / "static" / "viewer.html"
        if not viewer_path.exists():
            return web.Response(text="viewer.html not found", status=500)
        return web.FileResponse(viewer_path)

    async def _handle_offer(self, request: web.Request) -> web.Response:
        """Handle WebRTC SDP offer from client."""
        if not self.webrtc:
            return web.json_response({"error": "WebRTC not initialized"}, status=503)

        try:
            body = await request.json()
            sdp_offer = body.get("sdp")
            if not sdp_offer:
                return web.json_response({"error": "Missing SDP offer"}, status=400)

            answer = await self.webrtc.handle_offer(sdp_offer)
            return web.json_response({"sdp": answer, "type": "answer"})
        except Exception as e:
            logger.error(f"Offer handling failed: {e}")
            return web.json_response({"error": str(e)}, status=500)

    async def _handle_input_ws(self, request: web.Request) -> web.StreamResponse:
        """WebSocket endpoint for input relay."""
        if not self.input_relay:
            return web.Response(text="Input relay not initialized", status=503)

        ws = web.WebSocketResponse()
        await ws.prepare(request)

        client_id = id(ws)
        logger.info(f"Input client connected: {client_id}")
        self.input_relay.add_client(client_id, ws)

        try:
            async for msg in ws:
                if msg.type == aiohttp.WSMsgType.TEXT:
                    try:
                        event = json.loads(msg.data)
                        await self.input_relay.process_event(client_id, event)
                    except json.JSONDecodeError:
                        logger.warning(f"Invalid JSON from client {client_id}")
                elif msg.type == aiohttp.WSMsgType.ERROR:
                    logger.error(f"WebSocket error: {ws.exception()}")
        except asyncio.CancelledError:
            pass
        finally:
            self.input_relay.remove_client(client_id)
            logger.info(f"Input client disconnected: {client_id}")

        return ws

    async def _handle_health(self, request: web.Request) -> web.Response:
        """Health check endpoint."""
        status = {
            "status": "healthy",
            "webrtc": self.webrtc is not None,
            "adb": self.adb_config.enabled,
            "relay": self.relay_config.enabled,
        }
        return web.json_response(status)

    async def _handle_status(self, request: web.Request) -> web.Response:
        """Detailed status endpoint."""
        status = {
            "server": {
                "host": self.server_config.host,
                "port": self.server_config.port,
                "uptime": "running",
            },
            "capture": {
                "type": self.capture_config.type,
                "resolution": self.capture_config.resolution,
                "fps": self.capture_config.fps,
                "codec": self.capture_config.codec,
            },
            "webrtc": {
                "connected": self.webrtc.is_connected() if self.webrtc else False,
                "peers": self.webrtc.peer_count() if self.webrtc else 0,
            },
            "adb": {
                "enabled": self.adb_config.enabled,
                "connected": await self.adb.is_connected() if self.adb else False,
                "host": self.adb_config.host,
            }
            if self.adb_config.enabled
            else {"enabled": False},
        }
        return web.json_response(status)

    async def start(self):
        """Start the Emiscreen server."""
        load_from_env()

        logger.info("=" * 60)
        logger.info("  Emiscreen - Remote Display via WebRTC")
        logger.info("=" * 60)
        logger.info(f"  Capture: {self.capture_config.type} @ {self.capture_config.resolution} {self.capture_config.fps}fps")
        logger.info(f"  Server:  https://{self.server_config.host}:{self.server_config.port}")
        logger.info(f"  Codec:   {self.capture_config.codec}")
        logger.info("=" * 60)

        # Initialize WebRTC
        self.webrtc = EmiscreenWebRTC(self.capture_config)
        await self.webrtc.start()

        # Initialize ADB if enabled
        if self.adb_config.enabled and self.adb_config.host:
            self.adb = ADBController(
                host=self.adb_config.host,
                port=self.adb_config.port,
            )
            if await self.adb.connect():
                await self.adb.wake()
                # Auto-launch browser after a delay
                asyncio.create_task(self._auto_launch_browser())
                await self.adb.start_auto_reconnect()
            else:
                logger.warning("ADB connection failed, continuing without FireTV control")

        # Initialize input relay
        if self.relay_config.enabled:
            self.input_relay = InputRelay(
                adb=self.adb,
                xdotool_path=self.relay_config.xdotool_path,
                dpad_step=self.relay_config.dpad_step,
            )
            await self.input_relay.start()

        # Start HTTP server with SSL
        ssl_context = self._create_ssl_context()

        self._runner = web.AppRunner(self.app)
        await self._runner.setup()

        site = web.TCPSite(
            self._runner,
            self.server_config.host,
            self.server_config.port,
            ssl_context=ssl_context,
        )
        await site.start()

        logger.info(f"Server running at https://{self.server_config.host}:{self.server_config.port}")
        logger.info(f"FireTV URL: https://{self._get_local_ip()}:{self.server_config.port}")

        # Keep running
        try:
            while True:
                await asyncio.sleep(3600)
        except asyncio.CancelledError:
            pass
        finally:
            await self.stop()

    async def stop(self):
        """Stop the Emiscreen server."""
        logger.info("Shutting down Emiscreen...")

        if self.adb:
            await self.adb.stop_auto_reconnect()
            await self.adb.disconnect()

        if self.webrtc:
            await self.webrtc.stop()

        if self._runner:
            await self._runner.cleanup()

        logger.info("Emiscreen stopped.")

    def _create_ssl_context(self) -> ssl.SSLContext:
        """Create SSL context from certificate files."""
        cert_path = pathlib.Path(self.server_config.ssl_cert)
        key_path = pathlib.Path(self.server_config.ssl_key)

        if not cert_path.exists() or not key_path.exists():
            logger.warning("SSL certificates not found. Generating self-signed certs...")
            self._generate_certs()

        ssl_context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        ssl_context.load_cert_chain(str(cert_path), str(key_path))
        return ssl_context

    def _generate_certs(self):
        """Generate self-signed SSL certificates."""
        import subprocess
        cert_dir = pathlib.Path(self.server_config.ssl_cert).parent
        cert_dir.mkdir(parents=True, exist_ok=True)

        cert_path = pathlib.Path(self.server_config.ssl_cert)
        key_path = pathlib.Path(self.server_config.ssl_key)

        subprocess.run(
            [
                "openssl", "req", "-new", "-x509",
                "-keyout", str(key_path),
                "-out", str(cert_path),
                "-days", "3650",
                "-nodes",
                "-subj", "/CN=emiscreen.local",
                "-addext", "subjectAltName=DNS:emiscreen.local,DNS:localhost,IP:127.0.0.1",
            ],
            check=True,
            capture_output=True,
        )
        logger.info(f"SSL certificates generated at {cert_dir}")

    def _get_local_ip(self) -> str:
        """Get the local IP address for display."""
        import socket
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))
            ip = s.getsockname()[0]
            s.close()
            return ip
        except Exception:
            return "localhost"

    async def _auto_launch_browser(self):
        """Auto-launch browser on FireTV with stream URL."""
        if not self.adb:
            return

        # Wait for server to be ready
        await asyncio.sleep(3)

        url = f"https://{self._get_local_ip()}:{self.server_config.port}"
        logger.info(f"Launching FireTV browser: {url}")
        await self.adb.launch_browser(url)


def main():
    """CLI entry point."""
    parser = argparse.ArgumentParser(description="Emiscreen - Remote Display via WebRTC")
    parser.add_argument(
        "--source", "-s",
        default="ubuntu-desktop",
        help=f"Capture source name (default: ubuntu-desktop). Available: {list(SOURCES.keys())}",
    )
    parser.add_argument(
        "--host",
        default="0.0.0.0",
        help="Server bind address (default: 0.0.0.0)",
    )
    parser.add_argument(
        "--port", "-p",
        type=int,
        default=8443,
        help="Server port (default: 8443)",
    )
    parser.add_argument(
        "--firetv", "-f",
        help="FireTV IP address for ADB control",
    )
    parser.add_argument(
        "--resolution", "-r",
        help="Capture resolution (e.g., 1920x1080)",
    )
    parser.add_argument(
        "--fps",
        type=int,
        help="Capture frame rate",
    )
    parser.add_argument(
        "--no-adb",
        action="store_true",
        help="Disable ADB/FireTV control",
    )
    parser.add_argument(
        "--no-relay",
        action="store_true",
        help="Disable input relay",
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Enable debug logging",
    )

    args = parser.parse_args()

    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    # Load config
    load_from_env()

    # Get capture source config
    capture_config = get_source(args.source)

    # Override from CLI args
    if args.resolution:
        capture_config.resolution = args.resolution
    if args.fps:
        capture_config.fps = args.fps

    # Server config
    server_config = ServerConfig(host=args.host, port=args.port)

    # ADB config
    adb_config = ADBConfig(
        enabled=not args.no_adb and args.firetv is not None,
        host=args.firetv,
    )

    # Relay config
    relay_config = RelayConfig(enabled=not args.no_relay)

    # Create and run server
    server = EmiscreenServer(
        server_config=server_config,
        capture_config=capture_config,
        adb_config=adb_config,
        relay_config=relay_config,
    )

    try:
        asyncio.run(server.start())
    except KeyboardInterrupt:
        logger.info("Interrupted by user")
    except Exception as e:
        logger.error(f"Server error: {e}", exc_info=True)
        sys.exit(1)


if __name__ == "__main__":
    main()

"""Tests for SSL certificate generation."""
import pytest
import tempfile
import pathlib
from cryptography import x509
from cryptography.hazmat.primitives import serialization


class TestCertGeneration:
    def test_cert_contains_san(self):
        from emiscreen.server import EmiscreenServer
        from emiscreen.config import ServerConfig, CaptureConfig, ADBConfig, RelayConfig
        
        with tempfile.TemporaryDirectory() as tmpdir:
            cert_path = pathlib.Path(tmpdir) / "test.crt"
            key_path = pathlib.Path(tmpdir) / "test.key"
            
            server_config = ServerConfig(
                host="0.0.0.0",
                port=8445,
                ssl_cert=str(cert_path),
                ssl_key=str(key_path),
            )
            capture_config = CaptureConfig(type="windows")
            adb_config = ADBConfig(enabled=False)
            relay_config = RelayConfig(enabled=False)
            
            server = EmiscreenServer(server_config, capture_config, adb_config, relay_config)
            server._generate_certs()
            
            assert cert_path.exists()
            assert key_path.exists()
            
            # Parse cert and verify SAN
            cert_bytes = cert_path.read_bytes()
            cert = x509.load_pem_x509_certificate(cert_bytes)
            
            san_ext = cert.extensions.get_extension_for_class(x509.SubjectAlternativeName)
            san_names = [name.value for name in san_ext.value]
            
            assert "emiscreen.local" in san_names
            assert "localhost" in san_names
            assert "127.0.0.1" in str(san_names)

    def test_key_is_rsa_2048(self):
        from emiscreen.server import EmiscreenServer
        from emiscreen.config import ServerConfig, CaptureConfig, ADBConfig, RelayConfig
        
        with tempfile.TemporaryDirectory() as tmpdir:
            cert_path = pathlib.Path(tmpdir) / "test.crt"
            key_path = pathlib.Path(tmpdir) / "test.key"
            
            server_config = ServerConfig(
                host="0.0.0.0",
                port=8445,
                ssl_cert=str(cert_path),
                ssl_key=str(key_path),
            )
            capture_config = CaptureConfig(type="windows")
            adb_config = ADBConfig(enabled=False)
            relay_config = RelayConfig(enabled=False)
            
            server = EmiscreenServer(server_config, capture_config, adb_config, relay_config)
            server._generate_certs()
            
            key_bytes = key_path.read_bytes()
            key = serialization.load_pem_private_key(key_bytes, password=None)
            
            assert key.key_size == 2048

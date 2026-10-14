import os
import pytest
from datetime import datetime, timezone
from unittest.mock import patch
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")))

from app.logic import (
    calculate_item_subtotal,
    calculate_discounted_total,
    calculate_order_tax,
    sanitize_customer_notes,
)

def simulate_payment_gateway_ping(endpoint_url: str):
    """Simulates external payment gateway communication with timeout handling."""
    import urllib.request
    import urllib.error
    try:
        req = urllib.request.Request(endpoint_url)
        with urllib.request.urlopen(req, timeout=2) as response:
            return response.read()
    except (urllib.error.URLError, TimeoutError) as exc:
        return {"error": "Payment gateway timeout or unreachable", "detail": str(exc)}

@pytest.mark.edge
class TestEdgeCases:
    def test_null_and_empty_inputs(self):
        assert sanitize_customer_notes(None) == ""
        assert sanitize_customer_notes("") == ""
        assert sanitize_customer_notes("   ") == ""

    def test_wrong_type_inputs(self):
        assert sanitize_customer_notes(12345) == ""
        assert sanitize_customer_notes({"instructions": "leave at door"}) == ""

    def test_min_max_boundary_values(self):
        # Valid boundaries (0% and 100%)
        assert calculate_discounted_total(100.0, 0.0) == 100.0
        assert calculate_discounted_total(100.0, 100.0) == 0.0

        # Off-by-one / invalid boundaries
        with pytest.raises(ValueError):
            calculate_discounted_total(100.0, -0.01)

        with pytest.raises(ValueError):
            calculate_discounted_total(100.0, 100.01)

        with pytest.raises(ValueError):
            calculate_item_subtotal(-1.0, 5)

        with pytest.raises(ValueError):
            calculate_item_subtotal(10.0, -1)

    def test_large_input_payload_truncation(self):
        huge_text = "Urgent Delivery! " * 500  # > 8000 chars
        sanitized = sanitize_customer_notes(huge_text)
        assert len(sanitized) == 150
        assert sanitized.startswith("Urgent Delivery!")

    def test_unicode_and_injection_strings(self):
        payload = "📦 Order #1'; DROP TABLE orders; -- <script>alert('xss')</script>"
        sanitized = sanitize_customer_notes(payload)
        assert "📦" in sanitized
        assert len(sanitized) <= 150

    def test_timezone_and_leap_year_boundaries(self):
        leap_day = datetime(2024, 2, 29, 23, 59, 59, 999999, tzinfo=timezone.utc)
        assert leap_day.month == 2
        assert leap_day.day == 29
        assert leap_day.isoformat() == "2024-02-29T23:59:59.999999+00:00"

    def test_external_gateway_timeout_mocked(self):
        with patch("urllib.request.urlopen") as mock_url:
            mock_url.side_effect = TimeoutError("Connection timed out")
            result = simulate_payment_gateway_ping("https://mock-payment-gateway.internal/health")
            assert isinstance(result, dict)
            assert "error" in result
            assert "timeout" in result["error"].lower()

    def test_intentional_failure_gate(self):
        """Used to verify CI pipeline blocks failing tests when FAIL_GATE=true."""
        if os.environ.get("FAIL_GATE", "").lower() in ("true", "1"):
            pytest.fail("Intentional test failure triggered by FAIL_GATE=true")

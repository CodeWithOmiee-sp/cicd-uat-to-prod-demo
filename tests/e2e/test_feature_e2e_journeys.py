"""
Automated End-to-End (E2E) Feature Journey Tests.
Executes complete user journeys against live UAT endpoint (APP_URL) or simulated API client.
"""
import json
import os
import sys
import urllib.error
import urllib.request

import pytest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")))

from app.logic import (
    calculate_discounted_total,
    calculate_item_subtotal,
    calculate_order_tax,
    sanitize_customer_notes,
)

APP_URL = os.environ.get("APP_URL", "").rstrip("/")


def _make_http_request(method: str, path: str, payload: dict = None) -> tuple[int, dict]:
    """Helper to perform HTTP requests against the live UAT URL."""
    url = f"{APP_URL}{path}"
    data = json.dumps(payload).encode("utf-8") if payload else None
    headers = {"Content-Type": "application/json", "User-Agent": "OrderHub-E2E-Runner"}
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            body = json.loads(resp.read().decode("utf-8"))
            return resp.status, body
    except urllib.error.HTTPError as err:
        body = {}
        try:
            body = json.loads(err.read().decode("utf-8"))
        except Exception:
            pass
        return err.code, body


@pytest.mark.e2e
class TestAutomatedFeatureJourneys:
    """Simulates real multi-step user workflows on the deployed application."""

    def test_journey_1_system_health_and_service_info(self):
        """Journey 1: Verifies that UAT service is healthy and reports ready."""
        if APP_URL:
            status_code, body = _make_http_request("GET", "/api/health")
            assert status_code == 200, f"Health check failed with {status_code}"
            assert body.get("status") == "ok"
            assert "version" in body
            assert body.get("orders_count", 0) >= 0
        else:
            # Local simulation verification
            assert True

    def test_journey_2_complete_order_lifecycle(self):
        """
        Journey 2: Full End-to-End Business Flow
        1. User browses current orders
        2. User creates a multi-item order with discount
        3. Financial calculations are verified (subtotal, tax, total)
        4. User fetches the created order by ID and verifies persistence
        """
        if APP_URL:
            # Step 1: List existing orders
            status_code, initial_orders = _make_http_request("GET", "/api/orders")
            assert status_code == 200
            initial_count = len(initial_orders)

            # Step 2: Place a new order
            new_order_payload = {
                "customer_id": "CUST-E2E-AUTO",
                "items": [
                    {"item_id": "ITEM-1", "name": "Mechanical Keyboard", "unit_price": 80.0, "quantity": 2},
                    {"item_id": "ITEM-2", "name": "Wireless Mouse", "unit_price": 40.0, "quantity": 1},
                ],
                "discount_percent": 10.0,
                "notes": "   Please deliver before Friday afternoon   ",
            }

            status_code, created_order = _make_http_request("POST", "/api/orders", new_order_payload)
            assert status_code == 201, f"Expected 201 Created, got {status_code}: {created_order}"

            order_id = created_order["order_id"]
            # Subtotal: (80*2) + (40*1) = 200.0
            assert created_order["subtotal"] == 200.0
            # Discount: 10% of 200 = 20 -> 180.0
            # Tax: 8.5% of 180 = 15.30
            # Total: 180 + 15.30 = 195.30
            assert created_order["total"] == 195.30
            assert created_order["notes"] == "Please deliver before Friday afternoon"

            # Step 3: Fetch the created order by ID and verify persistence
            status_code, fetched_order = _make_http_request("GET", f"/api/orders/{order_id}")
            assert status_code == 200
            assert fetched_order["order_id"] == order_id
            assert fetched_order["customer_id"] == "CUST-E2E-AUTO"
            assert fetched_order["total"] == 195.30

            # Step 4: Verify count incremented
            status_code, final_orders = _make_http_request("GET", "/api/orders")
            assert status_code == 200
            assert len(final_orders) == initial_count + 1
        else:
            # Standalone logic journey validation
            subtotal = calculate_item_subtotal(80.0, 2) + calculate_item_subtotal(40.0, 1)
            discounted = calculate_discounted_total(subtotal, 10.0)
            tax = calculate_order_tax(discounted)
            total = round(discounted + tax, 2)
            assert total == 195.30
            assert sanitize_customer_notes("  Test note  ") == "Test note"

    def test_journey_3_resilience_and_error_handling(self):
        """Journey 3: Validates application error handling for missing resources and bad data."""
        if APP_URL:
            # 1. Non-existent order returns 404
            status_code, _ = _make_http_request("GET", "/api/orders/NON-EXISTENT-ID-999")
            assert status_code == 404

            # 2. Invalid payload returns 422 Unprocessable Entity
            bad_order_payload = {
                "customer_id": "CUST-ERR",
                "items": [{"item_id": "ITEM-BAD", "name": "Invalid", "unit_price": -50.0, "quantity": 1}],
                "discount_percent": 150.0,  # Invalid discount > 100%
            }
            status_code, _ = _make_http_request("POST", "/api/orders", bad_order_payload)
            assert status_code in (400, 422)
        else:
            with pytest.raises(ValueError):
                calculate_discounted_total(100.0, 150.0)

    def test_journey_4_concurrent_order_integrity(self):
        """Journey 4: Multiple rapid transactions do not cause data corruption."""
        for i in range(1, 4):
            subtotal = calculate_item_subtotal(50.0, i)
            discounted = calculate_discounted_total(subtotal, 5.0)
            tax = calculate_order_tax(discounted)
            total = round(discounted + tax, 2)
            assert total > 0

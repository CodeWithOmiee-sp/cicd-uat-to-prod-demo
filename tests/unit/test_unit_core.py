import pytest
import sys
import os

# Ensure app is discoverable
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")))

from app.logic import (
    calculate_item_subtotal,
    calculate_discounted_total,
    calculate_order_tax,
    sanitize_customer_notes,
)

@pytest.mark.unit
class TestUnitCoreCalculations:
    def test_calculate_subtotal_standard(self):
        assert calculate_item_subtotal(25.50, 4) == 102.0

    def test_calculate_subtotal_zero_quantity(self):
        assert calculate_item_subtotal(100.0, 0) == 0.0

    def test_calculate_discount_standard(self):
        assert calculate_discounted_total(200.0, 15.0) == 170.0

    def test_calculate_discount_zero_percent(self):
        assert calculate_discounted_total(150.0, 0.0) == 150.0

    def test_calculate_discount_full_hundred_percent(self):
        assert calculate_discounted_total(99.99, 100.0) == 0.0

    def test_calculate_order_tax_default(self):
        assert calculate_order_tax(100.0) == 8.50

    def test_sanitize_customer_notes_strip(self):
        assert sanitize_customer_notes("   Please ring doorbell   ") == "Please ring doorbell"

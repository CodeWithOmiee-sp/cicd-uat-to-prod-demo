"""
OrderHub Core Logic
Pure Python business calculation functions with zero external dependencies.
"""
from typing import Optional

def calculate_item_subtotal(unit_price: float, quantity: int) -> float:
    """Calculates subtotal for an item line."""
    if quantity < 0 or unit_price < 0:
        raise ValueError("Price and quantity must be non-negative.")
    return round(unit_price * quantity, 2)


def calculate_discounted_total(subtotal: float, discount_percent: float) -> float:
    """Applies percentage discount with boundary checks."""
    if discount_percent < 0 or discount_percent > 100:
        raise ValueError("Discount percentage must be between 0 and 100.")
    if subtotal < 0:
        raise ValueError("Subtotal must be non-negative.")
    discount_amount = (subtotal * discount_percent) / 100.0
    return round(subtotal - discount_amount, 2)


def calculate_order_tax(amount: float, tax_rate_percent: float = 8.5) -> float:
    """Calculates sales tax."""
    if tax_rate_percent < 0 or amount < 0:
        raise ValueError("Amount and tax rate must be non-negative.")
    return round((amount * tax_rate_percent) / 100.0, 2)


def sanitize_customer_notes(notes: Optional[str]) -> str:
    """Sanitizes customer order notes, limiting length to 150 characters."""
    if not notes or not isinstance(notes, str):
        return ""
    cleaned = notes.strip()
    return cleaned[:150]

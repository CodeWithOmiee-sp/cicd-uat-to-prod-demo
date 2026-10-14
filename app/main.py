"""
OrderHub REST API Service
Clean, lightweight sample application for UAT to Production Git Automation.
"""
import os
from typing import Any

from app.logic import (
    calculate_discounted_total,
    calculate_item_subtotal,
    calculate_order_tax,
    sanitize_customer_notes,
)

APP_ENV = os.environ.get("APP_ENV", "local")

try:
    from fastapi import FastAPI, HTTPException, status
    from pydantic import BaseModel, Field

    app = FastAPI(
        title="OrderHub API",
        version="1.0.0",
        description="Deterministic REST API service demonstrating automated CI/CD deployment pipelines."
    )

    class OrderItem(BaseModel):
        item_id: str
        name: str
        unit_price: float = Field(ge=0.0)
        quantity: int = Field(ge=1)

    class CreateOrderRequest(BaseModel):
        customer_id: str
        items: list[OrderItem]
        discount_percent: float = Field(default=0.0, ge=0.0, le=100.0)
        notes: str | None = None

    class OrderResponse(BaseModel):
        order_id: str
        customer_id: str
        subtotal: float
        discount_percent: float
        tax: float
        total: float
        status: str
        environment: str
        notes: str

    _ORDERS_DB: dict[str, dict[str, Any]] = {
        "ORD-1001": {
            "order_id": "ORD-1001",
            "customer_id": "CUST-99",
            "subtotal": 120.0,
            "discount_percent": 10.0,
            "tax": 9.18,
            "total": 117.18,
            "status": "confirmed",
            "environment": APP_ENV,
            "notes": "Standard express delivery"
        }
    }

    @app.get("/api/health", tags=["System"])
    def health_check():
        return {
            "status": "ok",
            "service": "orderhub-api",
            "version": "1.0.0",
            "environment": APP_ENV,
            "orders_count": len(_ORDERS_DB)
        }

    @app.get("/api/orders", response_model=list[OrderResponse], tags=["Orders"])
    def list_orders():
        return list(_ORDERS_DB.values())

    @app.get("/api/orders/{order_id}", response_model=OrderResponse, tags=["Orders"])
    def get_order(order_id: str):
        order = _ORDERS_DB.get(order_id)
        if not order:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Order '{order_id}' not found."
            )
        return order

    @app.post("/api/orders", response_model=OrderResponse, status_code=status.HTTP_201_CREATED, tags=["Orders"])
    def create_order(req: CreateOrderRequest):
        subtotal = sum(calculate_item_subtotal(i.unit_price, i.quantity) for i in req.items)
        discounted = calculate_discounted_total(subtotal, req.discount_percent)
        tax = calculate_order_tax(discounted)
        total = round(discounted + tax, 2)
        order_id = f"ORD-{1000 + len(_ORDERS_DB) + 1}"

        new_order = {
            "order_id": order_id,
            "customer_id": req.customer_id,
            "subtotal": subtotal,
            "discount_percent": req.discount_percent,
            "tax": tax,
            "total": total,
            "status": "confirmed",
            "environment": APP_ENV,
            "notes": sanitize_customer_notes(req.notes)
        }
        _ORDERS_DB[order_id] = new_order
        return new_order

except ImportError:
    app = None

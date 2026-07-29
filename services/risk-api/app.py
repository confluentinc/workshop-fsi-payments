"""
RiverPay shared Risk Scoring API — operational exception probability (not fraud).

GET /health
POST /v1/risk  JSON body: { amount, segment, account_tier, currency?, payment_type? }
GET  /v1/risk?amount=&segment=&account_tier=
Response: { risk_score, risk_reason }

Optional auth: set RISK_API_KEY; clients send Authorization: Bearer <key>.
"""

from __future__ import annotations

import os
from typing import Optional

from fastapi import Depends, FastAPI, Header, HTTPException
from pydantic import BaseModel, Field

app = FastAPI(title="RiverPay Risk Scoring API", version="1.0.0")

EXPECTED_API_KEY = os.environ.get("RISK_API_KEY", "").strip()


class RiskRequest(BaseModel):
    amount: float = Field(..., ge=0)
    segment: str = "retail"
    account_tier: str = "standard"
    currency: Optional[str] = "USD"
    payment_type: Optional[str] = "instant_credit_transfer"


class RiskResponse(BaseModel):
    risk_score: float
    risk_reason: str


def require_api_key(authorization: Optional[str] = Header(default=None)) -> None:
    if not EXPECTED_API_KEY:
        return
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="missing bearer token")
    token = authorization[len("Bearer ") :].strip()
    if token != EXPECTED_API_KEY:
        raise HTTPException(status_code=401, detail="invalid api key")


def score(amount: float, segment: str, account_tier: str) -> RiskResponse:
    """Deterministic heuristics — same shape as the interim Flink CASE logic."""
    seg = (segment or "").lower()
    tier = (account_tier or "").lower()

    if amount >= 10000:
        return RiskResponse(
            risk_score=0.85,
            risk_reason="amount_significantly_above_customer_baseline",
        )
    if amount >= 5000 and tier == "standard":
        return RiskResponse(
            risk_score=0.72,
            risk_reason="high_value_standard_tier",
        )
    if seg == "new_partner":
        return RiskResponse(
            risk_score=0.65,
            risk_reason="new_partner_bank_customer",
        )
    if amount >= 2500:
        return RiskResponse(
            risk_score=0.48,
            risk_reason="elevated_amount_review_recommended",
        )
    if tier == "premium":
        return RiskResponse(
            risk_score=0.12,
            risk_reason="low_value_established_recipient",
        )
    return RiskResponse(
        risk_score=0.28,
        risk_reason="routine_instant_credit_transfer",
    )


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "service": "riverpay-risk-api"}


@app.post("/v1/risk", response_model=RiskResponse, dependencies=[Depends(require_api_key)])
def lookup_risk(body: RiskRequest) -> RiskResponse:
    return score(body.amount, body.segment, body.account_tier)


@app.get("/v1/risk", response_model=RiskResponse, dependencies=[Depends(require_api_key)])
def lookup_risk_get(
    amount: float,
    segment: str = "retail",
    account_tier: str = "standard",
) -> RiskResponse:
    """GET variant for simple UDF query-string calls."""
    return score(amount, segment, account_tier)


if __name__ == "__main__":
    import uvicorn

    port = int(os.environ.get("PORT", "8089"))
    uvicorn.run(app, host="0.0.0.0", port=port)

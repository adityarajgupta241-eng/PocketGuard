from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, Field


class NotificationIn(BaseModel):
    package_name: str = Field(..., min_length=1)
    title: str = ""
    text: str = ""
    timestamp: Optional[datetime] = None


class ExpenseOut(BaseModel):
    id: int
    amount: float
    vendor: str
    type: str
    raw_text: str
    timestamp: datetime

    model_config = {"from_attributes": True}


class NotificationResult(BaseModel):
    status: str
    reason: Optional[str] = None
    data: Optional[ExpenseOut] = None


class ExpensesResponse(BaseModel):
    daily_total: float
    expenses: List[ExpenseOut]

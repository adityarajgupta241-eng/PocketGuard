from datetime import datetime, timezone
from typing import Optional

from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import select
from sqlalchemy.orm import Session

from database import Base, engine, get_db
from models import Expense
from parser import parse_notification
from schemas import ExpenseOut, ExpensesResponse, NotificationIn, NotificationResult

Base.metadata.create_all(bind=engine)

app = FastAPI(title="PocketGuard", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


def _as_utc(value: Optional[datetime]) -> datetime:
    if value is None:
        return datetime.now(timezone.utc)
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/api/notifications", response_model=NotificationResult)
def ingest_notification(payload: NotificationIn, db: Session = Depends(get_db)):
    parsed = parse_notification(payload.title, payload.text)
    if parsed is None:
        return NotificationResult(status="ignored", reason="non_financial_or_unparseable")

    expense = Expense(
        amount=parsed.amount,
        vendor=parsed.vendor,
        type=parsed.type,
        raw_text=parsed.raw_text,
        timestamp=_as_utc(payload.timestamp),
    )
    db.add(expense)
    db.commit()
    db.refresh(expense)
    return NotificationResult(status="success", data=ExpenseOut.model_validate(expense))


@app.get("/api/expenses", response_model=ExpensesResponse)
def list_expenses(db: Session = Depends(get_db)):
    expenses = db.scalars(select(Expense).order_by(Expense.timestamp.desc())).all()
    today = datetime.now(timezone.utc).date()
    daily_total = 0.0
    for item in expenses:
        stamp = item.timestamp
        if stamp.tzinfo is None:
            stamp = stamp.replace(tzinfo=timezone.utc)
        if stamp.astimezone(timezone.utc).date() == today and item.type == "Debit":
            daily_total += item.amount

    return ExpensesResponse(
        daily_total=round(daily_total, 2),
        expenses=[ExpenseOut.model_validate(item) for item in expenses],
    )

"""SMS / notification parsers for Indian bank and UPI messages."""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Optional

OTP_RE = re.compile(
    r"\b(otp|one[-\s]?time\s+password|verification\s+code|auth(?:entication)?\s+code|"
    r"do(?:n['’]?t|\s+not)\s+share|never\s+share|secret\s+code)\b",
    re.IGNORECASE,
)

SECURITY_RE = re.compile(
    r"\b(login\s+attempt|new\s+device|password\s+(?:changed|reset|updated)|"
    r"pin\s+(?:changed|reset|updated)|kyc|suspicious(?:\s+activit(?:y|ies))?|"
    r"blocked\s+(?:your\s+)?(?:card|account)|registered\s+successfully|"
    r"enable\s+(?:biometric|2fa)|security\s+alert)\b",
    re.IGNORECASE,
)

PROMO_RE = re.compile(
    r"\b(limited[-\s]?time|click\s+here|unsubscribe|pre[-\s]?approved|"
    r"loan\s+offer|win\s+a|congratulat(?:ions|e)|flat\s+\d+%\s+off|"
    r"exclusive\s+offer|promo(?:tion)?\s+code|download\s+(?:the\s+)?app|"
    r"cashback\s+offer|hurry|don['’]?t\s+miss)\b",
    re.IGNORECASE,
)

FINANCIAL_RE = re.compile(
    r"(?:₹|\binr\b|\brs\.?\b|\bdebited\b|\bcredited\b|\bwithdrawn\b|\bspent\b|"
    r"\bpaid\b|\breceived\b|\bupi\b|\bimps\b|\bneft\b|\brtgs\b|\batm\b|"
    r"\btxn\b|\btransaction\b|\ba/?c\b|\baccount\b|\bpurchase\b|"
    r"\btransferred\b|\bdeposit(?:ed)?\b)",
    re.IGNORECASE,
)

AMOUNT_RE = re.compile(
    r"(?:(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?))"
    r"|(?:(?:debited|credited|withdrawn|paid|spent|received|sent)\s+"
    r"(?:by|for|of|with|amt(?:\.|ount)?)?\s*(?:rs\.?|inr|₹)?\s*([\d,]+(?:\.\d{1,2})?))",
    re.IGNORECASE,
)

CREDIT_RE = re.compile(
    r"\b(credited|received|refund(?:ed)?|deposit(?:ed)?|cashback\s+(?:of|rs)|"
    r"added\s+to\s+(?:your\s+)?(?:wallet|account)|salary)\b",
    re.IGNORECASE,
)

DEBIT_RE = re.compile(
    r"\b(debited|withdrawn|spent|paid|purchase[ds]?|sent\s+to|transferred|"
    r"payment\s+(?:of|made)|atm\s+withdrawal)\b",
    re.IGNORECASE,
)

VENDOR_CONTEXT_RE = re.compile(
    r"\b(?:at|to|from|towards|via|for)\s+"
    r"([A-Za-z][A-Za-z0-9@._&+\-]{1,40}(?:\s+[A-Za-z0-9@._&+\-]{1,20}){0,3})",
    re.IGNORECASE,
)

KNOWN_VENDORS = (
    ("google pay", "Google Pay"),
    ("gpay", "Google Pay"),
    ("phonepe", "PhonePe"),
    ("paytm", "Paytm"),
    ("swiggy", "Swiggy"),
    ("zomato", "Zomato"),
    ("amazon", "Amazon"),
    ("flipkart", "Flipkart"),
    ("bigbasket", "BigBasket"),
    ("blinkit", "Blinkit"),
    ("zepto", "Zepto"),
    ("myntra", "Myntra"),
    ("ajio", "Ajio"),
    ("netflix", "Netflix"),
    ("spotify", "Spotify"),
    ("uber", "Uber"),
    ("ola", "Ola"),
    ("irctc", "IRCTC"),
    ("bookmyshow", "BookMyShow"),
    ("atm", "ATM"),
    ("upi", "UPI"),
)

SKIP_VENDOR_TOKENS = {
    "your",
    "a/c",
    "ac",
    "account",
    "bank",
    "inr",
    "rs",
    "the",
    "info",
    "sms",
    "xx",
}


@dataclass(frozen=True)
class ParsedExpense:
    amount: float
    vendor: str
    type: str
    raw_text: str


def _is_noise(text: str) -> bool:
    if OTP_RE.search(text):
        return True
    if SECURITY_RE.search(text):
        return True
    if PROMO_RE.search(text) and not DEBIT_RE.search(text) and not CREDIT_RE.search(text):
        return True
    return not FINANCIAL_RE.search(text)


def _parse_amount(text: str) -> Optional[float]:
    match = AMOUNT_RE.search(text)
    if not match:
        return None
    raw = next((group for group in match.groups() if group), None)
    if not raw:
        return None
    try:
        value = float(raw.replace(",", ""))
    except ValueError:
        return None
    if value <= 0:
        return None
    return round(value, 2)


def _clean_vendor(candidate: str) -> Optional[str]:
    cleaned = re.sub(r"\s+", " ", candidate).strip(" .,-")
    cleaned = re.sub(r"\b(on|dated|ref|txn|id)\b.*$", "", cleaned, flags=re.IGNORECASE).strip()
    if not cleaned:
        return None
    first = cleaned.split()[0].lower().rstrip(".,")
    if first in SKIP_VENDOR_TOKENS or first.isdigit():
        return None
    if len(cleaned) < 2:
        return None
    return cleaned[:48]


def _parse_vendor(text: str) -> str:
    lowered = text.lower()
    for needle, label in KNOWN_VENDORS:
        if needle in lowered:
            return label

    for match in VENDOR_CONTEXT_RE.finditer(text):
        vendor = _clean_vendor(match.group(1))
        if vendor:
            return vendor.title() if vendor.isupper() or vendor.islower() else vendor

    if re.search(r"\bupi\b", text, re.IGNORECASE):
        return "UPI"
    return "Unknown"


def _parse_type(text: str) -> str:
    credit = CREDIT_RE.search(text)
    debit = DEBIT_RE.search(text)
    if credit and not debit:
        return "Credit"
    if debit and not credit:
        return "Debit"
    if credit and debit:
        return "Credit" if credit.start() < debit.start() else "Debit"
    return "Debit"


def parse_notification(title: str, body: str) -> Optional[ParsedExpense]:
    """Return a parsed expense, or None if the notification should be ignored."""
    raw_text = " ".join(part.strip() for part in (title, body) if part and part.strip())
    if not raw_text:
        return None
    if _is_noise(raw_text):
        return None

    amount = _parse_amount(raw_text)
    if amount is None:
        return None

    return ParsedExpense(
        amount=amount,
        vendor=_parse_vendor(raw_text),
        type=_parse_type(raw_text),
        raw_text=raw_text[:1000],
    )

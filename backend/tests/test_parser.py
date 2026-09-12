import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from parser import parse_notification


class ParserTests(unittest.TestCase):
    def test_debit_swiggy(self):
        parsed = parse_notification(
            "HDFC Bank",
            "Rs. 499.00 debited from A/c XX1234 at Swiggy on 12-09-26",
        )
        self.assertIsNotNone(parsed)
        self.assertEqual(parsed.amount, 499.0)
        self.assertEqual(parsed.vendor, "Swiggy")
        self.assertEqual(parsed.type, "Debit")

    def test_inr_credit(self):
        parsed = parse_notification(
            "SBI",
            "INR 1,250.00 credited to your A/c from Amazon refund",
        )
        self.assertIsNotNone(parsed)
        self.assertEqual(parsed.amount, 1250.0)
        self.assertEqual(parsed.vendor, "Amazon")
        self.assertEqual(parsed.type, "Credit")

    def test_debited_by_phrase(self):
        parsed = parse_notification("Axis Bank", "A/c XX88 debited by 350 towards UPI")
        self.assertIsNotNone(parsed)
        self.assertEqual(parsed.amount, 350.0)
        self.assertEqual(parsed.vendor, "UPI")
        self.assertEqual(parsed.type, "Debit")

    def test_ignores_otp(self):
        self.assertIsNone(
            parse_notification("HDFC", "Your OTP is 482911. Do not share with anyone. Rs. 0")
        )

    def test_ignores_promo(self):
        self.assertIsNone(
            parse_notification("Bank", "Limited-time offer! Get 10% off. Click here to apply.")
        )


if __name__ == "__main__":
    unittest.main()

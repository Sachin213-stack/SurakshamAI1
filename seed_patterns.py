"""
Seed Pinecone with known scam patterns.
Usage: python seed_patterns.py
"""
import asyncio
from dotenv import load_dotenv
load_dotenv()

from agent.memory import store_pattern

KNOWN_SCAM_PATTERNS = [
    ("Your account will be blocked. Click the link immediately to verify your KYC.", "phishing"),
    ("Congratulations! You have won a lottery. Share your OTP to claim the prize.", "smishing"),
    ("This is [INSTITUTION] helpdesk. Your card is compromised. Share your PIN to secure it.", "vishing"),
    ("Urgent: Transfer [SENSITIVE_NUM] to this UPI ID to avoid legal action.", "scam"),
    ("Your [INSTITUTION] account is suspended. Verify now or lose access permanently.", "phishing"),
    ("Dear customer, your [SENSITIVE_NUM] reward points expire today. Redeem via this [URL].", "smishing"),
    ("You have a pending refund. Please share your account number to process it.", "scam"),
    ("Hi [USER], your electricity will be cut in 2 hours. Pay [SENSITIVE_NUM] immediately.", "scam"),
    ("Your KYC is incomplete. Update now or your account will be frozen within 24 hours.", "phishing"),
    ("We detected suspicious login. Confirm your identity by sharing your OTP.", "vishing"),
    ("You are selected for a government scheme. Send your Aadhaar and bank details.", "scam"),
    ("Your parcel is on hold. Pay customs fee via this link to release it.", "smishing"),
]


async def main():
    print(f"Seeding {len(KNOWN_SCAM_PATTERNS)} patterns into Pinecone...\n")
    success, failed = 0, 0
    for text, label in KNOWN_SCAM_PATTERNS:
        ok = await store_pattern(text, label)
        if ok:
            success += 1
            print(f"  ✓ [{label}] {text[:65]}...")
        else:
            failed += 1
            print(f"  ✗ FAILED: {text[:65]}...")

    print(f"\nDone. {success} stored, {failed} failed.")


if __name__ == "__main__":
    asyncio.run(main())

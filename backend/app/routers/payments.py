import hashlib
import hmac
import httpx
from fastapi import APIRouter, Depends, HTTPException, Request

from app.auth import get_current_user, require_teacher
from app.config import settings
from app.database import supabase
from app.models import CheckoutCreate, CheckoutOut, WithdrawalCreate

router = APIRouter(prefix="/payments", tags=["Paiements"])

PLATFORM_FEE_RATE = 0.17  # 17% prélevés par la plateforme sur chaque retrait


@router.post("/checkout", response_model=CheckoutOut)
async def create_checkout(payload: CheckoutCreate, user: dict = Depends(get_current_user)):
    """Crée une session de paiement LeekPay pour rejoindre une classe payante (élève ou enseignant)."""
    cls = supabase.table("classes").select("*").eq("id", payload.class_id).execute()
    if not cls.data:
        raise HTTPException(status_code=404, detail="Classe introuvable")
    class_data = cls.data[0]

    if not class_data.get("is_paid"):
        raise HTTPException(status_code=400, detail="Cette classe est gratuite, pas besoin de payer")

    existing = supabase.table("class_members").select("id").eq("class_id", payload.class_id).eq(
        "student_id", user["id"]
    ).execute()
    if existing.data:
        raise HTTPException(status_code=400, detail="Vous êtes déjà inscrit à cette classe")

    payment = supabase.table("payments").insert({
        "class_id": payload.class_id,
        "student_id": user["id"],
        "amount": class_data["price"],
        "currency": class_data["currency"],
        "status": "pending",
    }).execute().data[0]

    async with httpx.AsyncClient() as client:
        try:
            resp = await client.post(
                f"{settings.LEEKPAY_BASE_URL}/api/v1/checkout",
                headers={"Authorization": f"Bearer {settings.LEEKPAY_SECRET_KEY}"},
                json={
                    "amount": class_data["price"],
                    "currency": class_data["currency"],
                    "description": f"Inscription à la classe {class_data['name']}",
                    "return_url": settings.LEEKPAY_RETURN_URL,
                    "cancel_url": settings.LEEKPAY_CANCEL_URL,
                    "webhook_url": settings.LEEKPAY_WEBHOOK_URL,
                    "customer_email": user.get("email"),
                    "customer_name": user.get("full_name"),
                    "metadata": {"payment_id": payment["id"], "class_id": payload.class_id},
                },
                timeout=15.0,
            )
            resp.raise_for_status()
            body = resp.json()
        except Exception as e:
            supabase.table("payments").update({"status": "failed"}).eq("id", payment["id"]).execute()
            raise HTTPException(status_code=502, detail=f"Erreur LeekPay: {e}")

    data = body.get("data", {})
    checkout_url = data.get("payment_url")
    leekpay_id = data.get("id")

    if not checkout_url:
        supabase.table("payments").update({"status": "failed"}).eq("id", payment["id"]).execute()
        raise HTTPException(status_code=502, detail="Réponse LeekPay invalide (pas d'URL de paiement)")

    supabase.table("payments").update({"leekpay_reference": leekpay_id}).eq("id", payment["id"]).execute()

    return CheckoutOut(checkout_url=checkout_url, payment_id=payment["id"])


@router.post("/webhook")
async def leekpay_webhook(request: Request):
    """Reçoit la confirmation LeekPay (payment.completed / payment.failed / payment.cancelled)."""
    raw_body = await request.body()
    signature = request.headers.get("X-LeekPay-Signature", "")

    expected_signature = hmac.new(
        settings.LEEKPAY_PUBLIC_KEY.encode(),
        raw_body,
        hashlib.sha256,
    ).hexdigest()

    if not hmac.compare_digest(signature, expected_signature):
        raise HTTPException(status_code=401, detail="Signature invalide")

    payload = await request.json()
    data = payload.get("data", {})
    checkout_id = data.get("checkout_id")
    status = data.get("status")  # "paid" | "failed" | "cancelled" | ...

    payment = supabase.table("payments").select("*").eq("leekpay_reference", checkout_id).execute()
    if not payment.data:
        raise HTTPException(status_code=404, detail="Paiement introuvable")

    payment_row = payment.data[0]

    if status == "paid":
        supabase.table("payments").update({
            "status": "success",
            "confirmed_at": "now()",
        }).eq("id", payment_row["id"]).execute()

        try:
            supabase.table("class_members").insert({
                "class_id": payment_row["class_id"],
                "student_id": payment_row["student_id"],
            }).execute()
        except Exception:
            pass  # déjà membre

        try:
            cls = supabase.table("classes").select("teacher_id, name").eq(
                "id", payment_row["class_id"]
            ).execute()
            student = supabase.table("users").select("full_name").eq(
                "id", payment_row["student_id"]
            ).execute()
            if cls.data:
                student_name = student.data[0]["full_name"] if student.data else "Un élève"
                supabase.table("notifications").insert({
                    "user_id": cls.data[0]["teacher_id"],
                    "title": "Paiement reçu !",
                    "body": f"{student_name} a payé pour rejoindre {cls.data[0]['name']}.",
                }).execute()
        except Exception:
            pass
    else:
        supabase.table("payments").update({"status": "failed"}).eq("id", payment_row["id"]).execute()

    return {"received": True}


@router.get("/{payment_id}/status")
def payment_status(payment_id: str, student: dict = Depends(get_current_user)):
    """Permet à l'app de vérifier si un paiement a bien été confirmé (polling si pas de webhook)."""
    res = supabase.table("payments").select("*").eq("id", payment_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Paiement introuvable")
    return res.data[0]


# ---------------------------------------------------------------------------
# PORTEFEUILLE ENSEIGNANT (solde, historique, retraits)
# ---------------------------------------------------------------------------

@router.post("/payout-phone")
def set_payout_phone(phone: str, teacher: dict = Depends(require_teacher)):
    """Enregistre/met à jour le numéro mobile money de l'enseignant pour recevoir ses retraits."""
    supabase.table("users").update({"payout_phone": phone}).eq("id", teacher["id"]).execute()
    return {"message": "Numéro enregistré", "payout_phone": phone}


def _compute_wallet(teacher_id: str) -> dict:
    classes = supabase.table("classes").select("id, currency").eq("teacher_id", teacher_id).execute()
    class_ids = [c["id"] for c in classes.data]
    currency = classes.data[0]["currency"] if classes.data else "XOF"

    total_revenue = 0.0
    if class_ids:
        payments = supabase.table("payments").select("amount").in_("class_id", class_ids).eq(
            "status", "success"
        ).execute()
        total_revenue = sum(float(p["amount"]) for p in payments.data)

    withdrawals = supabase.table("withdrawals").select("amount, status").eq("teacher_id", teacher_id).in_(
        "status", ["pending", "completed"]
    ).execute()
    total_reserved_or_withdrawn = sum(float(w["amount"]) for w in withdrawals.data)

    balance = total_revenue - total_reserved_or_withdrawn

    return {
        "balance": balance,
        "currency": currency,
        "total_revenue": total_revenue,
        "total_withdrawn": total_reserved_or_withdrawn,
        "fee_rate": PLATFORM_FEE_RATE,
    }


@router.get("/wallet")
def get_wallet(teacher: dict = Depends(require_teacher)):
    """Solde disponible de l'enseignant (toutes classes confondues) + total encaissé/retiré."""
    return _compute_wallet(teacher["id"])


@router.post("/withdraw")
def request_withdrawal(payload: WithdrawalCreate, teacher: dict = Depends(require_teacher)):
    """Demande de retrait (mobile money ou carte bancaire). 17% de frais plateforme prélevés."""
    wallet = _compute_wallet(teacher["id"])

    if payload.amount <= 0:
        raise HTTPException(status_code=400, detail="Montant invalide")
    if payload.amount > wallet["balance"]:
        raise HTTPException(status_code=400, detail="Montant supérieur à votre solde disponible")
    if payload.method == "mobile_money" and not payload.phone:
        raise HTTPException(status_code=400, detail="Numéro mobile money requis")
    if payload.method == "card" and not payload.card_info:
        raise HTTPException(status_code=400, detail="Informations de carte requises")

    fee = round(payload.amount * PLATFORM_FEE_RATE, 2)
    net_amount = round(payload.amount - fee, 2)

    withdrawal = supabase.table("withdrawals").insert({
        "teacher_id": teacher["id"],
        "amount": payload.amount,
        "fee_amount": fee,
        "net_amount": net_amount,
        "currency": wallet["currency"],
        "method": payload.method,
        "phone": payload.phone,
        "card_info": payload.card_info,
        "status": "pending",
    }).execute().data[0]

    return {
        "message": "Demande de retrait enregistrée. Vous recevrez votre montant net sous 24h.",
        "withdrawal": withdrawal,
    }


@router.get("/withdrawals")
def list_withdrawals(teacher: dict = Depends(require_teacher)):
    res = supabase.table("withdrawals").select("*").eq("teacher_id", teacher["id"]).order(
        "created_at", desc=True
    ).execute()
    return res.data

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    SUPABASE_URL: str
    SUPABASE_KEY: str
    JWT_SECRET: str
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRE_MINUTES: int = 525600  # 1 an — connexion persistante jusqu'à déconnexion volontaire

    # LeekPay (paiement des classes payantes)
    LEEKPAY_PUBLIC_KEY: str = ""
    LEEKPAY_SECRET_KEY: str = ""
    LEEKPAY_BASE_URL: str = "https://leekpay.fr"
    LEEKPAY_WEBHOOK_URL: str = ""       # URL publique de ton backend + /payments/webhook
    LEEKPAY_RETURN_URL: str = ""        # où rediriger l'élève après paiement réussi
    LEEKPAY_CANCEL_URL: str = ""        # où rediriger l'élève s'il annule

    class Config:
        env_file = ".env"


settings = Settings()

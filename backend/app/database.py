import time
import logging

import httpx
import postgrest
from supabase import create_client, Client

from app.config import settings

logger = logging.getLogger("database")

supabase: Client = create_client(settings.SUPABASE_URL, settings.SUPABASE_KEY)


# ---------------------------------------------------------------------------
# Réessai automatique quand Supabase a fermé une connexion inactive
# ("httpx.RemoteProtocolError: Server disconnected")
# ---------------------------------------------------------------------------
_RETRY_ERRORS = (httpx.RemoteProtocolError, httpx.ConnectError)
_MAX_RETRIES = 3


def _with_retry(original_execute):
    def execute(self, *args, **kwargs):
        for attempt in range(1, _MAX_RETRIES + 1):
            try:
                return original_execute(self, *args, **kwargs)
            except _RETRY_ERRORS as e:
                if attempt == _MAX_RETRIES:
                    raise
                logger.warning(
                    "Connexion Supabase coupée (%s), nouvel essai %d/%d",
                    e, attempt, _MAX_RETRIES - 1,
                )
                time.sleep(0.3 * attempt)
    return execute


# On applique le réessai à tous les types de requêtes (select, insert, update, delete, single...)
for _name in (
    "SyncQueryRequestBuilder",
    "SyncSingleRequestBuilder",
    "SyncMaybeSingleRequestBuilder",
):
    _cls = getattr(postgrest, _name, None)
    if _cls is not None and "execute" in _cls.__dict__:
        _cls.execute = _with_retry(_cls.__dict__["execute"])
        
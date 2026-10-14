ALTER TABLE "app_users"
  ADD COLUMN "password_hash" VARCHAR(100);

CREATE TABLE "auth_sessions" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "user_id" UUID NOT NULL,
  "refresh_token_hash" CHAR(64) NOT NULL,
  "expires_at" TIMESTAMPTZ(6) NOT NULL,
  "revoked_at" TIMESTAMPTZ(6),
  "last_used_at" TIMESTAMPTZ(6),
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "auth_sessions_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "auth_sessions_user_id_fkey"
    FOREIGN KEY ("user_id") REFERENCES "app_users"("id")
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "auth_sessions_valid_expiry" CHECK ("created_at" < "expires_at"),
  CONSTRAINT "auth_sessions_refresh_hash_format"
    CHECK ("refresh_token_hash" ~ '^[a-f0-9]{64}$')
);

CREATE INDEX "auth_sessions_user_id_revoked_at_expires_at_idx"
  ON "auth_sessions"("user_id", "revoked_at", "expires_at");

CREATE INDEX "auth_sessions_expires_at_idx"
  ON "auth_sessions"("expires_at");

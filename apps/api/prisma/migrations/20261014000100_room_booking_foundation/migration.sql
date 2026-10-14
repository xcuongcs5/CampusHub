-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- Required by UUID defaults and GiST equality support for UUID columns.
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "btree_gist";

-- CreateEnum
CREATE TYPE "room_time_block_source" AS ENUM ('OFFICIAL_OCCUPANCY', 'ADMIN_BLOCK', 'ROOM_BOOKING');

-- CreateEnum
CREATE TYPE "room_time_block_state" AS ENUM ('ACTIVE', 'RELEASED');

-- CreateEnum
CREATE TYPE "room_booking_status" AS ENUM ('PENDING_PAYMENT', 'CONFIRMED', 'CHECKED_IN', 'COMPLETED', 'EXPIRED', 'CANCELLED', 'NO_SHOW', 'REVOKED');

-- CreateEnum
CREATE TYPE "check_in_method" AS ENUM ('ROOM_QR', 'STAFF_OVERRIDE');

-- CreateEnum
CREATE TYPE "payment_reference_purpose" AS ENUM ('CHARGE', 'REFUND');

-- CreateEnum
CREATE TYPE "actor_type" AS ENUM ('STUDENT', 'STAFF', 'SYSTEM');

-- CreateEnum
CREATE TYPE "idempotency_state" AS ENUM ('PROCESSING', 'COMPLETED', 'FAILED_FINAL');

-- CreateEnum
CREATE TYPE "outbox_publish_state" AS ENUM ('PENDING', 'PUBLISHED', 'FAILED');

-- CreateTable
CREATE TABLE "institutions" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "code" VARCHAR(50) NOT NULL,
    "name" VARCHAR(200) NOT NULL,
    "timezone" VARCHAR(64) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "institutions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "campuses" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "institution_id" UUID NOT NULL,
    "code" VARCHAR(50) NOT NULL,
    "name" VARCHAR(200) NOT NULL,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "campuses_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "app_users" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "institution_id" UUID NOT NULL,
    "external_ref" VARCHAR(200) NOT NULL,
    "email" VARCHAR(320) NOT NULL,
    "display_name" VARCHAR(200) NOT NULL,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "app_users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "rooms" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "institution_id" UUID NOT NULL,
    "campus_id" UUID NOT NULL,
    "code" VARCHAR(50) NOT NULL,
    "display_name" VARCHAR(200) NOT NULL,
    "capacity" INTEGER NOT NULL,
    "bookable_by_students" BOOLEAN NOT NULL DEFAULT false,
    "opening_policy_reference" VARCHAR(200),
    "active" BOOLEAN NOT NULL DEFAULT true,
    "version" INTEGER NOT NULL DEFAULT 1,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "rooms_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "room_timeline_guards" (
    "room_id" UUID NOT NULL,
    "institution_id" UUID NOT NULL,
    "version" INTEGER NOT NULL DEFAULT 1,

    CONSTRAINT "room_timeline_guards_pkey" PRIMARY KEY ("room_id")
);

-- CreateTable
CREATE TABLE "room_time_blocks" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "institution_id" UUID NOT NULL,
    "campus_id" UUID NOT NULL,
    "room_id" UUID NOT NULL,
    "starts_at" TIMESTAMPTZ(6) NOT NULL,
    "ends_at" TIMESTAMPTZ(6) NOT NULL,
    "time_range" tstzrange,
    "source_type" "room_time_block_source" NOT NULL,
    "source_reference" VARCHAR(200) NOT NULL,
    "state" "room_time_block_state" NOT NULL DEFAULT 'ACTIVE',
    "release_reason" VARCHAR(500),
    "released_at" TIMESTAMPTZ(6),
    "version" INTEGER NOT NULL DEFAULT 1,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "room_time_blocks_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "room_check_in_credentials" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "institution_id" UUID NOT NULL,
    "room_id" UUID NOT NULL,
    "token_hash" BYTEA NOT NULL,
    "active_from" TIMESTAMPTZ(6) NOT NULL,
    "revoked_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "room_check_in_credentials_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "booking_policy_versions" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "institution_id" UUID NOT NULL,
    "scope_type" VARCHAR(30) NOT NULL,
    "scope_reference" VARCHAR(200),
    "version_number" INTEGER NOT NULL,
    "effective_from" TIMESTAMPTZ(6) NOT NULL,
    "effective_until" TIMESTAMPTZ(6),
    "lead_time_minutes" INTEGER NOT NULL,
    "booking_horizon_days" INTEGER NOT NULL,
    "max_duration_minutes" INTEGER NOT NULL,
    "active_booking_limit" INTEGER NOT NULL,
    "payment_hold_minutes" INTEGER NOT NULL,
    "check_in_opens_before_minutes" INTEGER NOT NULL,
    "check_in_closes_after_minutes" INTEGER NOT NULL,
    "full_refund_before_minutes" INTEGER NOT NULL,
    "no_show_refundable" BOOLEAN NOT NULL DEFAULT false,
    "snapshot_schema_version" INTEGER NOT NULL DEFAULT 1,
    "published_by" VARCHAR(200) NOT NULL,
    "published_at" TIMESTAMPTZ(6) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "booking_policy_versions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "room_bookings" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "institution_id" UUID NOT NULL,
    "campus_id" UUID NOT NULL,
    "room_id" UUID NOT NULL,
    "booker_id" UUID NOT NULL,
    "time_block_id" UUID NOT NULL,
    "policy_version_id" UUID NOT NULL,
    "starts_at" TIMESTAMPTZ(6) NOT NULL,
    "ends_at" TIMESTAMPTZ(6) NOT NULL,
    "attendee_count" INTEGER NOT NULL,
    "purpose" VARCHAR(500) NOT NULL,
    "status" "room_booking_status" NOT NULL,
    "hold_expires_at" TIMESTAMPTZ(6),
    "checked_in_at" TIMESTAMPTZ(6),
    "completed_at" TIMESTAMPTZ(6),
    "terminal_reason_code" VARCHAR(100),
    "price_amount_minor" BIGINT NOT NULL,
    "price_currency" CHAR(3) NOT NULL,
    "policy_snapshot" JSONB NOT NULL,
    "version" INTEGER NOT NULL DEFAULT 1,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "room_bookings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "booking_actor_guards" (
    "booker_id" UUID NOT NULL,
    "institution_id" UUID NOT NULL,
    "version" INTEGER NOT NULL DEFAULT 1,

    CONSTRAINT "booking_actor_guards_pkey" PRIMARY KEY ("booker_id")
);

-- CreateTable
CREATE TABLE "booking_status_history" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "institution_id" UUID NOT NULL,
    "booking_id" UUID NOT NULL,
    "from_status" "room_booking_status",
    "to_status" "room_booking_status" NOT NULL,
    "transition_type" VARCHAR(100) NOT NULL,
    "actor_type" "actor_type" NOT NULL,
    "actor_reference" VARCHAR(200) NOT NULL,
    "reason_code" VARCHAR(100),
    "reason_detail" VARCHAR(1000),
    "metadata" JSONB,
    "occurred_at" TIMESTAMPTZ(6) NOT NULL,
    "correlation_id" VARCHAR(128) NOT NULL,
    "causation_id" VARCHAR(128),

    CONSTRAINT "booking_status_history_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "booking_check_ins" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "institution_id" UUID NOT NULL,
    "booking_id" UUID NOT NULL,
    "method" "check_in_method" NOT NULL,
    "credential_id" UUID,
    "actor_reference" VARCHAR(200) NOT NULL,
    "override_reason" VARCHAR(500),
    "checked_in_at" TIMESTAMPTZ(6) NOT NULL,
    "correlation_id" VARCHAR(128) NOT NULL,

    CONSTRAINT "booking_check_ins_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "booking_payment_references" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "institution_id" UUID NOT NULL,
    "booking_id" UUID NOT NULL,
    "payment_reference" VARCHAR(200) NOT NULL,
    "purpose" "payment_reference_purpose" NOT NULL,
    "requested_amount_minor" BIGINT NOT NULL,
    "currency" CHAR(3) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "booking_payment_references_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "idempotency_records" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "institution_id" UUID NOT NULL,
    "actor_id" UUID NOT NULL,
    "operation_scope" VARCHAR(100) NOT NULL,
    "operation_key" VARCHAR(128) NOT NULL,
    "request_fingerprint" BYTEA NOT NULL,
    "state" "idempotency_state" NOT NULL,
    "result_reference" VARCHAR(200),
    "response_snapshot" JSONB,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "completed_at" TIMESTAMPTZ(6),
    "expires_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "idempotency_records_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "outbox_messages" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "institution_id" UUID NOT NULL,
    "aggregate_type" VARCHAR(100) NOT NULL,
    "aggregate_id" UUID NOT NULL,
    "event_type" VARCHAR(150) NOT NULL,
    "event_version" INTEGER NOT NULL DEFAULT 1,
    "payload" JSONB NOT NULL,
    "occurred_at" TIMESTAMPTZ(6) NOT NULL,
    "correlation_id" VARCHAR(128) NOT NULL,
    "causation_id" VARCHAR(128),
    "publish_state" "outbox_publish_state" NOT NULL DEFAULT 'PENDING',
    "attempt_count" INTEGER NOT NULL DEFAULT 0,
    "next_attempt_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "published_at" TIMESTAMPTZ(6),
    "last_error" VARCHAR(1000),

    CONSTRAINT "outbox_messages_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "audit_records" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "institution_id" UUID NOT NULL,
    "actor_type" "actor_type" NOT NULL,
    "actor_reference" VARCHAR(200) NOT NULL,
    "action" VARCHAR(150) NOT NULL,
    "subject_type" VARCHAR(100) NOT NULL,
    "subject_reference" VARCHAR(200) NOT NULL,
    "reason_code" VARCHAR(100),
    "before_summary" JSONB,
    "after_summary" JSONB,
    "occurred_at" TIMESTAMPTZ(6) NOT NULL,
    "correlation_id" VARCHAR(128) NOT NULL,

    CONSTRAINT "audit_records_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "institutions_code_key" ON "institutions"("code");

-- CreateIndex
CREATE INDEX "campuses_institution_id_active_idx" ON "campuses"("institution_id", "active");

-- CreateIndex
CREATE UNIQUE INDEX "campuses_institution_id_code_key" ON "campuses"("institution_id", "code");

-- CreateIndex
CREATE INDEX "app_users_institution_id_active_idx" ON "app_users"("institution_id", "active");

-- CreateIndex
CREATE UNIQUE INDEX "app_users_institution_id_external_ref_key" ON "app_users"("institution_id", "external_ref");

-- CreateIndex
CREATE UNIQUE INDEX "app_users_institution_id_email_key" ON "app_users"("institution_id", "email");

-- CreateIndex
CREATE INDEX "rooms_institution_id_campus_id_active_bookable_by_students_idx" ON "rooms"("institution_id", "campus_id", "active", "bookable_by_students");

-- CreateIndex
CREATE UNIQUE INDEX "rooms_campus_id_code_key" ON "rooms"("campus_id", "code");

-- CreateIndex
CREATE INDEX "room_timeline_guards_institution_id_idx" ON "room_timeline_guards"("institution_id");

-- CreateIndex
CREATE INDEX "room_time_blocks_institution_id_room_id_state_idx" ON "room_time_blocks"("institution_id", "room_id", "state");

-- CreateIndex
CREATE INDEX "room_time_blocks_institution_id_source_type_source_referenc_idx" ON "room_time_blocks"("institution_id", "source_type", "source_reference");

-- CreateIndex
CREATE INDEX "room_check_in_credentials_institution_id_room_id_revoked_at_idx" ON "room_check_in_credentials"("institution_id", "room_id", "revoked_at");

-- CreateIndex
CREATE INDEX "booking_policy_versions_institution_id_scope_type_scope_ref_idx" ON "booking_policy_versions"("institution_id", "scope_type", "scope_reference", "effective_from", "effective_until");

-- CreateIndex
CREATE UNIQUE INDEX "booking_policy_versions_institution_id_scope_type_scope_ref_key"
  ON "booking_policy_versions"("institution_id", "scope_type", "scope_reference", "version_number")
  NULLS NOT DISTINCT;

-- CreateIndex
CREATE UNIQUE INDEX "room_bookings_time_block_id_key" ON "room_bookings"("time_block_id");

-- CreateIndex
CREATE INDEX "room_bookings_institution_id_booker_id_status_starts_at_idx" ON "room_bookings"("institution_id", "booker_id", "status", "starts_at");

-- CreateIndex
CREATE INDEX "room_bookings_institution_id_campus_id_starts_at_ends_at_st_idx" ON "room_bookings"("institution_id", "campus_id", "starts_at", "ends_at", "status");

-- CreateIndex
CREATE INDEX "room_bookings_institution_id_room_id_starts_at_ends_at_stat_idx" ON "room_bookings"("institution_id", "room_id", "starts_at", "ends_at", "status");

-- CreateIndex
CREATE INDEX "room_bookings_status_hold_expires_at_idx" ON "room_bookings"("status", "hold_expires_at");

-- CreateIndex
CREATE INDEX "room_bookings_status_starts_at_idx" ON "room_bookings"("status", "starts_at");

-- CreateIndex
CREATE INDEX "room_bookings_status_ends_at_idx" ON "room_bookings"("status", "ends_at");

-- CreateIndex
CREATE INDEX "booking_actor_guards_institution_id_idx" ON "booking_actor_guards"("institution_id");

-- CreateIndex
CREATE INDEX "booking_status_history_institution_id_booking_id_occurred_a_idx" ON "booking_status_history"("institution_id", "booking_id", "occurred_at");

-- CreateIndex
CREATE UNIQUE INDEX "booking_check_ins_booking_id_key" ON "booking_check_ins"("booking_id");

-- CreateIndex
CREATE INDEX "booking_check_ins_institution_id_checked_in_at_idx" ON "booking_check_ins"("institution_id", "checked_in_at");

-- CreateIndex
CREATE UNIQUE INDEX "booking_payment_references_payment_reference_key" ON "booking_payment_references"("payment_reference");

-- CreateIndex
CREATE INDEX "booking_payment_references_institution_id_booking_id_purpos_idx" ON "booking_payment_references"("institution_id", "booking_id", "purpose");

-- CreateIndex
CREATE INDEX "idempotency_records_state_expires_at_idx" ON "idempotency_records"("state", "expires_at");

-- CreateIndex
CREATE UNIQUE INDEX "idempotency_records_institution_id_actor_id_operation_scope_key" ON "idempotency_records"("institution_id", "actor_id", "operation_scope", "operation_key");

-- CreateIndex
CREATE INDEX "outbox_messages_publish_state_next_attempt_at_idx" ON "outbox_messages"("publish_state", "next_attempt_at");

-- CreateIndex
CREATE INDEX "outbox_messages_institution_id_aggregate_type_aggregate_id__idx" ON "outbox_messages"("institution_id", "aggregate_type", "aggregate_id", "occurred_at");

-- CreateIndex
CREATE INDEX "audit_records_institution_id_subject_type_subject_reference_idx" ON "audit_records"("institution_id", "subject_type", "subject_reference", "occurred_at");

-- CreateIndex
CREATE INDEX "audit_records_institution_id_actor_reference_occurred_at_idx" ON "audit_records"("institution_id", "actor_reference", "occurred_at");

-- AddForeignKey
ALTER TABLE "campuses" ADD CONSTRAINT "campuses_institution_id_fkey" FOREIGN KEY ("institution_id") REFERENCES "institutions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "app_users" ADD CONSTRAINT "app_users_institution_id_fkey" FOREIGN KEY ("institution_id") REFERENCES "institutions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "rooms" ADD CONSTRAINT "rooms_institution_id_fkey" FOREIGN KEY ("institution_id") REFERENCES "institutions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "rooms" ADD CONSTRAINT "rooms_campus_id_fkey" FOREIGN KEY ("campus_id") REFERENCES "campuses"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "room_timeline_guards" ADD CONSTRAINT "room_timeline_guards_institution_id_fkey" FOREIGN KEY ("institution_id") REFERENCES "institutions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "room_timeline_guards" ADD CONSTRAINT "room_timeline_guards_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "room_time_blocks" ADD CONSTRAINT "room_time_blocks_institution_id_fkey" FOREIGN KEY ("institution_id") REFERENCES "institutions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "room_time_blocks" ADD CONSTRAINT "room_time_blocks_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "rooms"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "room_check_in_credentials" ADD CONSTRAINT "room_check_in_credentials_institution_id_fkey" FOREIGN KEY ("institution_id") REFERENCES "institutions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "room_check_in_credentials" ADD CONSTRAINT "room_check_in_credentials_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "rooms"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "booking_policy_versions" ADD CONSTRAINT "booking_policy_versions_institution_id_fkey" FOREIGN KEY ("institution_id") REFERENCES "institutions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "room_bookings" ADD CONSTRAINT "room_bookings_institution_id_fkey" FOREIGN KEY ("institution_id") REFERENCES "institutions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "room_bookings" ADD CONSTRAINT "room_bookings_campus_id_fkey" FOREIGN KEY ("campus_id") REFERENCES "campuses"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "room_bookings" ADD CONSTRAINT "room_bookings_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "rooms"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "room_bookings" ADD CONSTRAINT "room_bookings_booker_id_fkey" FOREIGN KEY ("booker_id") REFERENCES "app_users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "room_bookings" ADD CONSTRAINT "room_bookings_time_block_id_fkey" FOREIGN KEY ("time_block_id") REFERENCES "room_time_blocks"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "room_bookings" ADD CONSTRAINT "room_bookings_policy_version_id_fkey" FOREIGN KEY ("policy_version_id") REFERENCES "booking_policy_versions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "booking_actor_guards" ADD CONSTRAINT "booking_actor_guards_institution_id_fkey" FOREIGN KEY ("institution_id") REFERENCES "institutions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "booking_actor_guards" ADD CONSTRAINT "booking_actor_guards_booker_id_fkey" FOREIGN KEY ("booker_id") REFERENCES "app_users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "booking_status_history" ADD CONSTRAINT "booking_status_history_institution_id_fkey" FOREIGN KEY ("institution_id") REFERENCES "institutions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "booking_status_history" ADD CONSTRAINT "booking_status_history_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "room_bookings"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "booking_check_ins" ADD CONSTRAINT "booking_check_ins_institution_id_fkey" FOREIGN KEY ("institution_id") REFERENCES "institutions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "booking_check_ins" ADD CONSTRAINT "booking_check_ins_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "room_bookings"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "booking_check_ins" ADD CONSTRAINT "booking_check_ins_credential_id_fkey" FOREIGN KEY ("credential_id") REFERENCES "room_check_in_credentials"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "booking_payment_references" ADD CONSTRAINT "booking_payment_references_institution_id_fkey" FOREIGN KEY ("institution_id") REFERENCES "institutions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "booking_payment_references" ADD CONSTRAINT "booking_payment_references_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "room_bookings"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "idempotency_records" ADD CONSTRAINT "idempotency_records_institution_id_fkey" FOREIGN KEY ("institution_id") REFERENCES "institutions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "idempotency_records" ADD CONSTRAINT "idempotency_records_actor_id_fkey" FOREIGN KEY ("actor_id") REFERENCES "app_users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "outbox_messages" ADD CONSTRAINT "outbox_messages_institution_id_fkey" FOREIGN KEY ("institution_id") REFERENCES "institutions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "audit_records" ADD CONSTRAINT "audit_records_institution_id_fkey" FOREIGN KEY ("institution_id") REFERENCES "institutions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- Domain checks that Prisma cannot express.
ALTER TABLE "rooms"
  ADD CONSTRAINT "rooms_capacity_positive" CHECK ("capacity" > 0),
  ADD CONSTRAINT "rooms_version_positive" CHECK ("version" > 0);

ALTER TABLE "room_time_blocks"
  ADD CONSTRAINT "room_time_blocks_valid_range" CHECK ("starts_at" < "ends_at"),
  ADD CONSTRAINT "room_time_blocks_range_materialized" CHECK ("time_range" IS NOT NULL),
  ADD CONSTRAINT "room_time_blocks_release_consistency" CHECK (
    ("state" = 'ACTIVE' AND "released_at" IS NULL)
    OR ("state" = 'RELEASED' AND "released_at" IS NOT NULL)
  ),
  ADD CONSTRAINT "room_time_blocks_version_positive" CHECK ("version" > 0);

ALTER TABLE "booking_policy_versions"
  ADD CONSTRAINT "booking_policy_versions_valid_effective_range" CHECK (
    "effective_until" IS NULL OR "effective_from" < "effective_until"
  ),
  ADD CONSTRAINT "booking_policy_versions_positive_values" CHECK (
    "version_number" > 0
    AND "lead_time_minutes" >= 0
    AND "booking_horizon_days" > 0
    AND "max_duration_minutes" > 0
    AND "active_booking_limit" > 0
    AND "payment_hold_minutes" > 0
    AND "check_in_opens_before_minutes" >= 0
    AND "check_in_closes_after_minutes" >= 0
    AND "full_refund_before_minutes" >= 0
    AND "snapshot_schema_version" > 0
  );

ALTER TABLE "room_bookings"
  ADD CONSTRAINT "room_bookings_valid_range" CHECK ("starts_at" < "ends_at"),
  ADD CONSTRAINT "room_bookings_attendee_count_positive" CHECK ("attendee_count" > 0),
  ADD CONSTRAINT "room_bookings_price_non_negative" CHECK ("price_amount_minor" >= 0),
  ADD CONSTRAINT "room_bookings_currency_format" CHECK ("price_currency" ~ '^[A-Z]{3}$'),
  ADD CONSTRAINT "room_bookings_policy_snapshot_object" CHECK (jsonb_typeof("policy_snapshot") = 'object'),
  ADD CONSTRAINT "room_bookings_pending_payment_has_deadline" CHECK (
    "status" <> 'PENDING_PAYMENT' OR "hold_expires_at" IS NOT NULL
  ),
  ADD CONSTRAINT "room_bookings_version_positive" CHECK ("version" > 0);

ALTER TABLE "booking_check_ins"
  ADD CONSTRAINT "booking_check_ins_method_consistency" CHECK (
    ("method" = 'ROOM_QR' AND "credential_id" IS NOT NULL AND "override_reason" IS NULL)
    OR (
      "method" = 'STAFF_OVERRIDE'
      AND "credential_id" IS NULL
      AND "override_reason" IS NOT NULL
      AND length(trim("override_reason")) > 0
    )
  );

ALTER TABLE "booking_payment_references"
  ADD CONSTRAINT "booking_payment_references_amount_non_negative" CHECK ("requested_amount_minor" >= 0),
  ADD CONSTRAINT "booking_payment_references_currency_format" CHECK ("currency" ~ '^[A-Z]{3}$');

ALTER TABLE "idempotency_records"
  ADD CONSTRAINT "idempotency_records_valid_expiry" CHECK ("created_at" < "expires_at"),
  ADD CONSTRAINT "idempotency_records_completion_consistency" CHECK (
    ("state" = 'PROCESSING' AND "completed_at" IS NULL)
    OR ("state" <> 'PROCESSING' AND "completed_at" IS NOT NULL)
  );

ALTER TABLE "outbox_messages"
  ADD CONSTRAINT "outbox_messages_attempt_count_non_negative" CHECK ("attempt_count" >= 0),
  ADD CONSTRAINT "outbox_messages_payload_object" CHECK (jsonb_typeof("payload") = 'object');

-- One booking owns one booking time block reference.
CREATE UNIQUE INDEX "room_time_blocks_booking_source_unique"
  ON "room_time_blocks" ("institution_id", "source_reference")
  WHERE "source_type" = 'ROOM_BOOKING';

CREATE UNIQUE INDEX "room_check_in_credentials_active_room_unique"
  ON "room_check_in_credentials" ("institution_id", "room_id")
  WHERE "revoked_at" IS NULL;

CREATE UNIQUE INDEX "room_check_in_credentials_token_hash_unique"
  ON "room_check_in_credentials" ("token_hash");

-- Efficient availability lookup. The partial GiST constraint is defense-in-depth for
-- booking-vs-booking overlap; the trigger below also protects booking-vs-official/admin.
CREATE INDEX "room_time_blocks_active_range_gist"
  ON "room_time_blocks" USING gist ("institution_id", "room_id", "time_range")
  WHERE "state" = 'ACTIVE';

ALTER TABLE "room_time_blocks"
  ADD CONSTRAINT "room_time_blocks_no_booking_overlap"
  EXCLUDE USING gist (
    "institution_id" WITH =,
    "room_id" WITH =,
    "time_range" WITH &&
  )
  WHERE ("state" = 'ACTIVE' AND "source_type" = 'ROOM_BOOKING')
  DEFERRABLE INITIALLY IMMEDIATE;

-- Worker indexes only contain actionable rows.
CREATE INDEX "room_bookings_pending_payment_expiry_idx"
  ON "room_bookings" ("hold_expires_at", "id")
  WHERE "status" = 'PENDING_PAYMENT';

CREATE INDEX "room_bookings_confirmed_no_show_idx"
  ON "room_bookings" ("starts_at", "id")
  WHERE "status" = 'CONFIRMED';

CREATE INDEX "room_bookings_checked_in_completion_idx"
  ON "room_bookings" ("ends_at", "id")
  WHERE "status" = 'CHECKED_IN';

CREATE INDEX "outbox_messages_pending_dispatch_idx"
  ON "outbox_messages" ("next_attempt_at", "id")
  WHERE "publish_state" IN ('PENDING', 'FAILED');

-- Guard creation is database-owned so every room/user has a row that can be locked.
CREATE OR REPLACE FUNCTION "create_room_timeline_guard"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO "room_timeline_guards" ("room_id", "institution_id", "version")
  VALUES (NEW."id", NEW."institution_id", 1);
  RETURN NEW;
END;
$$;

CREATE TRIGGER "rooms_create_timeline_guard"
AFTER INSERT ON "rooms"
FOR EACH ROW EXECUTE FUNCTION "create_room_timeline_guard"();

CREATE OR REPLACE FUNCTION "create_booking_actor_guard"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO "booking_actor_guards" ("booker_id", "institution_id", "version")
  VALUES (NEW."id", NEW."institution_id", 1);
  RETURN NEW;
END;
$$;

CREATE TRIGGER "app_users_create_booking_actor_guard"
AFTER INSERT ON "app_users"
FOR EACH ROW EXECUTE FUNCTION "create_booking_actor_guard"();

-- Validate Room belongs to its Institution.
CREATE OR REPLACE FUNCTION "validate_room_tenant_scope"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM "campuses" c
    WHERE c."id" = NEW."campus_id"
      AND c."institution_id" = NEW."institution_id"
  ) THEN
    RAISE EXCEPTION 'Room campus must belong to the same institution'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER "rooms_validate_tenant_scope"
BEFORE INSERT OR UPDATE OF "institution_id", "campus_id" ON "rooms"
FOR EACH ROW EXECUTE FUNCTION "validate_room_tenant_scope"();

-- Serialize every Room timeline mutation and enforce cross-source overlap rules.
CREATE OR REPLACE FUNCTION "prepare_and_validate_room_time_block"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM "rooms" r
    WHERE r."id" = NEW."room_id"
      AND r."institution_id" = NEW."institution_id"
      AND r."campus_id" = NEW."campus_id"
  ) THEN
    RAISE EXCEPTION 'Time block room/campus must belong to the same institution'
      USING ERRCODE = '23514';
  END IF;

  PERFORM 1
  FROM "room_timeline_guards" g
  WHERE g."room_id" = NEW."room_id"
    AND g."institution_id" = NEW."institution_id"
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Room timeline guard is missing' USING ERRCODE = '23503';
  END IF;

  NEW."time_range" := tstzrange(NEW."starts_at", NEW."ends_at", '[)');

  IF NEW."state" = 'ACTIVE' AND EXISTS (
    SELECT 1
    FROM "room_time_blocks" existing
    WHERE existing."institution_id" = NEW."institution_id"
      AND existing."room_id" = NEW."room_id"
      AND existing."id" <> NEW."id"
      AND existing."state" = 'ACTIVE'
      AND existing."time_range" && NEW."time_range"
      AND (
        NEW."source_type" = 'ROOM_BOOKING'
        OR existing."source_type" = 'ROOM_BOOKING'
      )
  ) THEN
    RAISE EXCEPTION 'Active booking time block overlaps another active block'
      USING ERRCODE = '23P01';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER "room_time_blocks_prepare_and_validate"
BEFORE INSERT OR UPDATE OF
  "institution_id", "campus_id", "room_id", "starts_at", "ends_at", "source_type", "state"
ON "room_time_blocks"
FOR EACH ROW EXECUTE FUNCTION "prepare_and_validate_room_time_block"();

-- Validate all cross-module references of a Booking are tenant-consistent and that the
-- linked time block is the immutable slot claimed by this Booking.
CREATE OR REPLACE FUNCTION "validate_room_booking_scope"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM "rooms" r
    JOIN "campuses" c ON c."id" = NEW."campus_id"
    WHERE r."id" = NEW."room_id"
      AND r."campus_id" = NEW."campus_id"
      AND r."institution_id" = NEW."institution_id"
      AND c."institution_id" = NEW."institution_id"
  ) THEN
    RAISE EXCEPTION 'Booking room/campus scope is inconsistent' USING ERRCODE = '23514';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM "app_users" u
    WHERE u."id" = NEW."booker_id" AND u."institution_id" = NEW."institution_id"
  ) THEN
    RAISE EXCEPTION 'Booking booker belongs to another institution' USING ERRCODE = '23514';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM "booking_policy_versions" p
    WHERE p."id" = NEW."policy_version_id" AND p."institution_id" = NEW."institution_id"
  ) THEN
    RAISE EXCEPTION 'Booking policy belongs to another institution' USING ERRCODE = '23514';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM "room_time_blocks" b
    WHERE b."id" = NEW."time_block_id"
      AND b."institution_id" = NEW."institution_id"
      AND b."room_id" = NEW."room_id"
      AND b."campus_id" = NEW."campus_id"
      AND b."source_type" = 'ROOM_BOOKING'
      AND b."source_reference" = NEW."id"::text
      AND b."starts_at" = NEW."starts_at"
      AND b."ends_at" = NEW."ends_at"
  ) THEN
    RAISE EXCEPTION 'Booking time block is inconsistent' USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$$;

CREATE CONSTRAINT TRIGGER "room_bookings_validate_scope"
AFTER INSERT OR UPDATE OF
  "institution_id", "campus_id", "room_id", "booker_id", "time_block_id",
  "policy_version_id", "starts_at", "ends_at"
ON "room_bookings"
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION "validate_room_booking_scope"();

-- Generic tenant validation for child facts that reference a Booking.
CREATE OR REPLACE FUNCTION "validate_booking_child_tenant"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM "room_bookings" b
    WHERE b."id" = NEW."booking_id" AND b."institution_id" = NEW."institution_id"
  ) THEN
    RAISE EXCEPTION 'Booking child belongs to another institution' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER "booking_status_history_validate_tenant"
BEFORE INSERT ON "booking_status_history"
FOR EACH ROW EXECUTE FUNCTION "validate_booking_child_tenant"();

CREATE TRIGGER "booking_check_ins_validate_tenant"
BEFORE INSERT OR UPDATE OF "institution_id", "booking_id" ON "booking_check_ins"
FOR EACH ROW EXECUTE FUNCTION "validate_booking_child_tenant"();

CREATE TRIGGER "booking_payment_references_validate_tenant"
BEFORE INSERT OR UPDATE OF "institution_id", "booking_id" ON "booking_payment_references"
FOR EACH ROW EXECUTE FUNCTION "validate_booking_child_tenant"();

-- Append-only lifecycle and audit records.
CREATE OR REPLACE FUNCTION "reject_mutation_of_append_only_record"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION '% is append-only', TG_TABLE_NAME USING ERRCODE = '55000';
END;
$$;

CREATE TRIGGER "booking_status_history_append_only"
BEFORE UPDATE OR DELETE ON "booking_status_history"
FOR EACH ROW EXECUTE FUNCTION "reject_mutation_of_append_only_record"();

CREATE TRIGGER "audit_records_append_only"
BEFORE UPDATE OR DELETE ON "audit_records"
FOR EACH ROW EXECUTE FUNCTION "reject_mutation_of_append_only_record"();

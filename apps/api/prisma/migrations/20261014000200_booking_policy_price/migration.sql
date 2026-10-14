-- A policy owns the price used to decide whether a booking is confirmed
-- immediately or held while its payment session is initialized.
ALTER TABLE "booking_policy_versions"
  ADD COLUMN "price_amount_minor" BIGINT NOT NULL DEFAULT 0,
  ADD COLUMN "price_currency" CHAR(3) NOT NULL DEFAULT 'VND';

ALTER TABLE "booking_policy_versions"
  ADD CONSTRAINT "booking_policy_versions_price_non_negative"
    CHECK ("price_amount_minor" >= 0),
  ADD CONSTRAINT "booking_policy_versions_currency_format"
    CHECK ("price_currency" ~ '^[A-Z]{3}$');

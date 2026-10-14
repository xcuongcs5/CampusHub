\set ON_ERROR_STOP on

BEGIN;

INSERT INTO institutions (id, code, name, timezone, updated_at)
VALUES
  ('10000000-0000-0000-0000-000000000001', 'UNI_A', 'University A', 'Asia/Ho_Chi_Minh', now()),
  ('10000000-0000-0000-0000-000000000002', 'UNI_B', 'University B', 'Asia/Ho_Chi_Minh', now());

INSERT INTO campuses (id, institution_id, code, name, updated_at)
VALUES
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'MAIN', 'Main Campus', now()),
  ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', 'OTHER', 'Other Campus', now());

DO $$
BEGIN
  BEGIN
    INSERT INTO rooms (
      id, institution_id, campus_id, code, display_name, capacity, updated_at
    ) VALUES (
      '30000000-0000-0000-0000-000000000099',
      '10000000-0000-0000-0000-000000000001',
      '20000000-0000-0000-0000-000000000002',
      'INVALID', 'Cross tenant room', 4, now()
    );
    RAISE EXCEPTION 'Expected cross-tenant Room insert to fail';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'PASS: cross-tenant Room rejected';
  END;
END;
$$;

INSERT INTO rooms (
  id, institution_id, campus_id, code, display_name, capacity,
  bookable_by_students, updated_at
) VALUES
  (
    '30000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    'A101', 'Room A101', 20, true, now()
  ),
  (
    '30000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    'A102', 'Room A102', 20, true, now()
  );

DO $$
BEGIN
  IF (SELECT count(*) FROM room_timeline_guards) <> 2 THEN
    RAISE EXCEPTION 'Room timeline guards were not created';
  END IF;
  RAISE NOTICE 'PASS: Room timeline guards auto-created';
END;
$$;

INSERT INTO app_users (
  id, institution_id, external_ref, email, display_name, updated_at
) VALUES (
  '40000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  'student-001', 'student@example.edu.vn', 'Student One', now()
);

DO $$
BEGIN
  IF (SELECT count(*) FROM booking_actor_guards) <> 1 THEN
    RAISE EXCEPTION 'Booking actor guard was not created';
  END IF;
  RAISE NOTICE 'PASS: Booking actor guard auto-created';
END;
$$;

INSERT INTO booking_policy_versions (
  id, institution_id, scope_type, version_number, effective_from,
  lead_time_minutes, booking_horizon_days, max_duration_minutes,
  active_booking_limit, payment_hold_minutes, check_in_opens_before_minutes,
  check_in_closes_after_minutes, full_refund_before_minutes,
  published_by, published_at
) VALUES (
  '50000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  'INSTITUTION', 1, now(), 30, 30, 120, 2, 10, 15, 15, 120,
  'system', now()
);

-- Non-booking blockers may overlap.
INSERT INTO room_time_blocks (
  id, institution_id, campus_id, room_id, starts_at, ends_at,
  source_type, source_reference, updated_at
) VALUES
  (
    '60000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000001',
    '2026-10-20 09:00:00+07', '2026-10-20 11:00:00+07',
    'OFFICIAL_OCCUPANCY', 'class-001', now()
  ),
  (
    '60000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000001',
    '2026-10-20 10:00:00+07', '2026-10-20 12:00:00+07',
    'ADMIN_BLOCK', 'maintenance-001', now()
  );

DO $$
BEGIN
  RAISE NOTICE 'PASS: official and admin blockers may overlap';
END;
$$;

-- Create a valid booking claim and aggregate for Room A102.
INSERT INTO room_time_blocks (
  id, institution_id, campus_id, room_id, starts_at, ends_at,
  source_type, source_reference, updated_at
) VALUES (
  '60000000-0000-0000-0000-000000000003',
  '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000002',
  '2026-10-21 09:00:00+07', '2026-10-21 11:00:00+07',
  'ROOM_BOOKING', '70000000-0000-0000-0000-000000000001', now()
);

INSERT INTO room_bookings (
  id, institution_id, campus_id, room_id, booker_id, time_block_id,
  policy_version_id, starts_at, ends_at, attendee_count, purpose, status,
  hold_expires_at, price_amount_minor, price_currency, policy_snapshot, updated_at
) VALUES (
  '70000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000002',
  '40000000-0000-0000-0000-000000000001',
  '60000000-0000-0000-0000-000000000003',
  '50000000-0000-0000-0000-000000000001',
  '2026-10-21 09:00:00+07', '2026-10-21 11:00:00+07',
  4, 'Constraint smoke test', 'PENDING_PAYMENT', now() + interval '10 minutes',
  50000, 'VND', '{"schema_version":1}'::jsonb, now()
);

SET CONSTRAINTS ALL IMMEDIATE;

DO $$
BEGIN
  BEGIN
    INSERT INTO room_time_blocks (
      id, institution_id, campus_id, room_id, starts_at, ends_at,
      source_type, source_reference, updated_at
    ) VALUES (
      '60000000-0000-0000-0000-000000000004',
      '10000000-0000-0000-0000-000000000001',
      '20000000-0000-0000-0000-000000000001',
      '30000000-0000-0000-0000-000000000002',
      '2026-10-21 10:00:00+07', '2026-10-21 12:00:00+07',
      'ROOM_BOOKING', '70000000-0000-0000-0000-000000000002', now()
    );
    RAISE EXCEPTION 'Expected overlapping booking block to fail';
  EXCEPTION WHEN exclusion_violation THEN
    RAISE NOTICE 'PASS: overlapping booking rejected';
  END;

  BEGIN
    INSERT INTO room_time_blocks (
      id, institution_id, campus_id, room_id, starts_at, ends_at,
      source_type, source_reference, updated_at
    ) VALUES (
      '60000000-0000-0000-0000-000000000005',
      '10000000-0000-0000-0000-000000000001',
      '20000000-0000-0000-0000-000000000001',
      '30000000-0000-0000-0000-000000000002',
      '2026-10-21 10:00:00+07', '2026-10-21 12:00:00+07',
      'ADMIN_BLOCK', 'maintenance-002', now()
    );
    RAISE EXCEPTION 'Expected blocker overlapping active booking to fail';
  EXCEPTION WHEN exclusion_violation THEN
    RAISE NOTICE 'PASS: blocker overlapping active booking rejected';
  END;
END;
$$;

INSERT INTO booking_status_history (
  id, institution_id, booking_id, to_status, transition_type,
  actor_type, actor_reference, occurred_at, correlation_id
) VALUES (
  '80000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  '70000000-0000-0000-0000-000000000001',
  'PENDING_PAYMENT', 'BOOKING_HELD', 'STUDENT',
  '40000000-0000-0000-0000-000000000001', now(), 'constraint-smoke-test'
);

DO $$
BEGIN
  BEGIN
    UPDATE booking_status_history
    SET reason_code = 'ILLEGAL_MUTATION'
    WHERE id = '80000000-0000-0000-0000-000000000001';
    RAISE EXCEPTION 'Expected append-only update to fail';
  EXCEPTION WHEN object_not_in_prerequisite_state THEN
    RAISE NOTICE 'PASS: status history is append-only';
  END;
END;
$$;

ROLLBACK;


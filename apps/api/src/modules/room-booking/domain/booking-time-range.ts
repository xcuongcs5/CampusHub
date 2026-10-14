import { RoomBookingError } from "./room-booking.errors";

const MILLISECONDS_PER_MINUTE = 60_000;
const MILLISECONDS_PER_DAY = 86_400_000;

export interface BookingTimePolicy {
  leadTimeMinutes: number;
  bookingHorizonDays: number;
  maxDurationMinutes: number;
}

export class BookingTimeRange {
  private constructor(
    readonly startsAt: Date,
    readonly endsAt: Date,
  ) {}

  static create(
    startsAt: Date,
    endsAt: Date,
    now: Date,
    policy: BookingTimePolicy,
  ): BookingTimeRange {
    const start = startsAt.getTime();
    const end = endsAt.getTime();
    const current = now.getTime();

    if (!Number.isFinite(start) || !Number.isFinite(end) || start >= end) {
      throw new RoomBookingError(
        "INVALID_TIME_RANGE",
        "Booking start time must be before end time.",
      );
    }

    const earliestStart =
      current + policy.leadTimeMinutes * MILLISECONDS_PER_MINUTE;
    if (start < earliestStart) {
      throw new RoomBookingError(
        "BOOKING_TOO_SOON",
        "Booking does not satisfy the minimum lead time.",
        { earliestStart: new Date(earliestStart).toISOString() },
      );
    }

    const latestStart =
      current + policy.bookingHorizonDays * MILLISECONDS_PER_DAY;
    if (start > latestStart) {
      throw new RoomBookingError(
        "BOOKING_TOO_FAR_AHEAD",
        "Booking exceeds the configured booking horizon.",
        { latestStart: new Date(latestStart).toISOString() },
      );
    }

    const durationMinutes = (end - start) / MILLISECONDS_PER_MINUTE;
    if (durationMinutes > policy.maxDurationMinutes) {
      throw new RoomBookingError(
        "BOOKING_DURATION_EXCEEDED",
        "Booking duration exceeds the configured maximum.",
        { maxDurationMinutes: policy.maxDurationMinutes },
      );
    }

    return new BookingTimeRange(new Date(start), new Date(end));
  }

  get durationMinutes(): number {
    return (
      (this.endsAt.getTime() - this.startsAt.getTime()) /
      MILLISECONDS_PER_MINUTE
    );
  }
}

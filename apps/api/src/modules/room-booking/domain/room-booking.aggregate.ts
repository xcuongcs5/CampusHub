import { BookingTimeRange } from "./booking-time-range";
import { RoomBookingError } from "./room-booking.errors";
import {
  BookableRoomSnapshot,
  RoomBookingDomainEvent,
  RoomBookingPolicySnapshot,
  RoomBookingStatus,
} from "./room-booking.types";

export interface CreateRoomBookingProps {
  bookingId: string;
  timeBlockId: string;
  institutionId: string;
  bookerId: string;
  room: BookableRoomSnapshot;
  policy: RoomBookingPolicySnapshot;
  startsAt: Date;
  endsAt: Date;
  attendeeCount: number;
  purpose: string;
  now: Date;
}

export interface RoomBookingSnapshot {
  bookingId: string;
  timeBlockId: string;
  institutionId: string;
  campusId: string;
  roomId: string;
  bookerId: string;
  policyVersionId: string;
  startsAt: Date;
  endsAt: Date;
  attendeeCount: number;
  purpose: string;
  status: RoomBookingStatus;
  holdExpiresAt?: Date;
  priceAmountMinor: bigint;
  priceCurrency: string;
  policySnapshot: Readonly<Record<string, unknown>>;
  version: number;
  createdAt: Date;
}

export class RoomBooking {
  private readonly events: RoomBookingDomainEvent[] = [];

  private constructor(private readonly state: RoomBookingSnapshot) {}

  static create(props: CreateRoomBookingProps): RoomBooking {
    if (
      props.room.institutionId !== props.institutionId ||
      !props.room.active ||
      !props.room.bookableByStudents
    ) {
      throw new RoomBookingError(
        "ROOM_NOT_BOOKABLE",
        "The selected room is not available for student booking.",
      );
    }

    if (!Number.isInteger(props.attendeeCount) || props.attendeeCount < 1) {
      throw new RoomBookingError(
        "INVALID_ATTENDEE_COUNT",
        "Attendee count must be a positive integer.",
      );
    }

    if (props.attendeeCount > props.room.capacity) {
      throw new RoomBookingError(
        "ROOM_CAPACITY_EXCEEDED",
        "Attendee count exceeds room capacity.",
        { capacity: props.room.capacity },
      );
    }

    const purpose = props.purpose.trim();
    if (purpose.length === 0) {
      throw new RoomBookingError(
        "PURPOSE_REQUIRED",
        "Booking purpose is required.",
      );
    }

    const range = BookingTimeRange.create(
      props.startsAt,
      props.endsAt,
      props.now,
      props.policy,
    );
    const status: RoomBookingStatus = props.policy.price.isFree
      ? "CONFIRMED"
      : "PENDING_PAYMENT";
    const holdExpiresAt = props.policy.price.isFree
      ? undefined
      : new Date(
          props.now.getTime() + props.policy.paymentHoldMinutes * 60_000,
        );

    const booking = new RoomBooking({
      bookingId: props.bookingId,
      timeBlockId: props.timeBlockId,
      institutionId: props.institutionId,
      campusId: props.room.campusId,
      roomId: props.room.roomId,
      bookerId: props.bookerId,
      policyVersionId: props.policy.policyVersionId,
      startsAt: range.startsAt,
      endsAt: range.endsAt,
      attendeeCount: props.attendeeCount,
      purpose,
      status,
      holdExpiresAt,
      priceAmountMinor: props.policy.price.amountMinor,
      priceCurrency: props.policy.price.currency,
      policySnapshot: {
        schemaVersion: props.policy.snapshotSchemaVersion,
        leadTimeMinutes: props.policy.leadTimeMinutes,
        bookingHorizonDays: props.policy.bookingHorizonDays,
        maxDurationMinutes: props.policy.maxDurationMinutes,
        activeBookingLimit: props.policy.activeBookingLimit,
        paymentHoldMinutes: props.policy.paymentHoldMinutes,
        checkInOpensBeforeMinutes: props.policy.checkInOpensBeforeMinutes,
        checkInClosesAfterMinutes: props.policy.checkInClosesAfterMinutes,
        fullRefundBeforeMinutes: props.policy.fullRefundBeforeMinutes,
        noShowRefundable: props.policy.noShowRefundable,
      },
      version: 1,
      createdAt: new Date(props.now),
    });

    booking.events.push(
      status === "CONFIRMED"
        ? {
            eventType: "RoomBookingConfirmed",
            bookingId: props.bookingId,
            institutionId: props.institutionId,
            occurredAt: new Date(props.now),
          }
        : {
            eventType: "RoomBookingHeld",
            bookingId: props.bookingId,
            institutionId: props.institutionId,
            occurredAt: new Date(props.now),
            holdExpiresAt: holdExpiresAt!,
          },
    );

    return booking;
  }

  snapshot(): Readonly<RoomBookingSnapshot> {
    return {
      ...this.state,
      startsAt: new Date(this.state.startsAt),
      endsAt: new Date(this.state.endsAt),
      holdExpiresAt: this.state.holdExpiresAt
        ? new Date(this.state.holdExpiresAt)
        : undefined,
      createdAt: new Date(this.state.createdAt),
    };
  }

  pullEvents(): RoomBookingDomainEvent[] {
    return this.events.splice(0, this.events.length);
  }
}

export type RoomBookingErrorCode =
  | "INVALID_TIME_RANGE"
  | "BOOKING_TOO_SOON"
  | "BOOKING_TOO_FAR_AHEAD"
  | "BOOKING_DURATION_EXCEEDED"
  | "INVALID_ATTENDEE_COUNT"
  | "PURPOSE_REQUIRED"
  | "ROOM_NOT_BOOKABLE"
  | "ROOM_CAPACITY_EXCEEDED"
  | "ACTIVE_BOOKING_LIMIT_REACHED"
  | "BOOKER_NOT_ELIGIBLE"
  | "ROOM_SLOT_UNAVAILABLE"
  | "OPERATION_KEY_INVALID"
  | "OPERATION_KEY_REUSED"
  | "PAYMENT_INITIALIZATION_FAILED";

export class RoomBookingError extends Error {
  constructor(
    readonly code: RoomBookingErrorCode,
    message: string,
    readonly details: Readonly<Record<string, unknown>> = {},
  ) {
    super(message);
    this.name = "RoomBookingError";
  }
}

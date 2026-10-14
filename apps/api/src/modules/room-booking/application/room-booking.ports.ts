import { Money } from "../domain/money";
import {
  RoomBooking,
  RoomBookingSnapshot,
} from "../domain/room-booking.aggregate";
import {
  BookableRoomSnapshot,
  RoomBookingDomainEvent,
  RoomBookingPolicySnapshot,
} from "../domain/room-booking.types";

export interface IdGeneratorPort {
  nextId(): string;
}

export interface ClockPort {
  now(): Date;
}

export interface RoomBookingTransaction {
  lockBooker(bookerId: string): Promise<void>;
  isBookerEligible(bookerId: string): Promise<boolean>;
  countActiveBookings(bookerId: string): Promise<number>;
  getBookableRoom(roomId: string): Promise<BookableRoomSnapshot | null>;
  resolvePolicy(
    room: BookableRoomSnapshot,
    startsAt: Date,
  ): Promise<RoomBookingPolicySnapshot>;
  claimRoomTimeBlock(input: {
    timeBlockId: string;
    bookingId: string;
    institutionId: string;
    campusId: string;
    roomId: string;
    startsAt: Date;
    endsAt: Date;
  }): Promise<void>;
  saveBooking(booking: RoomBooking): Promise<void>;
  appendOutbox(events: RoomBookingDomainEvent[]): Promise<void>;
}

export interface IdempotentOperation {
  institutionId: string;
  actorId: string;
  operationScope: string;
  operationKey: string;
  requestFingerprint: string;
}

export interface RoomBookingUnitOfWorkPort {
  executeIdempotent<T>(
    operation: IdempotentOperation,
    work: (transaction: RoomBookingTransaction) => Promise<T>,
  ): Promise<T>;

  cancelPaymentInitializationFailure(input: {
    bookingId: string;
    operation: IdempotentOperation;
  }): Promise<void>;
}

export interface PaymentAction {
  actionType: "REDIRECT" | "DEEP_LINK";
  actionUrl: string;
  expiresAt: Date;
}

export interface RoomBookingPaymentPort {
  initializeCharge(input: {
    bookingId: string;
    institutionId: string;
    amount: Money;
    holdExpiresAt: Date;
    operationKey: string;
  }): Promise<PaymentAction>;
}

export interface RequestRoomBookingResult {
  booking: Readonly<RoomBookingSnapshot>;
  paymentAction?: PaymentAction;
  replayed?: boolean;
}

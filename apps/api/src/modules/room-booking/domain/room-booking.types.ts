import { Money } from "./money";

export type RoomBookingStatus =
  | "PENDING_PAYMENT"
  | "CONFIRMED"
  | "CHECKED_IN"
  | "COMPLETED"
  | "EXPIRED"
  | "CANCELLED"
  | "NO_SHOW"
  | "REVOKED";

export interface BookableRoomSnapshot {
  institutionId: string;
  campusId: string;
  roomId: string;
  capacity: number;
  active: boolean;
  bookableByStudents: boolean;
}

export interface RoomBookingPolicySnapshot {
  policyVersionId: string;
  snapshotSchemaVersion: number;
  leadTimeMinutes: number;
  bookingHorizonDays: number;
  maxDurationMinutes: number;
  activeBookingLimit: number;
  paymentHoldMinutes: number;
  checkInOpensBeforeMinutes: number;
  checkInClosesAfterMinutes: number;
  fullRefundBeforeMinutes: number;
  noShowRefundable: boolean;
  price: Money;
}

export type RoomBookingDomainEvent =
  | {
      eventType: "RoomBookingHeld";
      bookingId: string;
      institutionId: string;
      occurredAt: Date;
      holdExpiresAt: Date;
    }
  | {
      eventType: "RoomBookingConfirmed";
      bookingId: string;
      institutionId: string;
      occurredAt: Date;
    };

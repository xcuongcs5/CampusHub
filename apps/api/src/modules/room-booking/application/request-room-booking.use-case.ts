import { createHash } from "node:crypto";

import { RoomBooking } from "../domain/room-booking.aggregate";
import { RoomBookingError } from "../domain/room-booking.errors";
import { Money } from "../domain/money";
import {
  ClockPort,
  IdGeneratorPort,
  RequestRoomBookingResult,
  RoomBookingPaymentPort,
  RoomBookingUnitOfWorkPort,
} from "./room-booking.ports";

export interface RequestRoomBookingCommand {
  institutionId: string;
  actorId: string;
  operationKey: string;
  roomId: string;
  startsAt: Date;
  endsAt: Date;
  attendeeCount: number;
  purpose: string;
}

interface PendingPaymentInitialization {
  bookingId: string;
  institutionId: string;
  amountMinor: bigint;
  currency: string;
  holdExpiresAt: Date;
}

interface TransactionResult {
  result: RequestRoomBookingResult;
  pendingPayment?: PendingPaymentInitialization;
}

export class RequestRoomBookingUseCase {
  constructor(
    private readonly unitOfWork: RoomBookingUnitOfWorkPort,
    private readonly payment: RoomBookingPaymentPort,
    private readonly clock: ClockPort,
    private readonly ids: IdGeneratorPort,
  ) {}

  async execute(
    command: RequestRoomBookingCommand,
  ): Promise<RequestRoomBookingResult> {
    this.validateOperationKey(command.operationKey);
    const now = this.clock.now();
    const requestFingerprint = this.fingerprint(command);
    const operation = {
      institutionId: command.institutionId,
      actorId: command.actorId,
      operationScope: "REQUEST_ROOM_BOOKING",
      operationKey: command.operationKey,
      requestFingerprint,
    } as const;

    const transactionResult =
      await this.unitOfWork.executeIdempotent<TransactionResult>(
        operation,
        async (transaction) => {
          await transaction.lockBooker(command.actorId);

          if (!(await transaction.isBookerEligible(command.actorId))) {
            throw new RoomBookingError(
              "BOOKER_NOT_ELIGIBLE",
              "The student is not eligible to book a room.",
            );
          }

          const room = await transaction.getBookableRoom(command.roomId);
          if (!room || room.institutionId !== command.institutionId) {
            throw new RoomBookingError(
              "ROOM_NOT_BOOKABLE",
              "The selected room is not available for student booking.",
            );
          }

          const policy = await transaction.resolvePolicy(
            room,
            command.startsAt,
          );
          const activeBookingCount = await transaction.countActiveBookings(
            command.actorId,
          );
          if (activeBookingCount >= policy.activeBookingLimit) {
            throw new RoomBookingError(
              "ACTIVE_BOOKING_LIMIT_REACHED",
              "The student has reached the active booking limit.",
              { activeBookingLimit: policy.activeBookingLimit },
            );
          }

          const bookingId = this.ids.nextId();
          const timeBlockId = this.ids.nextId();
          const booking = RoomBooking.create({
            bookingId,
            timeBlockId,
            institutionId: command.institutionId,
            bookerId: command.actorId,
            room,
            policy,
            startsAt: command.startsAt,
            endsAt: command.endsAt,
            attendeeCount: command.attendeeCount,
            purpose: command.purpose,
            now,
          });
          const snapshot = booking.snapshot();

          try {
            await transaction.claimRoomTimeBlock({
              timeBlockId,
              bookingId,
              institutionId: command.institutionId,
              campusId: room.campusId,
              roomId: room.roomId,
              startsAt: snapshot.startsAt,
              endsAt: snapshot.endsAt,
            });
          } catch (error: unknown) {
            if (error instanceof RoomBookingError) {
              throw error;
            }
            throw new RoomBookingError(
              "ROOM_SLOT_UNAVAILABLE",
              "The requested room slot is no longer available.",
            );
          }

          await transaction.saveBooking(booking);
          await transaction.appendOutbox(booking.pullEvents());

          return {
            result: { booking: snapshot },
            pendingPayment: snapshot.holdExpiresAt
              ? {
                  bookingId,
                  institutionId: command.institutionId,
                  amountMinor: snapshot.priceAmountMinor,
                  currency: snapshot.priceCurrency,
                  holdExpiresAt: snapshot.holdExpiresAt,
                }
              : undefined,
          };
        },
      );

    if (!transactionResult.pendingPayment) {
      return transactionResult.result;
    }

    try {
      const pending = transactionResult.pendingPayment;
      const paymentAction = await this.payment.initializeCharge({
        bookingId: pending.bookingId,
        institutionId: pending.institutionId,
        amount: Money.of(pending.amountMinor, pending.currency),
        holdExpiresAt: pending.holdExpiresAt,
        operationKey: command.operationKey,
      });
      return { ...transactionResult.result, paymentAction };
    } catch (error: unknown) {
      await this.unitOfWork.cancelPaymentInitializationFailure({
        bookingId: transactionResult.pendingPayment.bookingId,
        operation,
      });
      throw new RoomBookingError(
        "PAYMENT_INITIALIZATION_FAILED",
        "The payment session could not be initialized.",
        { cause: error instanceof Error ? error.name : "UnknownError" },
      );
    }
  }

  private validateOperationKey(operationKey: string): void {
    if (operationKey.length < 16 || operationKey.length > 128) {
      throw new RoomBookingError(
        "OPERATION_KEY_INVALID",
        "Operation key must contain between 16 and 128 characters.",
      );
    }
  }

  private fingerprint(command: RequestRoomBookingCommand): string {
    const canonical = JSON.stringify({
      institutionId: command.institutionId,
      actorId: command.actorId,
      roomId: command.roomId,
      startsAt: command.startsAt.toISOString(),
      endsAt: command.endsAt.toISOString(),
      attendeeCount: command.attendeeCount,
      purpose: command.purpose.trim(),
    });
    return createHash("sha256").update(canonical).digest("hex");
  }
}

import {
  IdempotencyRecord,
  Prisma,
  PrismaClient,
  RoomBookingStatus as PrismaRoomBookingStatus,
} from "@prisma/client";

import {
  IdempotentOperation,
  RoomBookingTransaction,
  RoomBookingUnitOfWorkPort,
} from "../application/room-booking.ports";
import { Money } from "../domain/money";
import { RoomBooking } from "../domain/room-booking.aggregate";
import {
  RoomBookingError,
  RoomBookingErrorCode,
} from "../domain/room-booking.errors";
import {
  BookableRoomSnapshot,
  RoomBookingDomainEvent,
  RoomBookingPolicySnapshot,
} from "../domain/room-booking.types";
import { decodePrismaJson, encodePrismaJson } from "./prisma-json.codec";

type TransactionClient = Prisma.TransactionClient;

type FailureSnapshot = {
  error: { code: RoomBookingErrorCode; message: string };
};

export class PrismaRoomBookingUnitOfWork implements RoomBookingUnitOfWorkPort {
  constructor(private readonly prisma: PrismaClient) {}

  async executeIdempotent<T>(
    operation: IdempotentOperation,
    work: (transaction: RoomBookingTransaction) => Promise<T>,
  ): Promise<T> {
    const existing = await this.findOperation(operation);
    if (existing) {
      return this.replay<T>(existing, operation);
    }

    try {
      return await this.prisma.$transaction(
        async (database) => {
          await database.idempotencyRecord.create({
            data: {
              institutionId: operation.institutionId,
              actorId: operation.actorId,
              operationScope: operation.operationScope,
              operationKey: operation.operationKey,
              requestFingerprint: Buffer.from(
                operation.requestFingerprint,
                "hex",
              ),
              state: "PROCESSING",
              expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1_000),
            },
          });

          const result = await work(
            new PrismaRoomBookingTransaction(database, operation),
          );
          await database.idempotencyRecord.update({
            where: { operationIdentity: this.operationIdentity(operation) },
            data: {
              state: "COMPLETED",
              responseSnapshot: encodePrismaJson(
                result,
              ) as Prisma.InputJsonValue,
              completedAt: new Date(),
            },
          });
          return result;
        },
        { isolationLevel: Prisma.TransactionIsolationLevel.ReadCommitted },
      );
    } catch (error: unknown) {
      if (!this.isUniqueViolation(error)) {
        throw error;
      }
      const racedOperation = await this.findOperation(operation);
      if (!racedOperation) {
        throw error;
      }
      return this.replay<T>(racedOperation, operation);
    }
  }

  async cancelPaymentInitializationFailure(input: {
    bookingId: string;
    operation: IdempotentOperation;
  }): Promise<void> {
    await this.prisma.$transaction(async (database) => {
      const rows = await database.$queryRaw<
        Array<{
          institution_id: string;
          booker_id: string;
          time_block_id: string;
          status: PrismaRoomBookingStatus;
        }>
      >`
        SELECT "institution_id", "booker_id", "time_block_id", "status"
        FROM "room_bookings"
        WHERE "id" = ${input.bookingId}::uuid
        FOR UPDATE
      `;
      const booking = rows[0];
      if (!booking || booking.status === "CANCELLED") {
        return;
      }
      if (booking.status !== "PENDING_PAYMENT") {
        return;
      }

      const now = new Date();
      await database.roomTimeBlock.update({
        where: { id: booking.time_block_id },
        data: {
          state: "RELEASED",
          releaseReason: "PAYMENT_INITIALIZATION_FAILED",
          releasedAt: now,
          version: { increment: 1 },
        },
      });
      await database.roomBooking.update({
        where: { id: input.bookingId },
        data: {
          status: "CANCELLED",
          terminalReasonCode: "PAYMENT_INITIALIZATION_FAILED",
          version: { increment: 1 },
        },
      });
      await database.bookingStatusHistory.create({
        data: {
          institutionId: booking.institution_id,
          bookingId: input.bookingId,
          fromStatus: "PENDING_PAYMENT",
          toStatus: "CANCELLED",
          transitionType: "PAYMENT_INITIALIZATION_FAILED",
          actorType: "SYSTEM",
          actorReference: "room-booking-payment",
          reasonCode: "PAYMENT_INITIALIZATION_FAILED",
          occurredAt: now,
          correlationId: input.operation.operationKey,
        },
      });
      await database.outboxMessage.create({
        data: {
          institutionId: booking.institution_id,
          aggregateType: "RoomBooking",
          aggregateId: input.bookingId,
          eventType: "RoomBookingCancelled",
          payload: {
            bookingId: input.bookingId,
            reasonCode: "PAYMENT_INITIALIZATION_FAILED",
          },
          occurredAt: now,
          correlationId: input.operation.operationKey,
        },
      });

      const failure: FailureSnapshot = {
        error: {
          code: "PAYMENT_INITIALIZATION_FAILED",
          message: "The payment session could not be initialized.",
        },
      };
      await database.idempotencyRecord.update({
        where: { operationIdentity: this.operationIdentity(input.operation) },
        data: {
          state: "FAILED_FINAL",
          responseSnapshot: failure,
          completedAt: now,
        },
      });
    });
  }

  private async findOperation(
    operation: IdempotentOperation,
  ): Promise<IdempotencyRecord | null> {
    return this.prisma.idempotencyRecord.findUnique({
      where: { operationIdentity: this.operationIdentity(operation) },
    });
  }

  private operationIdentity(operation: IdempotentOperation): {
    institutionId: string;
    actorId: string;
    operationScope: string;
    operationKey: string;
  } {
    return {
      institutionId: operation.institutionId,
      actorId: operation.actorId,
      operationScope: operation.operationScope,
      operationKey: operation.operationKey,
    };
  }

  private replay<T>(
    record: IdempotencyRecord,
    operation: IdempotentOperation,
  ): T {
    const fingerprint = Buffer.from(operation.requestFingerprint, "hex");
    if (!Buffer.from(record.requestFingerprint).equals(fingerprint)) {
      throw new RoomBookingError(
        "OPERATION_KEY_REUSED",
        "Operation key was already used for a different request.",
      );
    }
    if (record.state === "PROCESSING") {
      throw new RoomBookingError(
        "OPERATION_KEY_REUSED",
        "The operation is still being processed.",
      );
    }
    if (record.state === "FAILED_FINAL") {
      const snapshot = record.responseSnapshot as FailureSnapshot | null;
      throw new RoomBookingError(
        snapshot?.error.code ?? "PAYMENT_INITIALIZATION_FAILED",
        snapshot?.error.message ?? "The operation failed permanently.",
      );
    }
    if (record.responseSnapshot === null) {
      throw new Error("Completed idempotency record has no response snapshot.");
    }
    return decodePrismaJson(record.responseSnapshot) as T;
  }

  private isUniqueViolation(error: unknown): boolean {
    return (
      error instanceof Prisma.PrismaClientKnownRequestError &&
      error.code === "P2002"
    );
  }
}

class PrismaRoomBookingTransaction implements RoomBookingTransaction {
  constructor(
    private readonly database: TransactionClient,
    private readonly operation: IdempotentOperation,
  ) {}

  async lockBooker(bookerId: string): Promise<void> {
    const locked = await this.database.$queryRaw<Array<{ booker_id: string }>>`
      SELECT "booker_id"
      FROM "booking_actor_guards"
      WHERE "booker_id" = ${bookerId}::uuid
      FOR UPDATE
    `;
    if (locked.length === 0) {
      throw new RoomBookingError(
        "BOOKER_NOT_ELIGIBLE",
        "The student is not eligible to book a room.",
      );
    }
  }

  async isBookerEligible(bookerId: string): Promise<boolean> {
    return (
      (await this.database.appUser.count({
        where: {
          id: bookerId,
          institutionId: this.operation.institutionId,
          active: true,
        },
      })) === 1
    );
  }

  async countActiveBookings(bookerId: string): Promise<number> {
    return this.database.roomBooking.count({
      where: {
        institutionId: this.operation.institutionId,
        bookerId,
        status: { in: ["PENDING_PAYMENT", "CONFIRMED", "CHECKED_IN"] },
      },
    });
  }

  async getBookableRoom(roomId: string): Promise<BookableRoomSnapshot | null> {
    const room = await this.database.room.findFirst({
      where: {
        id: roomId,
        institutionId: this.operation.institutionId,
        active: true,
        bookableByStudents: true,
      },
    });
    return room
      ? {
          institutionId: room.institutionId,
          campusId: room.campusId,
          roomId: room.id,
          capacity: room.capacity,
          active: room.active,
          bookableByStudents: room.bookableByStudents,
        }
      : null;
  }

  async resolvePolicy(
    room: BookableRoomSnapshot,
    startsAt: Date,
  ): Promise<RoomBookingPolicySnapshot> {
    const policies = await this.database.bookingPolicyVersion.findMany({
      where: {
        institutionId: room.institutionId,
        effectiveFrom: { lte: startsAt },
        OR: [{ effectiveUntil: null }, { effectiveUntil: { gt: startsAt } }],
        AND: [
          {
            OR: [
              { scopeType: "ROOM", scopeReference: room.roomId },
              { scopeType: "CAMPUS", scopeReference: room.campusId },
              { scopeType: "INSTITUTION", scopeReference: null },
            ],
          },
        ],
      },
    });
    const priority: Record<string, number> = {
      ROOM: 3,
      CAMPUS: 2,
      INSTITUTION: 1,
    };
    const policy = policies.sort(
      (left, right) =>
        (priority[right.scopeType] ?? 0) - (priority[left.scopeType] ?? 0) ||
        right.versionNumber - left.versionNumber ||
        right.effectiveFrom.getTime() - left.effectiveFrom.getTime(),
    )[0];
    if (!policy) {
      throw new RoomBookingError(
        "ROOM_NOT_BOOKABLE",
        "No booking policy applies to the selected room and time.",
      );
    }
    return {
      policyVersionId: policy.id,
      snapshotSchemaVersion: policy.snapshotSchemaVersion,
      leadTimeMinutes: policy.leadTimeMinutes,
      bookingHorizonDays: policy.bookingHorizonDays,
      maxDurationMinutes: policy.maxDurationMinutes,
      activeBookingLimit: policy.activeBookingLimit,
      paymentHoldMinutes: policy.paymentHoldMinutes,
      checkInOpensBeforeMinutes: policy.checkInOpensBeforeMinutes,
      checkInClosesAfterMinutes: policy.checkInClosesAfterMinutes,
      fullRefundBeforeMinutes: policy.fullRefundBeforeMinutes,
      noShowRefundable: policy.noShowRefundable,
      price: Money.of(policy.priceAmountMinor, policy.priceCurrency.trim()),
    };
  }

  async claimRoomTimeBlock(input: {
    timeBlockId: string;
    bookingId: string;
    institutionId: string;
    campusId: string;
    roomId: string;
    startsAt: Date;
    endsAt: Date;
  }): Promise<void> {
    try {
      await this.database.roomTimeBlock.create({
        data: {
          id: input.timeBlockId,
          institutionId: input.institutionId,
          campusId: input.campusId,
          roomId: input.roomId,
          startsAt: input.startsAt,
          endsAt: input.endsAt,
          sourceType: "ROOM_BOOKING",
          sourceReference: input.bookingId,
        },
      });
    } catch (error: unknown) {
      if (
        error instanceof Error &&
        (error.message.includes(
          "room_time_blocks_no_overlapping_student_bookings",
        ) ||
          error.message.toLowerCase().includes("exclusion constraint"))
      ) {
        throw new RoomBookingError(
          "ROOM_SLOT_UNAVAILABLE",
          "The requested room slot is no longer available.",
        );
      }
      throw error;
    }
  }

  async saveBooking(booking: RoomBooking): Promise<void> {
    const snapshot = booking.snapshot();
    await this.database.roomBooking.create({
      data: {
        id: snapshot.bookingId,
        institutionId: snapshot.institutionId,
        campusId: snapshot.campusId,
        roomId: snapshot.roomId,
        bookerId: snapshot.bookerId,
        timeBlockId: snapshot.timeBlockId,
        policyVersionId: snapshot.policyVersionId,
        startsAt: snapshot.startsAt,
        endsAt: snapshot.endsAt,
        attendeeCount: snapshot.attendeeCount,
        purpose: snapshot.purpose,
        status: snapshot.status,
        holdExpiresAt: snapshot.holdExpiresAt,
        priceAmountMinor: snapshot.priceAmountMinor,
        priceCurrency: snapshot.priceCurrency,
        policySnapshot: snapshot.policySnapshot as Prisma.InputJsonValue,
        version: snapshot.version,
        createdAt: snapshot.createdAt,
      },
    });
    await this.database.bookingStatusHistory.create({
      data: {
        institutionId: snapshot.institutionId,
        bookingId: snapshot.bookingId,
        toStatus: snapshot.status,
        transitionType: "BOOKING_CREATED",
        actorType: "STUDENT",
        actorReference: snapshot.bookerId,
        occurredAt: snapshot.createdAt,
        correlationId: this.operation.operationKey,
      },
    });
  }

  async appendOutbox(events: RoomBookingDomainEvent[]): Promise<void> {
    if (events.length === 0) {
      return;
    }
    await this.database.outboxMessage.createMany({
      data: events.map((event) => ({
        institutionId: event.institutionId,
        aggregateType: "RoomBooking",
        aggregateId: event.bookingId,
        eventType: event.eventType,
        payload: encodePrismaJson(event) as Prisma.InputJsonValue,
        occurredAt: event.occurredAt,
        correlationId: this.operation.operationKey,
      })),
    });
  }
}

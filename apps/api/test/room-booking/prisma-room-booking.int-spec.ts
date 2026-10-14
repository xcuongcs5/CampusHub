import { randomUUID } from "node:crypto";

import { PrismaClient } from "@prisma/client";

import {
  ClockPort,
  IdGeneratorPort,
  RoomBookingPaymentPort,
} from "../../src/modules/room-booking/application/room-booking.ports";
import {
  RequestRoomBookingCommand,
  RequestRoomBookingUseCase,
} from "../../src/modules/room-booking/application/request-room-booking.use-case";
import { RoomBookingError } from "../../src/modules/room-booking/domain/room-booking.errors";
import { PrismaRoomBookingUnitOfWork } from "../../src/modules/room-booking/infrastructure/prisma-room-booking-unit-of-work";

const TEST_DATABASE_URL =
  process.env.TEST_DATABASE_URL ??
  "postgresql://campus:campus@localhost:5432/campus_hub_test?schema=public";
const databaseName = new URL(TEST_DATABASE_URL).pathname.slice(1);
if (databaseName !== "campus_hub_test") {
  throw new Error(
    `Integration tests refuse to truncate non-test database: ${databaseName}`,
  );
}

const NOW = new Date("2026-10-14T02:00:00.000Z");

class FixedClock implements ClockPort {
  now(): Date {
    return new Date(NOW);
  }
}

class UuidGenerator implements IdGeneratorPort {
  nextId(): string {
    return randomUUID();
  }
}

class NoPaymentExpected implements RoomBookingPaymentPort {
  async initializeCharge(): Promise<never> {
    throw new Error("Free booking must not initialize a payment.");
  }
}

describe("PrismaRoomBookingUnitOfWork", () => {
  const prisma = new PrismaClient({
    datasources: { db: { url: TEST_DATABASE_URL } },
  });
  const institutionId = randomUUID();
  const campusId = randomUUID();
  const roomId = randomUUID();
  const bookerIds = [randomUUID(), randomUUID(), randomUUID()];

  beforeAll(async () => {
    await prisma.$connect();
    await prisma.$executeRawUnsafe('TRUNCATE TABLE "institutions" CASCADE');
    await prisma.institution.create({
      data: {
        id: institutionId,
        code: "TEST-UNIVERSITY",
        name: "Test University",
        timezone: "Asia/Ho_Chi_Minh",
      },
    });
    await prisma.campus.create({
      data: {
        id: campusId,
        institutionId,
        code: "MAIN",
        name: "Main Campus",
      },
    });
    for (const [index, bookerId] of bookerIds.entries()) {
      await prisma.appUser.create({
        data: {
          id: bookerId,
          institutionId,
          externalRef: `student-${index + 1}`,
          email: `student-${index + 1}@example.edu.vn`,
          displayName: `Student ${index + 1}`,
        },
      });
    }
    await prisma.room.create({
      data: {
        id: roomId,
        institutionId,
        campusId,
        code: "A-101",
        displayName: "Room A-101",
        capacity: 12,
        bookableByStudents: true,
      },
    });
    await prisma.bookingPolicyVersion.create({
      data: {
        institutionId,
        scopeType: "INSTITUTION",
        scopeReference: null,
        versionNumber: 1,
        effectiveFrom: new Date("2026-01-01T00:00:00.000Z"),
        leadTimeMinutes: 30,
        bookingHorizonDays: 60,
        maxDurationMinutes: 180,
        activeBookingLimit: 5,
        paymentHoldMinutes: 10,
        checkInOpensBeforeMinutes: 15,
        checkInClosesAfterMinutes: 15,
        fullRefundBeforeMinutes: 120,
        noShowRefundable: false,
        priceAmountMinor: 0n,
        priceCurrency: "VND",
        publishedBy: "integration-test",
        publishedAt: NOW,
      },
    });
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  function createUseCase(): RequestRoomBookingUseCase {
    return new RequestRoomBookingUseCase(
      new PrismaRoomBookingUnitOfWork(prisma),
      new NoPaymentExpected(),
      new FixedClock(),
      new UuidGenerator(),
    );
  }

  function command(
    actorId: string,
    operationKey: string,
    startsAt: string,
    endsAt: string,
  ): RequestRoomBookingCommand {
    return {
      institutionId,
      actorId,
      operationKey,
      roomId,
      startsAt: new Date(startsAt),
      endsAt: new Date(endsAt),
      attendeeCount: 4,
      purpose: "Database integration test",
    };
  }

  it("persists one complete booking transaction and replays idempotently", async () => {
    const useCase = createUseCase();
    const request = command(
      bookerIds[0],
      "integration-idempotency-0001",
      "2026-10-15T03:00:00.000Z",
      "2026-10-15T04:00:00.000Z",
    );

    const first = await useCase.execute(request);
    const replay = await useCase.execute(request);

    expect(replay.booking.bookingId).toBe(first.booking.bookingId);
    expect(replay.booking.startsAt).toBeInstanceOf(Date);
    expect(replay.booking.priceAmountMinor).toBe(0n);
    await expect(
      prisma.roomBooking.count({ where: { id: first.booking.bookingId } }),
    ).resolves.toBe(1);
    await expect(
      prisma.roomTimeBlock.count({
        where: { sourceReference: first.booking.bookingId },
      }),
    ).resolves.toBe(1);
    await expect(
      prisma.bookingStatusHistory.count({
        where: { bookingId: first.booking.bookingId },
      }),
    ).resolves.toBe(1);
    await expect(
      prisma.outboxMessage.count({
        where: { aggregateId: first.booking.bookingId },
      }),
    ).resolves.toBe(1);
    await expect(
      prisma.idempotencyRecord.count({
        where: { operationKey: request.operationKey, state: "COMPLETED" },
      }),
    ).resolves.toBe(1);
  });

  it("allows only one winner when two students claim the same room slot", async () => {
    const startsAt = "2026-10-16T03:00:00.000Z";
    const endsAt = "2026-10-16T04:00:00.000Z";
    const requests = [
      createUseCase().execute(
        command(bookerIds[1], "integration-concurrent-0001", startsAt, endsAt),
      ),
      createUseCase().execute(
        command(bookerIds[2], "integration-concurrent-0002", startsAt, endsAt),
      ),
    ];

    const results = await Promise.allSettled(requests);
    const fulfilled = results.filter((result) => result.status === "fulfilled");
    const rejected = results.filter(
      (result): result is PromiseRejectedResult => result.status === "rejected",
    );

    expect(fulfilled).toHaveLength(1);
    expect(rejected).toHaveLength(1);
    expect(rejected[0].reason).toBeInstanceOf(RoomBookingError);
    expect((rejected[0].reason as RoomBookingError).code).toBe(
      "ROOM_SLOT_UNAVAILABLE",
    );
    await expect(
      prisma.roomBooking.count({
        where: {
          roomId,
          startsAt: new Date(startsAt),
          endsAt: new Date(endsAt),
        },
      }),
    ).resolves.toBe(1);
  });
});

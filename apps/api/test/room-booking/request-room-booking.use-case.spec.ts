import { Money } from "../../src/modules/room-booking/domain/money";
import { RoomBookingError } from "../../src/modules/room-booking/domain/room-booking.errors";
import {
  BookableRoomSnapshot,
  RoomBookingDomainEvent,
  RoomBookingPolicySnapshot,
} from "../../src/modules/room-booking/domain/room-booking.types";
import {
  ClockPort,
  IdempotentOperation,
  IdGeneratorPort,
  PaymentAction,
  RoomBookingPaymentPort,
  RoomBookingTransaction,
  RoomBookingUnitOfWorkPort,
} from "../../src/modules/room-booking/application/room-booking.ports";
import {
  RequestRoomBookingCommand,
  RequestRoomBookingUseCase,
} from "../../src/modules/room-booking/application/request-room-booking.use-case";

const NOW = new Date("2026-10-14T02:00:00.000Z");
const ROOM: BookableRoomSnapshot = {
  institutionId: "institution-1",
  campusId: "campus-1",
  roomId: "room-1",
  capacity: 10,
  active: true,
  bookableByStudents: true,
};

function policy(amountMinor: bigint): RoomBookingPolicySnapshot {
  return {
    policyVersionId: "policy-1",
    snapshotSchemaVersion: 1,
    leadTimeMinutes: 30,
    bookingHorizonDays: 30,
    maxDurationMinutes: 120,
    activeBookingLimit: 2,
    paymentHoldMinutes: 10,
    checkInOpensBeforeMinutes: 15,
    checkInClosesAfterMinutes: 15,
    fullRefundBeforeMinutes: 120,
    noShowRefundable: false,
    price: Money.of(amountMinor, "VND"),
  };
}

class FixedClock implements ClockPort {
  now(): Date {
    return new Date(NOW);
  }
}

class SequenceIds implements IdGeneratorPort {
  private index = 0;
  private readonly values = [
    "booking-1",
    "time-block-1",
    "booking-2",
    "time-block-2",
  ];

  nextId(): string {
    return this.values[this.index++] ?? `generated-${this.index}`;
  }
}

class FakeTransaction implements RoomBookingTransaction {
  eligible = true;
  activeBookingCount = 0;
  room: BookableRoomSnapshot | null = ROOM;
  selectedPolicy: RoomBookingPolicySnapshot = policy(0n);
  conflict = false;
  lockCalls: string[] = [];
  claims: Array<{ bookingId: string; roomId: string }> = [];
  savedBookingIds: string[] = [];
  events: RoomBookingDomainEvent[] = [];

  async lockBooker(bookerId: string): Promise<void> {
    this.lockCalls.push(bookerId);
  }

  async isBookerEligible(): Promise<boolean> {
    return this.eligible;
  }

  async countActiveBookings(): Promise<number> {
    return this.activeBookingCount;
  }

  async getBookableRoom(): Promise<BookableRoomSnapshot | null> {
    return this.room;
  }

  async resolvePolicy(): Promise<RoomBookingPolicySnapshot> {
    return this.selectedPolicy;
  }

  async claimRoomTimeBlock(input: {
    bookingId: string;
    roomId: string;
  }): Promise<void> {
    if (this.conflict) {
      throw new Error("exclusion violation");
    }
    this.claims.push(input);
  }

  async saveBooking(booking: {
    snapshot(): { bookingId: string };
  }): Promise<void> {
    this.savedBookingIds.push(booking.snapshot().bookingId);
  }

  async appendOutbox(events: RoomBookingDomainEvent[]): Promise<void> {
    this.events.push(...events);
  }
}

class FakeUnitOfWork implements RoomBookingUnitOfWorkPort {
  readonly transaction = new FakeTransaction();
  readonly cancelledPaymentBookingIds: string[] = [];
  private readonly completed = new Map<
    string,
    { requestFingerprint: string; result: unknown }
  >();

  async executeIdempotent<T>(
    operation: IdempotentOperation,
    work: (transaction: RoomBookingTransaction) => Promise<T>,
  ): Promise<T> {
    const key = `${operation.institutionId}:${operation.actorId}:${operation.operationScope}:${operation.operationKey}`;
    const previous = this.completed.get(key);
    if (previous) {
      if (previous.requestFingerprint !== operation.requestFingerprint) {
        throw new RoomBookingError(
          "OPERATION_KEY_REUSED",
          "Operation key was reused with a different request.",
        );
      }
      return previous.result as T;
    }

    const result = await work(this.transaction);
    this.completed.set(key, {
      requestFingerprint: operation.requestFingerprint,
      result,
    });
    return result;
  }

  async cancelPaymentInitializationFailure(input: {
    bookingId: string;
  }): Promise<void> {
    this.cancelledPaymentBookingIds.push(input.bookingId);
  }
}

class FakePayment implements RoomBookingPaymentPort {
  calls = 0;
  shouldFail = false;
  readonly action: PaymentAction = {
    actionType: "REDIRECT",
    actionUrl: "https://payments.example/checkout/test",
    expiresAt: new Date("2026-10-14T02:10:00.000Z"),
  };

  async initializeCharge(): Promise<PaymentAction> {
    this.calls += 1;
    if (this.shouldFail) {
      throw new Error("provider unavailable");
    }
    return this.action;
  }
}

function command(
  overrides: Partial<RequestRoomBookingCommand> = {},
): RequestRoomBookingCommand {
  return {
    institutionId: "institution-1",
    actorId: "student-1",
    operationKey: "operation-key-0001",
    roomId: "room-1",
    startsAt: new Date("2026-10-14T03:00:00.000Z"),
    endsAt: new Date("2026-10-14T04:00:00.000Z"),
    attendeeCount: 4,
    purpose: "Study group",
    ...overrides,
  };
}

function setup(): {
  useCase: RequestRoomBookingUseCase;
  unitOfWork: FakeUnitOfWork;
  payment: FakePayment;
} {
  const unitOfWork = new FakeUnitOfWork();
  const payment = new FakePayment();
  return {
    useCase: new RequestRoomBookingUseCase(
      unitOfWork,
      payment,
      new FixedClock(),
      new SequenceIds(),
    ),
    unitOfWork,
    payment,
  };
}

describe("RequestRoomBookingUseCase", () => {
  it("confirms a free room without initializing payment", async () => {
    const { useCase, unitOfWork, payment } = setup();

    const result = await useCase.execute(command());

    expect(result.booking.status).toBe("CONFIRMED");
    expect(result.paymentAction).toBeUndefined();
    expect(payment.calls).toBe(0);
    expect(unitOfWork.transaction.claims).toHaveLength(1);
    expect(unitOfWork.transaction.savedBookingIds).toEqual(["booking-1"]);
    expect(unitOfWork.transaction.events[0]?.eventType).toBe(
      "RoomBookingConfirmed",
    );
  });

  it("creates a ten-minute hold and initializes payment for a paid room", async () => {
    const { useCase, unitOfWork, payment } = setup();
    unitOfWork.transaction.selectedPolicy = policy(50_000n);

    const result = await useCase.execute(command());

    expect(result.booking.status).toBe("PENDING_PAYMENT");
    expect(result.booking.holdExpiresAt?.toISOString()).toBe(
      "2026-10-14T02:10:00.000Z",
    );
    expect(result.paymentAction).toEqual(payment.action);
    expect(payment.calls).toBe(1);
    expect(unitOfWork.transaction.events[0]?.eventType).toBe("RoomBookingHeld");
  });

  it("rejects a student who already reached the active booking limit", async () => {
    const { useCase, unitOfWork } = setup();
    unitOfWork.transaction.activeBookingCount = 2;

    await expect(useCase.execute(command())).rejects.toMatchObject({
      code: "ACTIVE_BOOKING_LIMIT_REACHED",
    });
    expect(unitOfWork.transaction.claims).toHaveLength(0);
  });

  it("maps a storage overlap to ROOM_SLOT_UNAVAILABLE", async () => {
    const { useCase, unitOfWork } = setup();
    unitOfWork.transaction.conflict = true;

    await expect(useCase.execute(command())).rejects.toMatchObject({
      code: "ROOM_SLOT_UNAVAILABLE",
    });
    expect(unitOfWork.transaction.savedBookingIds).toHaveLength(0);
  });

  it("compensates the hold when payment initialization fails", async () => {
    const { useCase, unitOfWork, payment } = setup();
    unitOfWork.transaction.selectedPolicy = policy(50_000n);
    payment.shouldFail = true;

    await expect(useCase.execute(command())).rejects.toMatchObject({
      code: "PAYMENT_INITIALIZATION_FAILED",
    });
    expect(unitOfWork.cancelledPaymentBookingIds).toEqual(["booking-1"]);
  });

  it("does not create a second booking when the same command is retried", async () => {
    const { useCase, unitOfWork } = setup();

    const first = await useCase.execute(command());
    const second = await useCase.execute(command());

    expect(second.booking.bookingId).toBe(first.booking.bookingId);
    expect(unitOfWork.transaction.savedBookingIds).toEqual(["booking-1"]);
  });
});

import { RoomBookingError } from "./room-booking.errors";

export class Money {
  private constructor(
    readonly amountMinor: bigint,
    readonly currency: string,
  ) {}

  static of(amountMinor: bigint, currency: string): Money {
    if (amountMinor < 0n) {
      throw new RoomBookingError(
        "PAYMENT_INITIALIZATION_FAILED",
        "Money amount cannot be negative.",
      );
    }

    const normalizedCurrency = currency.toUpperCase();
    if (!/^[A-Z]{3}$/.test(normalizedCurrency)) {
      throw new RoomBookingError(
        "PAYMENT_INITIALIZATION_FAILED",
        "Currency must be a three-letter ISO code.",
      );
    }

    return new Money(amountMinor, normalizedCurrency);
  }

  get isFree(): boolean {
    return this.amountMinor === 0n;
  }
}

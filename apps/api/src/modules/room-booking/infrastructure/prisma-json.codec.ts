const TYPE_KEY = "__campusHubType";

type TaggedValue = {
  [TYPE_KEY]: "bigint" | "date";
  value: string;
};

export function encodePrismaJson(value: unknown): unknown {
  if (typeof value === "bigint") {
    return { [TYPE_KEY]: "bigint", value: value.toString() };
  }
  if (value instanceof Date) {
    return { [TYPE_KEY]: "date", value: value.toISOString() };
  }
  if (Array.isArray(value)) {
    return value.map(encodePrismaJson);
  }
  if (value !== null && typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value).map(([key, child]) => [
        key,
        encodePrismaJson(child),
      ]),
    );
  }
  return value;
}

export function decodePrismaJson(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.map(decodePrismaJson);
  }
  if (value !== null && typeof value === "object") {
    const record = value as Record<string, unknown>;
    if (
      (record[TYPE_KEY] === "bigint" || record[TYPE_KEY] === "date") &&
      typeof record.value === "string"
    ) {
      const tagged = record as TaggedValue;
      return tagged[TYPE_KEY] === "bigint"
        ? BigInt(tagged.value)
        : new Date(tagged.value);
    }
    return Object.fromEntries(
      Object.entries(record).map(([key, child]) => [
        key,
        decodePrismaJson(child),
      ]),
    );
  }
  return value;
}

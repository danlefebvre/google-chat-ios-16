import { describe, expect, it } from "vitest";
import { createTokenCrypto } from "../src/crypto.js";

describe("createTokenCrypto", () => {
  it("round-trips refresh tokens", () => {
    const crypto = createTokenCrypto("unit-test-secret-value");
    const cipher = crypto.encrypt("refresh-token-plain");
    expect(cipher.startsWith("v1:")).toBe(true);
    expect(cipher).not.toContain("refresh-token-plain");
    expect(crypto.decrypt(cipher)).toBe("refresh-token-plain");
  });

  it("fails closed on tampered ciphertext", () => {
    const crypto = createTokenCrypto("unit-test-secret-value");
    const cipher = crypto.encrypt("secret");
    const tampered = cipher.replace(/.$/, cipher.endsWith("A") ? "B" : "A");
    expect(() => crypto.decrypt(tampered)).toThrow();
  });
});

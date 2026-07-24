import { describe, it, expect } from "vitest";
import { healthResponse } from "../src/health.js";

describe("healthResponse", () => {
  it("returns ok status with version", () => {
    const res = healthResponse("0.1.0");
    expect(res.status).toBe("ok");
    expect(res.version).toBe("0.1.0");
    expect(res.timestamp).toBeTruthy();
  });
});

import { describe, it, expect } from "vitest";
import { Readable } from "stream";
import {
  MAX_BODY_BYTES,
  PayloadTooLargeError,
  requestToFetchArgs,
} from "../src/request-body.js";

function fakeReq(body: Buffer, headers: Record<string, string> = {}) {
  const stream = Readable.from([body]) as Readable & {
    headers: Record<string, string | string[] | undefined>;
    method?: string;
    url?: string;
  };
  stream.headers = { host: "localhost", ...headers };
  stream.method = "POST";
  stream.url = "/test-notify";
  return stream;
}

describe("requestToFetchArgs body limit", () => {
  it("rejects when Content-Length exceeds the cap", async () => {
    const req = fakeReq(Buffer.alloc(0), {
      "content-length": String(MAX_BODY_BYTES + 1),
    });

    await expect(requestToFetchArgs(req as never)).rejects.toBeInstanceOf(PayloadTooLargeError);
  });

  it("rejects when streamed body exceeds the cap", async () => {
    const req = fakeReq(Buffer.alloc(MAX_BODY_BYTES + 1));

    await expect(requestToFetchArgs(req as never)).rejects.toBeInstanceOf(PayloadTooLargeError);
  });
});

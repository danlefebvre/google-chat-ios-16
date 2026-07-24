/** Cap buffered request bodies to avoid unbounded memory use. */
export const MAX_BODY_BYTES = 1_048_576;

export class PayloadTooLargeError extends Error {
  readonly statusCode = 413;

  constructor(message = "Payload Too Large") {
    super(message);
    this.name = "PayloadTooLargeError";
  }
}

export async function requestToFetchArgs(
  req: import("http").IncomingMessage,
): Promise<{ url: string; init: RequestInit }> {
  const host = req.headers.host ?? "localhost";
  const url = `http://${host}${req.url ?? "/"}`;

  const contentLengthHeader = req.headers["content-length"];
  if (contentLengthHeader) {
    const contentLength = Number(contentLengthHeader);
    if (Number.isFinite(contentLength) && contentLength > MAX_BODY_BYTES) {
      req.resume();
      throw new PayloadTooLargeError();
    }
  }

  const chunks: Buffer[] = [];
  let total = 0;

  for await (const chunk of req) {
    const buf = chunk as Buffer;
    total += buf.length;
    if (total > MAX_BODY_BYTES) {
      req.destroy();
      throw new PayloadTooLargeError();
    }
    chunks.push(buf);
  }

  const body = chunks.length > 0 ? Buffer.concat(chunks) : undefined;
  const headers = new Headers();
  for (const [key, value] of Object.entries(req.headers)) {
    if (value) {
      headers.set(key, Array.isArray(value) ? value.join(", ") : value);
    }
  }

  const init: RequestInit = { method: req.method, headers };
  if (body && req.method !== "GET" && req.method !== "HEAD") {
    init.body = body;
  }

  return { url, init };
}

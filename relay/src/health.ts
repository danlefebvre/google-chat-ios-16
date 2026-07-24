export function healthResponse(version: string): { status: string; version: string; timestamp: string } {
  return {
    status: "ok",
    version,
    timestamp: new Date().toISOString(),
  };
}

export interface HealthStatus {
  status: "ok";
  version: string;
  timestamp: string;
}

export function healthResponse(version: string): HealthStatus {
  return {
    status: "ok",
    version,
    timestamp: new Date().toISOString(),
  };
}

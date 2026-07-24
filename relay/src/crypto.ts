import { createCipheriv, createDecipheriv, createHash, randomBytes } from "node:crypto";
import type { TokenCrypto } from "./types.js";

/**
 * AES-256-GCM token crypto. Key is derived from RELAY_TOKEN_SECRET.
 * Format: v1:<iv_b64>:<tag_b64>:<cipher_b64>
 */
export function createTokenCrypto(secret: string): TokenCrypto {
  const key = createHash("sha256").update(secret).digest();

  return {
    encrypt(plain: string): string {
      const iv = randomBytes(12);
      const cipher = createCipheriv("aes-256-gcm", key, iv);
      const encrypted = Buffer.concat([
        cipher.update(plain, "utf8"),
        cipher.final(),
      ]);
      const tag = cipher.getAuthTag();
      return [
        "v1",
        iv.toString("base64"),
        tag.toString("base64"),
        encrypted.toString("base64"),
      ].join(":");
    },
    decrypt(cipherText: string): string {
      const [version, ivB64, tagB64, dataB64] = cipherText.split(":");
      if (version !== "v1" || !ivB64 || !tagB64 || !dataB64) {
        throw new Error("invalid encrypted token format");
      }
      const decipher = createDecipheriv(
        "aes-256-gcm",
        key,
        Buffer.from(ivB64, "base64"),
      );
      decipher.setAuthTag(Buffer.from(tagB64, "base64"));
      const plain = Buffer.concat([
        decipher.update(Buffer.from(dataB64, "base64")),
        decipher.final(),
      ]);
      return plain.toString("utf8");
    },
  };
}

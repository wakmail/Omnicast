# Rayconfig container format

Raycast exports observed in 2025 and 2026 use the same versionless binary container. Tracing the export and import routines in the Raycast executable shows that the first 16 bytes are a random initialization vector. All bytes from offset 16 through the end are AES 256 CBC ciphertext with PKCS7 padding.

The encryption key is the 32 byte SHA256 digest of the UTF8 password. There is no PBKDF2 step, salt, iteration field, inline version byte, or HMAC. The PBKDF2 and HMAC strings visible in the executable belong to its embedded SQLCipher database codec and are not called by the Rayconfig export path.

The decrypted payload is normally gzip data whose expanded bytes are JSON. The reader also accepts an uncompressed JSON object. A decrypted ZIP signature is treated as an unsupported payload version.

Raycast attempts to write an extended attribute after the encrypted file is written. The attribute records export metadata and is not consumed by the decryption path. Both ground truth samples lack a Raycast specific attribute, so parsing must not depend on it.

The container has no integrity tag. A wrong password is detected by AES padding failure or by the absence of a supported payload signature after decryption.

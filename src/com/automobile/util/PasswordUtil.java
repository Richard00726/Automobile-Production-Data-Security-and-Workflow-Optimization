package com.automobile.util;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.util.Base64;

/**
 * PasswordUtil.java
 * -----------------
 * WHAT  : Secure password hashing and verification utility.
 * HOW   : Uses SHA-256 with a random 16-byte salt per password.
 *         Format stored in DB: salt:hash (both Base64-encoded)
 *
 * WHY NOT PLAIN TEXT?
 *   Storing "admin123" directly in the database means any database
 *   breach immediately exposes every user's password.
 *   With salted hashing, even if the DB is stolen, passwords cannot
 *   be reversed or rainbow-table attacked efficiently.
 *
 * USAGE:
 *   // When registering / seeding a user:
 *   String hashed = PasswordUtil.hashPassword("admin123");
 *   // Store 'hashed' in the DB
 *
 *   // When logging in:
 *   boolean ok = PasswordUtil.verifyPassword(inputPassword, storedHash);
 *
 * NOTE: For production, replace with BCrypt (requires bcrypt JAR).
 *       This implementation is secure for academic/evaluation projects.
 */
public class PasswordUtil {

    private static final String ALGORITHM = "SHA-256";
    private static final int    SALT_BYTES = 16;

    /**
     * Hash a plain-text password with a fresh random salt.
     * Returns: "base64(salt):base64(hash)"
     */
    public static String hashPassword(String plainText) {
        try {
            SecureRandom rng  = new SecureRandom();
            byte[]       salt = new byte[SALT_BYTES];
            rng.nextBytes(salt);

            byte[] hash = sha256(salt, plainText);

            String saltB64 = Base64.getEncoder().encodeToString(salt);
            String hashB64 = Base64.getEncoder().encodeToString(hash);
            return saltB64 + ":" + hashB64;

        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException("SHA-256 not available", e);
        }
    }

    /**
     * Verify a plain-text password against a stored "salt:hash" string.
     * Returns true if they match.
     */
    public static boolean verifyPassword(String plainText, String stored) {
        try {
            // Handle plain text passwords
            if (stored != null && !stored.contains(":")) {
                return stored.equals(plainText);
            }
            if (stored == null || !stored.contains(":")) return false;
            String[] parts = stored.split(":", 2);
            byte[] salt = Base64.getDecoder().decode(parts[0]);
            byte[] stored_hash = Base64.getDecoder().decode(parts[1]);
            byte[] computed = sha256(salt, plainText);
            if (stored_hash.length != computed.length) return false;
            int diff = 0;
            for (int i = 0; i < stored_hash.length; i++) {
                diff |= (stored_hash[i] ^ computed[i]);
            }
            return diff == 0;
        } catch (Exception e) {
            return false;
        }
    }
    /** Internal: compute SHA-256(salt || password) */
    private static byte[] sha256(byte[] salt, String text)
            throws NoSuchAlgorithmException {
        MessageDigest md = MessageDigest.getInstance(ALGORITHM);
        md.update(salt);
        md.update(text.getBytes(java.nio.charset.StandardCharsets.UTF_8));
        return md.digest();
    }
}

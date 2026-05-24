package com.automobile.util;

import com.automobile.db.DBConnection;
import java.sql.Connection;
import java.sql.PreparedStatement;

/**
 * SeedPasswords.java
 * -------------------
 * RUN ONCE: Inserts/updates the 5 demo users with properly hashed passwords.
 *
 * HOW TO RUN in Eclipse:
 *   Right-click this file → Run As → Java Application
 *   (Ensure your Tomcat server has started and DB is reachable)
 *
 * WHAT IT DOES:
 *   Uses PasswordUtil.hashPassword() to create a salted SHA-256 hash
 *   for each demo password, then UPDATEs the existing rows in the users table.
 *
 * After running, log in with:
 *   admin/admin123 | designer1/design123 | analyst1/analytics123
 *   qc1/qc123      | tester1/test123
 */
public class SeedPasswords {

    public static void main(String[] args) throws Exception {

        String[][] users = {
            { "admin",     "admin123"     },
            { "designer1", "design123"    },
            { "analyst1",  "analytics123" },
            { "qc1",       "qc123"        },
            { "tester1",   "test123"      }
        };

        try (Connection conn = DBConnection.getConnection()) {
            String sql = "UPDATE users SET password = ? WHERE username = ?";
            PreparedStatement ps = conn.prepareStatement(sql);

            for (String[] u : users) {
                String hashed = PasswordUtil.hashPassword(u[1]);
                ps.setString(1, hashed);
                ps.setString(2, u[0]);
                int rows = ps.executeUpdate();
                System.out.println("✅ Updated " + u[0] + " → " + rows + " row(s)  [hash=" + hashed.substring(0,24) + "...]");
            }

            System.out.println("\n✅ All passwords hashed and stored. You can now log in with the demo credentials.");
        }
    }
}

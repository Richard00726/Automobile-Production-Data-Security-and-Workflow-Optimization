package com.automobile.db;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;

public class DBConnection {

    private static final String URL = "jdbc:mysql://localhost:3306/automobile_db"
            + "?useSSL=false"
            + "&serverTimezone=UTC"
            + "&allowPublicKeyRetrieval=true"
            + "&useUnicode=true"
            + "&characterEncoding=UTF-8"
            + "&characterSetResults=UTF-8"
            + "&connectionCollation=utf8mb4_unicode_ci";

    private static final String USER     = "root";
    private static final String PASSWORD = "Rich@2005";

    public static Connection getConnection() throws SQLException {
        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
            Connection conn = DriverManager.getConnection(URL, USER, PASSWORD);
            // Force UTF-8 on every connection — overrides cp850 permanently!
            conn.createStatement().execute("SET NAMES utf8mb4");
            conn.createStatement().execute("SET CHARACTER SET utf8mb4");
            conn.createStatement().execute("SET character_set_connection = utf8mb4");
            return conn;
        } catch (ClassNotFoundException e) {
            throw new SQLException(
                "MySQL Connector JAR not found. "
              + "Add mysql-connector-java-x.x.xx.jar to WEB-INF/lib/\n"
              + e.getMessage()
            );
        }
    }
}


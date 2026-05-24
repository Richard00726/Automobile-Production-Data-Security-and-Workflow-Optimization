package com.automobile.util;

import java.util.LinkedHashMap;
import java.util.Map;

public class ValidationUtil {

    private Map<String, String> errors;

    public ValidationUtil() {
        errors = new LinkedHashMap<>();
    }

    // Required field validation
    public ValidationUtil require(String field, String value, String message) {
        if (value == null || value.trim().isEmpty()) {
            errors.put(field, message);
        }
        return this;
    }

    // Minimum length validation
    public ValidationUtil minLength(String field, String value, int min, String message) {
        if (!errors.containsKey(field)) {
            if (value == null || value.trim().length() < min) {
                errors.put(field, message);
            }
        }
        return this;
    }

    // Maximum length validation
    public ValidationUtil maxLength(String field, String value, int max, String message) {
        if (!errors.containsKey(field)) {
            if (value != null && value.length() > max) {
                errors.put(field, message);
            }
        }
        return this;
    }

    // Pattern validation
    public ValidationUtil pattern(String field, String value, String regex, String message) {
        if (!errors.containsKey(field)) {
            if (value == null || !value.matches(regex)) {
                errors.put(field, message);
            }
        }
        return this;
    }

    // Integer range validation
    public ValidationUtil intRange(String field, String value, int min, int max, String message) {
        if (!errors.containsKey(field)) {
            try {
                int n = Integer.parseInt(value);
                if (n < min || n > max) {
                    errors.put(field, message);
                }
            } catch (NumberFormatException e) {
                errors.put(field, message);
            }
        }
        return this;
    }

    // Double range validation
    public ValidationUtil doubleRange(String field, String value, double min, double max, String message) {
        if (!errors.containsKey(field)) {
            try {
                double d = Double.parseDouble(value);
                if (d < min || d > max) {
                    errors.put(field, message);
                }
            } catch (NumberFormatException e) {
                errors.put(field, message);
            }
        }
        return this;
    }

    // Username validation
    public ValidationUtil safeUsername(String field, String value) {
        return pattern(field, value,
                "^[a-zA-Z0-9_]{3,30}$",
                "Username must be 3-30 characters: letters, digits, underscores only.");
    }

    // Password validation
    public ValidationUtil strongPassword(String field, String value) {
        if (!errors.containsKey(field)) {
            if (value == null || value.length() < 6) {
                errors.put(field, "Password must be at least 6 characters.");
            }
        }
        return this;
    }

    // Prevent HTML injection
    public ValidationUtil noHtml(String field, String value) {
        return pattern(field, value,
                "^[^<>\"';&]*$",
                "Field contains invalid characters: < > \" ' ; &");
    }

    // Check if errors exist
    public boolean hasErrors() {
        return !errors.isEmpty();
    }

    // Get all errors
    public Map<String, String> getErrors() {
        return errors;
    }

    // Get first error
    public String getFirst() {
        return errors.values().stream().findFirst().orElse(null);
    }

    // Get summary of errors
    public String getSummary() {
        StringBuilder sb = new StringBuilder();
        for (String msg : errors.values()) {
            sb.append(msg).append("\n");
        }
        return sb.toString();
    }
}
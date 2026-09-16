/**
 * ELV_PricingAccess
 * ───────────────────
 * Dynamic-field utility used by all pricing services.  All field reads/writes go
 * through this class so the package compiles without hard SBQQ__* references.
 */
public with sharing class ELV_PricingAccess {

    // ── Read / Write ─────────────────────────────────────────────────────
    public static Object get(SObject row, String apiName) {
        return row.get(apiName);
    }

    public static void put(SObject row, String apiName, Object value) {
        row.put(apiName, value);
    }

    /** Read a parent-relationship field, e.g. 'Quote.ShippingCountry'. */
    public static Object getRelated(SObject row, String path) {
        List<String> parts = path.split('\\.');
        SObject current = row;
        for (Integer i = 0; i < parts.size() - 1; i++) {
            if (current == null) return null;
            current = current.getSObject(parts[i]);
        }
        return current == null ? null : current.get(parts[parts.size() - 1]);
    }

    // ── Comparison helpers ───────────────────────────────────────────────
    public static Boolean blank(Object x) {
        return x == null || String.valueOf(x).trim() == '';
    }

    public static Boolean eq(Object x, String v) {
        return x != null && String.valueOf(x).equalsIgnoreCase(v);
    }

    public static Boolean neq(Object x, String v) {
        return !eq(x, v);
    }

    /** True when String value of x equals any entry (case-insensitive). */
    public static Boolean anyOf(Object x, List<String> values) {
        if (x == null) return false;
        String s = String.valueOf(x);
        for (String v : values) {
            if (s.equalsIgnoreCase(v.trim())) return true;
        }
        return false;
    }

    /** True when the numeric field value is greater than threshold. */
    public static Boolean gt(Object x, Decimal threshold) {
        if (x == null) return false;
        return toDecimal(x) > threshold;
    }

    public static Boolean gte(Object x, Decimal threshold) {
        if (x == null) return false;
        return toDecimal(x) >= threshold;
    }

    public static Boolean lt(Object x, Decimal threshold) {
        if (x == null) return false;
        return toDecimal(x) < threshold;
    }

    public static Boolean lte(Object x, Decimal threshold) {
        if (x == null) return false;
        return toDecimal(x) <= threshold;
    }

    public static Boolean isTrue(Object x) {
        return x instanceof Boolean && ((Boolean) x) == true;
    }

    public static Boolean isFalse(Object x) {
        return x == null || (x instanceof Boolean && ((Boolean) x) == false);
    }

    public static Decimal toDecimal(Object x) {
        if (x == null) return 0;
        if (x instanceof Decimal) return (Decimal) x;
        try { return Decimal.valueOf(String.valueOf(x)); } catch (Exception e) { return 0; }
    }

    public static Integer toInteger(Object x) {
        return toDecimal(x).intValue();
    }

    public static Date toDate(Object x) {
        if (x == null) return null;
        if (x instanceof Date) return (Date) x;
        if (x instanceof Datetime) return ((Datetime) x).date();
        return null;
    }
}

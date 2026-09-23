/**
 * Configuration gate for the scratch Required for Approval solution.
 * Default behavior is fail-closed: no trigger work runs until the Default
 * Custom Metadata record is explicitly activated and bindings are enabled.
 */
public with sharing class ELV_RFA_Config {
    public class Settings {
        public Boolean active = false;
        public Boolean entitlementCheckActive = false;
        public Boolean isrCheckActive = false;
        public String pilotUserId;
        public String version;
        public String esoRecordType;
        public String huntIqRecordType;
        public String transitionRecordType;
    }

    @TestVisible private static Settings testSettings;

    public static Settings get() {
        if (Test.isRunningTest() && testSettings != null) {
            return testSettings;
        }
        Settings out = new Settings();
        try {
            ELV_RFA_Control__mdt row = [
                SELECT Active__c, Entitlement_Check_Active__c, ISR_Check_Active__c,
                       Pilot_User_Id__c, Version__c, ESO_ISR_Record_Type__c,
                       HuntIQ_ISR_Record_Type__c, Transition_ISR_Record_Type__c
                FROM ELV_RFA_Control__mdt
                WHERE DeveloperName = 'Default'
                LIMIT 1
            ];
            out.active = row.Active__c == true;
            out.entitlementCheckActive = row.Entitlement_Check_Active__c == true;
            out.isrCheckActive = row.ISR_Check_Active__c == true;
            out.pilotUserId = row.Pilot_User_Id__c;
            out.version = row.Version__c;
            out.esoRecordType = row.ESO_ISR_Record_Type__c;
            out.huntIqRecordType = row.HuntIQ_ISR_Record_Type__c;
            out.transitionRecordType = row.Transition_ISR_Record_Type__c;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'ELV_RFA_Config fail-closed: ' + e.getMessage());
            out.active = false;
        }
        if (out.active && !String.isBlank(out.pilotUserId) && out.pilotUserId != String.valueOf(UserInfo.getUserId())) {
            out.active = false;
        }
        return out;
    }

    public static Boolean isActive() {
        return get().active == true;
    }
}
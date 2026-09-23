/*
 * Licensed Materials - Property of IBM
 * 6949-82Q
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public with sharing class x7sExpRecordQueryHelper {

    /*
        Execute query
        NOTE: All calls to this function are built using buildQueryString function
        which ensures that the query is safe.
     */
    @SuppressWarnings('PMD')
    public static List<SObject> executeQuery(String queryString) {
        return Database.query(queryString);
    }

    /*
       Build a query
    */
    public static String buildQueryString(String objectType, List<String> fields, String whereClause) {

        // Start off string
        String queryString = 'Select ';

        // Fields
        String fieldsList = String.escapeSingleQuotes(x7sExpUtils.buildStringFromList(fields));// Escape (prevent injection), build String from list
        queryString += fieldsList;

        // From clause
        queryString += ' from ' + String.escapeSingleQuotes(objectType);

        // Where clause
        if (whereClause != null) {
            queryString += ' where ' + whereClause;
        }

        // limit clause

        return queryString;
    }

    /*
        Build a where clause for a detail (by ID)
     */
    public static String buildIdWhereClause(String recordIdString) {
        return 'Id = \'' + String.escapeSingleQuotes(recordIdString) + '\'';
    }

    /*
        Format a detail result as x7sExp Content Objects to get field labels!
     */
    public static List<x7sExpContentObject> formatRecordDetailWithLabels(String objectType, SObject recordDetail, List<String> fields) {

        // Get describe, object schema, and field map
        Map<String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
        Schema.SObjectType objectSchema = schemaMap.get(objectType);
        Map<String, Schema.SObjectField> fieldMap = objectSchema.getDescribe().fields.getMap();

        // List of PCO to return
        List<x7sExpContentObject> labeledFields = new List<x7sExpContentObject>();

        // For each field, check if user can see it, and if so, get it's label, map to value in a PCO, add to list
        for (String fieldName : fields) {

            // Is this field accessible to user?
            if (fieldMap.get(fieldName).getDescribe().isAccessible()) {
                x7sExpContentObject fieldLabelValue = new x7sExpContentObject();

                // Set "title" as the field name. We will use this on the front end
                fieldLabelValue.title = fieldName; // Not doing this anymore! fieldMap.get(fieldName).getDescribe().getLabel(); // get the label (translation!) for this field

                // get value from our queried record detail. This will ONLY be used later to determine if the value is null! Therefore, we can cram it into a string
                fieldLabelValue.description = String.valueOf(recordDetail.get(fieldName));

                // Add to list
                labeledFields.add(fieldLabelValue);
            }
        }

        return labeledFields;
    }
}
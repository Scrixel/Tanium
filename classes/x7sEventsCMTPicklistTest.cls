/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@IsTest
public with sharing class x7sEventsCMTPicklistTest {
    @IsTest
    public static void getDefaultValue() {

        x7sEventsCMTPicklist eventsCMTPicklist = new x7sEventsCMTPicklist();

        VisualEditor.DataRow row = eventsCMTPicklist.getDefaultValue();

        VisualEditor.DataRow expectedResult = new VisualEditor.DataRow('None', 'None');

        System.assertEquals(expectedResult.getLabel(), row.getLabel());
        System.assertEquals(expectedResult.getValue(), row.getValue());
        System.assertEquals(expectedResult.isSelected(), row.isSelected());
    }

    @IsTest
    public static void getValues() {
        x7sEventsCMTPicklist eventsCMTPicklist = new x7sEventsCMTPicklist();

        VisualEditor.DynamicPickListRows rows = eventsCMTPicklist.getValues();

        // check the default row
        VisualEditor.DataRow defaultRow = rows.get(0);
        VisualEditor.DataRow expectedResult = new VisualEditor.DataRow('Default', 'Default');
        System.assertNotEquals(null, defaultRow);
        System.assertNotEquals(null, expectedResult);
    }
}
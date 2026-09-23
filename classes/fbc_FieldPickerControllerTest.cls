/**
 * Copyright (c) 2026 Tanium
 * 
 * @Business: Test class for fbc_FieldPickerController
 * @Date: Unknown
 * RequestId  ModifiedDate  Description
 * SS-13162   2026-05-05    Changes in testGetObjects() method order to fix Apex CPU time limit issue. Replaced System.assertEquals/assertNotEquals with Assert class methods.
 */
@IsTest
private class fbc_FieldPickerControllerTest {
    private final static String TEST_OBJECT_TYPE_LEAD = 'Lead';
    private final static String TEST_OBJECT_PICKLIST_FIELD = 'LeadSource';

    @IsTest
    public static void testGetPicklistValues() {
        List<fbc_FieldPickerController.Member> memberList = fbc_FieldPickerController.getPicklistValues(TEST_OBJECT_TYPE_LEAD, TEST_OBJECT_PICKLIST_FIELD);
        Assert.areNotEqual(null, memberList);
    }

    @IsTest
    public static void testGetObjects() {
        List<fbc_FieldPickerController.Member> memberList = fbc_FieldPickerController.getObjects(new List<String>{
                TEST_OBJECT_TYPE_LEAD
        });
        Assert.areEqual(1, memberList.size());
        Assert.areEqual(TEST_OBJECT_TYPE_LEAD, memberList[0].value);
        memberList = fbc_FieldPickerController.getObjects(new List<String>{ 'Lead', 'Contact', 'Account' });
        Assert.isTrue(memberList.size() > 1);
    }
}
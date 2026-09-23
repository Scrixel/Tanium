/*
 * Copyright (c) 2021. 7Summits, an IBM Company. All rights reserved.
 */

/*
@Class Name          : x7sNewsTopicsListTest
@Created by          :
@Description         : Apex Test class for x7sNewsTopicsListTest
*/

@IsTest
global class x7sNewsTopicsListTest
{

    @isTest
    public static void getDefaultValue() {
        x7sNewsTopicsList newsTopicList = new x7sNewsTopicsList();

        VisualEditor.DataRow row = newsTopicList.getDefaultValue();

        VisualEditor.DataRow expectedResult = new VisualEditor.DataRow('None', '');

        System.assertEquals(row.getLabel(), expectedResult.getLabel());
        System.assertEquals(row.getValue(), expectedResult.getValue());
        System.assertEquals(row.isSelected(), expectedResult.isSelected());
    }

    @isTest
    public static void getValues() {
        // yes this test isn't the greatest. Wasn't able to get a networkId mocked up
        // to be able to actually execute the query that getValue uses to get topics
        // The query to get topics 'SELECT name, id FROM Topic WHERE networkid != null'
        // will return 0 results in this cases so we will only have the default row
        // created which we test for.

        x7sNewsTopicsList newsTopicList = new x7sNewsTopicsList();

        VisualEditor.DynamicPickListRows rows = newsTopicList.getValues();

        // check to make sure we at least have a default option
        System.assertEquals(1, rows.size());

        // check the default row
        VisualEditor.DataRow defaultRow = rows.get(0);
        VisualEditor.DataRow expectedResult = new VisualEditor.DataRow('None', '');

        System.assertEquals(defaultRow.getLabel(), expectedResult.getLabel());
        System.assertEquals(defaultRow.getValue(), expectedResult.getValue());
        System.assertEquals(defaultRow.isSelected(), expectedResult.isSelected());
    }

}
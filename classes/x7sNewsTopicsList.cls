/*
 * Copyright (c) 2021. 7Summits, an IBM Company. All rights reserved.
 */

/*
@Class Name          : x7sNewsTopicsList
@Created by          :
@Description         : Apex class for creating dynamic Topic dropdown in News List component
*/
@SuppressWarnings('PMD.ApexSharingViolations')
global class x7sNewsTopicsList extends VisualEditor.DynamicPickList{

    global override VisualEditor.DataRow getDefaultValue() {
        // set the default value of the picklist
        VisualEditor.DataRow defaultValue = new VisualEditor.DataRow('None', '');

        return defaultValue;
    }

    global override VisualEditor.DynamicPickListRows getValues() {
        // query string to get all the Topics that are associated to a community
        String queryTopic = 'SELECT name, id FROM Topic WHERE networkid != null';

        // do the query
        List<Topic> topicList = Database.query(queryTopic);

        // create picklist
        VisualEditor.DynamicPickListRows myValues = new VisualEditor.DynamicPickListRows();

        // add the default picklist value
        VisualEditor.DataRow defaultTopic = new VisualEditor.DataRow('None', '');
        myValues.addRow(defaultTopic);

        // iterate all the Topics adding them to the picklist
        for(Topic topic : topicList) {
            myValues.addRow(new VisualEditor.DataRow(topic.Name, String.valueOf(topic.Id)));
        }

        return myValues;
    }
}
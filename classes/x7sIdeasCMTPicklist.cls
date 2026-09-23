/*
 * Licensed Materials - Property of IBM
 * 6949-82Z
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */ 

 /**
	 * @description : class for making dynamic picklist for builder property
 **/
@SuppressWarnings('PMD.AvoidGlobalModifier')
global without sharing class x7sIdeasCMTPicklist extends VisualEditor.DynamicPickList {
   
    public static final String IDEA_OBJECT = 'Idea'; 
    private static final String NONE = 'None'; 
    private static final String DEFAULT_FIELDSET = '7S Ideas Setting - Default Field Set'; 

    global override VisualEditor.DataRow getDefaultValue() {
        // set the default value of the picklist
        VisualEditor.DataRow defaultValue = new VisualEditor.DataRow(NONE, NONE);
        return defaultValue;
    }

    global override VisualEditor.DynamicPickListRows getValues() {
        // create picklist
        VisualEditor.DynamicPickListRows myValues = new VisualEditor.DynamicPickListRows();

        // add the default picklist value
        VisualEditor.DataRow defaultSetting = new VisualEditor.DataRow(NONE, NONE);
        VisualEditor.DataRow cmtSetting = new VisualEditor.DataRow(DEFAULT_FIELDSET, 'Default');
        myValues.addRow(defaultSetting);
        myValues.addRow(cmtSetting);

        List<X7S_Shr_Custom_Field_Set__mdt> settingsName = X7S_Shr_Custom_Field_Set__mdt.getAll().values();

        // populate picklist
        myValues = populatePickListWithSettings(settingsName, myValues);
        return myValues;
        
    }

    private static VisualEditor.DynamicPickListRows populatePickListWithSettings(List<X7S_Shr_Custom_Field_Set__mdt> settingsName, VisualEditor.DynamicPickListRows pickList){
        // iterate all the topics
        for (X7S_Shr_Custom_Field_Set__mdt setting : settingsName) {
            // create data row row and add it to picklist
            if(setting.Active__c == true && setting.Object_API_Name__c == IDEA_OBJECT){
                VisualEditor.DataRow row = new VisualEditor.DataRow(setting.Label,setting.DeveloperName);
                pickList.addRow(row);
            }
        }
        return pickList;
    }
}
/*
 * Copyright (c) 2022.  7Summits, an IBM company. All rights reserved.
 */
/**
 * @description Collection of custom fields
 */
public without sharing class x7sShrCustomFieldList {
	@AuraEnabled
	public String objectName { get;set; }
	@AuraEnabled
	public Boolean active { get; set; }
	@AuraEnabled
	public Boolean allFieldsRequired { get; set; }
	@AuraEnabled
	public List<x7sShrCustomFieldModel> fields { get; set; }

	public x7sShrCustomFieldList() {
		this.active = true;
		this.allFieldsRequired = false;
		this.fields = new List<x7sShrCustomFieldModel>();
	}

	public void dump(String title) {
		System.debug('Custom Field List: ' + title);
		System.debug('Object name: ' + objectName);
		System.debug('Size: ' + fields.size());
		System.debug('Active: ' + active);
		System.debug('All fields required: ' + allFieldsRequired);
		for (Integer index = 0; index < fields.size(); ++index) {
			fields[index].dump(String.valueOf(index));
		}
	}
}
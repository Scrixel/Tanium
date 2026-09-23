/*
 * Licensed Materials - Property of IBM
 * 6949-82Z
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public without sharing class x7sIdeasNotifyModel {
	public String id { get; set; } 
	public String name { get; set; } 
	public String context { get; set; } 
	public String detail { get; set; } 
	public String url { get; set; } 

	public x7sIdeasNotifyModel(String id, String name, String context, String detail, String url) {
		this.id = id;
		this.name = name;
		this.context = context;
		this.detail = detail;
		this.url = url;
	}

	public void Dump(String message) {
		System.debug('Notification  : ' + message);
		System.debug('    id        : ' + this.id);
		System.debug('    name      : ' + this.name);
		System.debug('    context   : ' + this.context);
		System.debug('    detail    : ' + this.detail);
		System.debug('    url       : ' + this.url);
	}
}
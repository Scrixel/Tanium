/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public with sharing class x7sEventsExternalMeetingResponse implements x7sEventsIExternalMeetingResponse {
	public x7sEventsExternalMeetingResponse() {
		success = true;
		error = '';
		result = '';
	}

	public Boolean success {
		private get {
			return success;
		}
		set {
			success = value;
		}
	}

	public String error {
		private get {
			return error;
		}
		set {
			error = value;
		}
	}

	public String result {
		private get {
			return result;
		}
		set {
			result = value;
		}
	}

	public Boolean isSuccess() {
		return success;
	}

	public String getError() {
		return error;
	}

	public String getResult() {
		return result;
	}
}
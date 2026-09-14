/*
 * Copyright (c) 2025 Tanium
 *
 * @DATE: 2025-12-09
 * @AUTHOR: Tanium Dev Team
 * @REQUEST:
 * @BUSINESS: Mock Http Class for the all CaseSendToSlack classes.
 * RequestId    ModifiedDate    Comment
 * SS-12185     2025-12-09      Initial Development
 */
public class CaseSendToSlackMock implements HttpCalloutMock {
	public HttpResponse respond(HttpRequest request) {
		HttpResponse respone = new HttpResponse();
		respone.setBody('{"text":"value"}');
		respone.setStatusCode(200);

		return respone;
	}
}
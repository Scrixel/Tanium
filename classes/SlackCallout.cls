/*
 * @DATE: 2025-12-09
 * @AUTHOR: Tanium Dev Team
 * @BUSINESS: Utility class for creating Slack callouts.
 * RequestId	ModifiedDate    Comment
 * SS-12185     2025-12-09      Initial Development
 */
public class SlackCallout implements Queueable, Database.AllowsCallouts {
	private final String url;
	private final String method;
	private final String body;

	public SlackCallout(String url, String method, String body) {
		this.url = url;
		this.method = method;
		this.body = body;
	}

	public void execute(QueueableContext ctx) {
		HttpRequest req = new HttpRequest();
		req.setEndpoint(url);
		req.setMethod(method);
		req.setBody(body);
		Http http = new Http();
		HttpResponse res = http.send(req);
	}
}
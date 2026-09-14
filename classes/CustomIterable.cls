/**
 * @Business: Iterate through csv file - use in a batch class
 * @Date: 12/21/24
 * @Authors: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-9924    2024-12-21    Mass Undelete Contact Records
 */
public class CustomIterable implements Iterable<String> {
	private String data;

	public CustomIterable(String dataString) {
		data = dataString;
	}

	public Iterator<String> iterator() {
		return new RoscoRowIterator(data);
	}
}
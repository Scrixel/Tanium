//Used to stop recursion in after updates (to allow for non-cascading updates of an entity)

public class StopRecursion {
	public static boolean flag = true;
	public static boolean runonce() {
		if (flag) {
			flag = false;
		} else {
			return flag;
		}
		return true;
	}
}
public abstract class Singleton {
	private static final Map<Type, Singleton> typeToSingleton = new Map<Type, Singleton>();

	public static Singleton getSingleton(Type type) {
		if (typeToSingleton.containsKey(type) == false) {
			typeToSingleton.put(type, (Singleton) type.newInstance());
		}
		return typeToSingleton.get(type);
	}
}
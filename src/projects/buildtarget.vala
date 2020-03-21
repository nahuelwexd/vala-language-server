using Gee;

abstract class Vls.BuildTarget : Object, Hashable<BuildTarget> {
    public string build_dir { get; construct; }
    public string name { get; construct; }
    public string id { get; construct; }
    public int no { get; construct; }

    /**
     * Input to the build target
     */
    public ArrayList<File> input { get; private set; default = new ArrayList<File> (Util.file_equal); }

    /**
     * Output of the build target
     */
    public ArrayList<File> output { get; private set; default = new ArrayList<File> (Util.file_equal); }

    public HashMap<File, BuildTarget> dependencies { get; private set; default = new HashMap<File, BuildTarget> (Util.file_hash, Util.file_equal); }

    public DateTime last_updated { get; protected set; }

    protected BuildTarget (string build_dir, string name, string id, int no) {
        Object (build_dir: build_dir, name: name, id: id, no: no);
    }

    /**
     * Build the target only if it needs to be built from its sources and if
     * its dependencies are newer than this target. This does not take care of 
     * building the target's dependencies.
     */
    public abstract void build_if_stale (Cancellable? cancellable = null) throws Error;

    public bool equal_to (BuildTarget other) {
        return build_dir == other.build_dir && name == other.name && id == other.id;
    }

    public uint hash () {
        return @"$build_dir::$name::$id".hash ();
    }
}

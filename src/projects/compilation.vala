using Gee;

class Vls.Compilation : BuildTarget {
    private HashSet<string> _packages = new HashSet<string> ();
    private HashSet<string> _defines = new HashSet<string> ();

    private HashSet<string> _vapi_dirs = new HashSet<string> ();
    private HashSet<string> _gir_dirs = new HashSet<string> ();
    private HashSet<string> _metadata_dirs = new HashSet<string> ();
    private HashSet<string> _gresources_dirs = new HashSet<string> ();

    /**
     * These are files that are part of the project.
     */
    private HashMap<File, TextDocument> _project_sources = new HashMap<File, TextDocument> (Util.file_hash, Util.file_equal);

    /**
     * These may not exist until right before we compile the code context.
     */
    private HashSet<File> _generated_sources = new HashSet<File> (Util.file_hash, Util.file_equal);

    public Vala.CodeContext code_context { get; private set; default = new Vala.CodeContext (); }

    // CodeContext arguments:
    private bool _deprecated;
    private bool _experimental;
    private bool _experimental_non_null;
    private bool _abi_stability;
    /**
     * The output directory.
     */
    private string _directory;
    private Vala.Profile _profile;
    private string? _entry_point_name;
    private bool _fatal_warnings;

    /**
     * Absolute path to generated VAPI
     */
    private string? _output_vapi;

    /**
     * Absolute path to generated GIR
     */
    private string? _output_gir;

    /**
     * Absolute path to generated internal VAPI
     */
    private string? _output_internal_vapi;

    /**
     * The reporter for the code context
     */
    public Reporter reporter {
        get {
            assert (code_context.report is Reporter);
            return (Reporter) code_context.report;
        }
    }

    public Compilation (string build_dir, string name, string id, int no,
                        string[] compiler, string[] args, string[] sources, string[] generated_sources) throws Error {
        base (build_dir, name, id, no);
        _directory = build_dir;

        // parse arguments
        var build_dir_file = File.new_for_path (build_dir);
        bool set_directory = false;
        string? flag_name, arg_value;           // --<flag_name>[=<arg_value>]
        for (int arg_i = -1; (arg_i = Util.iterate_valac_args (args, out flag_name, out arg_value)) < args.length;) {
            if (flag_name == "pkg") {
                _packages.add (arg_value);
            } else if (flag_name == "vapidir") {
                _vapi_dirs.add (arg_value);
            } else if (flag_name == "girdir") {
                _gir_dirs.add (arg_value);
            } else if (flag_name == "metadatadir") {
                _metadata_dirs.add (arg_value);
            } else if (flag_name == "gresourcesdir") {
                _gresources_dirs.add (arg_value);
            } else if (flag_name == "define") {
                _defines.add (arg_value);
            } else if (flag_name == "experimental") {
                _experimental = true;
            } else if (flag_name == "experimental-non-null") {
                _experimental_non_null = true;
            } else if (flag_name == "profile") {
                if (arg_value == "posix")
                    _profile = Vala.Profile.POSIX;
                else if (arg_value == "gobject")
                    _profile = Vala.Profile.GOBJECT;
                else
                    throw new ProjectError.INTROSPECTION (@"Compilation($id) unsupported Vala profile `$arg_value'");
            } else if (flag_name == "abi-stability") {
                _abi_stability = true;
            } else if (flag_name == "directory") {
                if (arg_value == null) {
                    warning ("Compilation(%s) null --directory", id);
                    continue;
                }
                _directory = Util.realpath (arg_value, build_dir);
                set_directory = true;
            } else if (flag_name == "vapi" || flag_name == "gir" || flag_name == "internal-vapi") {
                if (arg_value == null) {
                    warning ("Compilation(%s) --%s is null", id, flag_name);
                    continue;
                }

                string path = Util.realpath (arg_value, _directory);
                if (!set_directory)
                    warning ("Compilation(%s) no --directory before --%s, assuming %s", id, flag_name, _directory);
                if (flag_name == "vapi")
                    _output_vapi = path;
                else if (flag_name == "gir")
                    _output_gir = path;
                else
                    _output_internal_vapi = path;
            } else if (flag_name == null) {
                if (arg_value == null) {
                    warning ("Compilation(%s) failed to parse argument #%d (%s)", id, arg_i, args[arg_i]);
                } else if (Util.arg_is_file (arg_value)) {
                    var file_from_arg = File.new_for_path (Util.realpath (arg_value, _directory));
                    if (build_dir_file.get_relative_path (file_from_arg) != null)
                        _generated_sources.add (file_from_arg);
                    input.add (file_from_arg);
                }
            } else {
                warning ("Compilation(%s) ignoring argument #%d (%s)", id, arg_i, args[arg_i]);
            }
        }

        foreach (string source in sources) {
            input.add (File.new_for_path (Util.realpath (source, _directory)));
        }

        foreach (string generated_source in generated_sources) {
            var generated_source_file = File.new_for_path (Util.realpath (generated_source, _directory));
            _generated_sources.add (generated_source_file);
            input.add (generated_source_file);
        }
    }

    private void configure (Cancellable? cancellable = null) throws Error {
        // 1. recreate code context
        code_context = new Vala.CodeContext () {
            deprecated = _deprecated,
            experimental = _experimental,
            experimental_non_null = _experimental_non_null,
            abi_stability = _abi_stability,
            directory = _directory,
            vapi_directories = _vapi_dirs.to_array (),
            gir_directories = _gir_dirs.to_array (),
            metadata_directories = _metadata_dirs.to_array (),
            profile = _profile,
            keep_going = true,
            report = new Reporter (_fatal_warnings),
            entry_point_name = _entry_point_name,
            gresources_directories = _gresources_dirs.to_array ()
        };

        new Util.CodeContextRAII (code_context);

        switch (_profile) {
            case Vala.Profile.POSIX:
                code_context.add_define ("POSIX");
                break;
            case Vala.Profile.GOBJECT:
                code_context.add_define ("GOBJECT");
                break;
        }

        foreach (string define in _defines)
            code_context.add_define (define);

        if (!input.is_empty && _project_sources.is_empty) {
            debug ("Compilation(%s): will load input sources for the first time", id);
            foreach (File file in input) {
                if (!dependencies.has_key (file))
                    _project_sources[file] = new TextDocument (code_context, file, true);
                else
                    _generated_sources.add (file);

                if (cancellable != null && cancellable.is_cancelled ())
                    cancellable.set_error_if_cancelled ();
            }
        }

        foreach (TextDocument doc in _project_sources.values) {
            doc.context = code_context;
            code_context.add_source_file (doc);
            // clear all using directives (to avoid "T ambiguous with T" errors)
            doc.current_using_directives.clear ();
            // add default using directives for the profile
            if (_profile == Vala.Profile.POSIX) {
                // import the Posix namespace by default (namespace of backend-specific standard library)
                var ns_ref = new Vala.UsingDirective (new Vala.UnresolvedSymbol (null, "Posix", null));
                doc.add_using_directive (ns_ref);
                code_context.root.add_using_directive (ns_ref);
            } else if (_profile == Vala.Profile.GOBJECT) {
                // import the GLib namespace by default (namespace of backend-specific standard library)
                var ns_ref = new Vala.UsingDirective (new Vala.UnresolvedSymbol (null, "GLib", null));
                doc.add_using_directive (ns_ref);
                code_context.root.add_using_directive (ns_ref);
            }

            // clear all comments from file
            doc.get_comments ().clear ();

            // clear all code nodes from file
            doc.get_nodes ().clear ();
        }

        // packages (should come after in case we've wrapped any package files in TextDocuments)
        foreach (string package in _packages)
            code_context.add_external_package (package);
    }

    private void compile () throws Error {
        new Util.CodeContextRAII (code_context);
        var vala_parser = new Vala.Parser ();
        var genie_parser = new Vala.Genie.Parser ();
        var gir_parser = new Vala.GirParser ();

        // add all generated files before compiling
        foreach (File generated_file in _generated_sources) {
            // generated files are also part of the project, so we use TextDocument intead of Vala.SourceFile
            code_context.add_source_file (new TextDocument (code_context, generated_file));
        }

        // compile everything
        vala_parser.parse (code_context);
        genie_parser.parse (code_context);
        gir_parser.parse (code_context);
        code_context.check ();

        last_updated = new DateTime.now ();
    }

    public override void build_if_stale (Cancellable? cancellable = null) throws Error {
        bool stale = false;
        foreach (BuildTarget dep in dependencies.values) {
            if (dep.last_updated.compare (last_updated) > 0) {
                stale = true;
                break;
            }
        }
        foreach (TextDocument doc in _project_sources.values) {
            if (doc.last_updated.compare (last_updated) > 0) {
                stale = true;
                break;
            }
        }
        if (stale) {
            configure (cancellable);
            compile ();
        }
    }

    public bool lookup_input_source_file (File file, out Vala.SourceFile input_source) {
        string filename = Util.realpath (file.get_path ());
        foreach (var source_file in code_context.get_source_files ()) {
            if (source_file.filename == filename) {
                input_source = source_file;
                return true;
            }
        }
        input_source = null;
        return false;
    }
}

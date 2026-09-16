#import "Basic";
#import "Compiler";

#run {
    set_build_options_dc(.{ do_output = false });

    w := compiler_create_workspace("Jay_Core Asset Test");
    opts := get_build_options(w);

    new_path: [..]string;
    array_add(*new_path, ..opts.import_path);
    array_add(*new_path, "../../");
    opts.import_path = new_path;

    opts.output_type = .EXECUTABLE;
    opts.output_executable_name = "test_assets";
    opts.output_path = "./";

    set_build_options(opts, w);
    add_build_file("test_assets.jai", w);
}

Asset_Registry :: struct {
    #insert -> string {
        #import "Slang";
        #import "File";
        #import "File_Utilities";
        #import "Process";
        #import "String";
        #import "System";
        #import "Compiler";

        assets_in :: #run sprint("%/assets", get_working_directory());
        assets_out :: #run sprint("%/bin/assets", get_working_directory());

        handlers_in :: #run sprint("%/handlers", get_working_directory());

        sources: []string: #run -> []string {
            make_directory_if_it_does_not_exist(assets_in, true);
            return file_list(assets_in, true);
        }
        packages: []string: #run -> []string {
            delete_directory(assets_out);
            make_directory_if_it_does_not_exist(assets_out, true);
            return file_list(assets_out, true);
        }
        handlers: []string: #run -> []string {
            make_directory_if_it_does_not_exist(handlers_in, true);
            return file_list(handlers_in, true);
        }

        import_call :: ($code: Code, in: string, out: string) {
            import :: #insert code;

            data := import(in);
            write(out, data);
        }

        extract_asset_type :: (import: Code) -> u64 {
            status, root_type := get_root_type(import);
            assert(status == .SUCCESS, "Failed to resolve handler type for '%'.", import);

            proc_info := cast(*Type_Info_Procedure)root_type;
            assert(proc_info.return_types.count > 0, "Handler '%' must return a value.", import);

            ret_info := proc_info.return_types[0];
            assert(ret_info.type == .STRUCT, "Handler '%' must return a struct type.", import);

            ret_struct := cast(*Type_Info_Struct)ret_info;

            return reinterp(u64, ret_struct);
        }

        asset_types: [..]u64;

        #insert -> string {
            builder: String_Builder;

            known_ext: [..]string;

            for handlers {
                name := path_strip_extension(path_filename(it));

                print_to_builder(*builder, "    %_handler :: #import,file \"%\";\n", name, it);
                print_to_builder(*builder, "    array_add_if_unique(*asset_types, extract_asset_type(%_handler.import));\n", name);

                array_add_if_unique(*known_ext, name);
            }

            for sources {
                ext := path_extension(it);
                if !array_find(known_ext, ext) {
                    log("Unknown asset: %. Known assets: %", ext, known_ext);
                    continue;
                }
                relative_path := advance(it, assets_in.count);

                out := Name.from_path(relative_path);

                print_to_builder(*builder, "    import_call(%_handler.import, \"%\", \"%\");\n", ext, it, join(assets_out, sprint("/%.jpkg", out.id)));
            }

            return builder_to_string(*builder);
        }

        registry_builder: String_Builder;
        {
            for asset_types
                print_to_builder(*registry_builder, "    asset_%: Table(u64, #run reinterp(Type, %));\n", it, it); // just a way to pass type without any #import
        }

        return builder_to_string(*registry_builder);
    }
}

asset_registry: Asset_Registry;

get_assets :: ($asset_type: Type) -> Table(u64, asset_type) {
    return #insert #run sprint("asset_registry.asset_%;", reinterp(u64, type_info(asset_type)));
}

get_asset :: ($asset_type: Type, asset_name: Name) -> (*asset_type) {
    container := #insert #run sprint("asset_registry.asset_%;", reinterp(u64, type_info(asset_type)));

    asset := table_find_pointer(*container, asset_name.id);
    if asset
        return asset;

    asset_path := sprint("/%.jpkg", asset_name.id);
    defer free(asset_path);

    asset_in := join(path_strip_filename(get_path_of_running_executable()), "assets", asset_path);
    defer free(asset_in);

    loaded := read(asset_in, asset_type);

    return table_add(*container, asset_name.id, loaded);
}

unload_asset :: ($asset_type: Type, asset_name: Name) {
    container := #insert #run sprint("asset_registry.asset_%;", reinterp(u64, type_info(asset_type)));
    table_remove(*container, asset_name.id);
}

clear_asset_registry :: ($asset_type: Type) {
    container := #insert #run sprint("asset_registry.asset_%;", reinterp(u64, type_info(asset_type)));
    table_reset(*container);
}

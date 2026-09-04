#import "System";
#import "File";
#import "File_Utilities";
#import "Hash_Table";

#run {
    make_directory_if_it_does_not_exist(Paths.assets_user, true);
    make_directory_if_it_does_not_exist(Paths.assets_out, true);
    make_directory_if_it_does_not_exist(Paths.handlers, true);
}

Default_Handler :: struct {
    import :: read_entire_file; 
}

Asset_Registry :: struct {
     
    import_asset :: ($in: string, $name: Name) {
        #insert -> string {
            builder: String_Builder;

            ext := path_extension(in);
            handler_path := path_join(Paths.handlers, sprint("%.jai", ext));

            if file_exists(handler_path)
                print_to_builder(*builder, "    handler :: #import,file \"%\";\n", handler_path);
            else
                print_to_builder(*builder, "    handler :: Default_Handler;\n");
            return builder_to_string(*builder);
        }

        in_path :: #run get_asset_source_path(in);
        out_path :: #run path_join(Paths.assets_out, sprint("%.jpkg", name.id));
        
        in_mod, in_exists := file_modtime(in_path);
        out_mod, out_exists := file_modtime(out_path);

        if !in_exists return;
        if out_exists && in_mod <= out_mod return;

        log("Importing % -> %", in, sprint("%.jpkg", name.id));
        data := handler.import(in_path);
        write(out_path, data);

    }

}

get_assets :: ($asset_type: Type) -> *Table(u64, asset_type) {
    t_id := reinterp(u64, asset_type);
    table := table_find_pointer(*loaded_assets, t_id);

    if !table {
        new_table := Table(u64, asset_type);
        table_add(*loaded_assets, t_id, reinterp(Table(u64, *void), new_table));
        table = table_find_pointer(*loaded_assets, t_id);
    }
    return cast(*Table(u64, asset_type)) table;
}

get_asset :: ($asset_type: Type, $asset_name: string) -> *asset_type {
    return get_asset(asset_type, Name.static(asset_name));
} 

get_asset :: ($asset_type: Type, asset_name: Name) -> *asset_type {

    container := get_assets(asset_type);

    asset := table_find_pointer(container, asset_name.id);
    if asset
        return asset;

    asset_path := sprint("/%.jpkg", asset_name.id);
    defer free(asset_path);

    asset_in := join(path_strip_filename(get_path_of_running_executable()), "assets", asset_path);
    defer free(asset_in);

    if !file_exists(asset_in) return null;

    loaded, ok := read(asset_in, asset_type);
    assert(ok, "Asset % is not found.", asset_name);

    return table_add(container, asset_name.id, loaded);
}

get_asset_source_path :: (local: string) -> string {
    
    user_path := path_join(Paths.assets_user, local);
    if  file_exists(user_path) {
        return user_path;
    }
    engine_path := path_join(Paths.assets_engine, local);
    if file_exists(engine_path) {
        return engine_path;
    }

    return "";
}

get_asset_source :: (in: string) -> string {
    if file_exists(in)
        return read_entire_file(in);
    else 
        return "";
}

unload_asset :: ($asset_type: Type, asset_name: Name) {
    container := get_assets(asset_type);
    table_remove(container, asset_name.id);
}

clear_asset_registry :: ($asset_type: Type) {
    container := get_assets(asset_type);
    deinit(container);
    table_remove(*loaded_assets, container);
}

#scope_module

loaded_assets : Table(u64, Table(u64, *void));

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

HANDLE_NULL :: Handle.{void, 4294967295, 4294967295};

Handle :: struct {
    type: Type;
    index: u32;
    generation: u32;
}

is_null :: (handle: Handle) -> bool {
    return handle.index == 4294967295;
}

Asset_Registry :: struct {

    Asset_Slot :: struct {
        index:      u32;
        generation: u32;
        references: u32;
        object:     *void;
        name:       Name;
        has_name:   bool;
        data_key:   string;
    }

    add_type :: (type: Type, load: (slot: *Asset_Slot) -> bool, unload: (slot: *Asset_Slot)) {
        table_add(*registry, reinterp(u64, type), Type_Entry.{load, unload, .{}});
    }

    ensure_registered :: ($T: Type, load: (slot: *Asset_Slot) -> bool, unload: (slot: *Asset_Slot)) {
        if table_find_pointer(*registry, reinterp(u64, T)) != null return;
        add_type(T, load, unload);
    }

    register_asset_type :: (type: Type, load: (slot: *Asset_Slot) -> bool, unload: (slot: *Asset_Slot)) {
        assert(table_find_pointer(*registry, reinterp(u64, type)) == null, "Duplicate asset types: %", type);
        add_type(type, load, unload);
    }


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




retain :: ($asset_type: Type, name: Name) -> Handle {
    entry := table_find_pointer(*registry, reinterp(u64, asset_type));
    assert(entry != null, "Unknown asset type %", asset_type);
    storage := *entry.storage;

    found, existing := table_find(*storage.names, name.id);
    if found {
        assert(existing < cast(u32)storage.slots.count, "Asset name map out of sync");
        slot := *storage.slots[existing];
        assert(slot.references > 0, "Asset slot has no live references");
        slot.references += 1;
        return Handle.{asset_type, existing, slot.generation};
    }

    index := alloc_slot(storage);
    slot := *storage.slots[index];
    slot.name = name;
    slot.has_name = true;
    slot.references = 1;

    pkg_path := asset_package_path(name);
    defer free(pkg_path);
    loaded, read_ok := read(pkg_path, asset_type);
    if !read_ok {
        free_slot(storage, index);
        return HANDLE_NULL;
    }

    stored := New(asset_type);
    stored.* = loaded;
    slot.object = xx stored;

    if !entry.load(slot) {
        entry.unload(slot);
        free_slot(storage, index);
        return HANDLE_NULL;
    }

    table_add(*storage.names, name.id, index);
    return Handle.{asset_type, index, slot.generation};
}

retain :: (asset: $T) -> Handle {
    entry := table_find_pointer(*registry, reinterp(u64, T));
    if entry == null {
        log("Auto-registered trivial asset type %", T);
        Asset_Registry.add_type(T, trivial_asset_load, trivial_asset_unload);
        entry = table_find_pointer(*registry, reinterp(u64, T));
    }
    storage := *entry.storage;

    query := string.{data = cast(*u8)*asset, count = size_of(T)};
    found, existing := table_find(*storage.data_assets, query);
    if found {
        assert(existing < cast(u32)storage.slots.count, "Asset data map out of sync");
        slot := *storage.slots[existing];
        assert(slot.references > 0, "Asset slot has no live references");
        slot.references += 1;
        return Handle.{T, existing, slot.generation};
    }

    index := alloc_slot(storage);
    stored := New(T);
    stored.* = asset;

    slot := *storage.slots[index];
    slot.references = 1;
    slot.object = xx stored;

    if !entry.load(slot) {
        entry.unload(slot);
        free_slot(storage, index);
        return HANDLE_NULL;
    }
    slot.data_key = string.{data = cast(*u8)stored, count = size_of(T)};
    table_add(*storage.data_assets, slot.data_key, index);
    return Handle.{T, index, slot.generation};
}

release :: (handle: Handle) {
    if is_null(handle) return;

    entry := table_find_pointer(*registry, reinterp(u64, handle.type));
    assert(entry != null, "Unknown asset type %", handle.type);
    storage := *entry.storage;

    assert(handle.index < cast(u32)storage.slots.count, "Asset handle index out of range");
    slot := *storage.slots[handle.index];
    assert(slot.generation == handle.generation, "Stale asset handle");
    assert(slot.references > 0, "Asset handle already released");

    slot.references -= 1;
    if slot.references > 0 return;

    if slot.has_name {
        table_remove(*storage.names, slot.name.id);
    } else {
        table_remove(*storage.data_assets, slot.data_key);
    }
    entry.unload(slot);
    free_slot(storage, handle.index);
}

get_asset :: (handle: Handle, $T: Type) -> *T {
    assert(!is_null(handle), "Null asset handle");
    assert(handle.type == T, "Asset handle type mismatch");

    entry := table_find_pointer(*registry, reinterp(u64, T));
    assert(entry != null, "Unknown asset type %", T);
    storage := *entry.storage;

    assert(handle.index < cast(u32)storage.slots.count, "Asset handle index out of range");
    slot := *storage.slots[handle.index];
    assert(slot.generation == handle.generation, "Stale asset handle");
    assert(slot.references > 0, "Asset slot has no live references");
    assert(slot.object != null, "Asset slot is empty");
    return cast(*T)slot.object;
}


get_asset_source_path :: (local: string) -> string {
    user_path := path_join(Paths.assets_user, local);
    if file_exists(user_path) return user_path;

    engine_path := path_join(Paths.assets_engine, local);
    if file_exists(engine_path) return engine_path;

    return "";
}


get_asset_source :: (in: string) -> string {
    if file_exists(in)
        return read_entire_file(in);
    return "";
}

#scope_file

alloc_slot :: (storage: *Asset_Storage) -> u32 {
    index: u32;
    if storage.free.count > 0 {
        index = pop(*storage.free);
    } else {
        index = cast(u32)storage.slots.count;
        array_add(*storage.slots, Asset_Registry.Asset_Slot.{});
    }
    slot := *storage.slots[index];
    slot.index = index;
    slot.references = 0;
    slot.object = null;
    slot.has_name = false;
    slot.name = .{};
    slot.data_key = .{};
    return index;
}

free_slot :: (storage: *Asset_Storage, index: u32) {
    slot := *storage.slots[index];
    slot.references = 0;
    slot.object = null;
    slot.has_name = false;
    slot.name = .{};
    slot.data_key = .{};
    slot.generation += 1;
    array_add(*storage.free, index);
}

is_valid :: (handle: Handle) -> bool {
    if is_null(handle) return false;
    entry := table_find_pointer(*registry, reinterp(u64, handle.type));
    if entry == null return false;
    storage := *entry.storage;
    if handle.index >= cast(u32)storage.slots.count return false;
    slot := storage.slots[handle.index];
    if slot.generation != handle.generation return false;
    if slot.references == 0 return false;
    return slot.object != null;
}

asset_package_path :: (name: Name) -> string {
    return join(path_strip_filename(get_path_of_running_executable()), "assets", sprint("/%.jpkg", name.id));
}

trivial_asset_load :: (slot: *Asset_Registry.Asset_Slot) -> bool {
    return slot.object != null;
}

trivial_asset_unload :: (slot: *Asset_Registry.Asset_Slot) {
    if slot.object != null free(slot.object);
    slot.object = null;
}

Asset_Storage :: struct {
    slots: [..] Asset_Registry.Asset_Slot;
    free: [..] u32;
    names: Table(u64, u32);       // file path: Name.id -> slot
    data_assets: Table(string, u32); // value path: raw bytes -> slot
}

Type_Entry :: struct {
    load: (slot: *Asset_Registry.Asset_Slot) -> bool;
    unload: (slot: *Asset_Registry.Asset_Slot);
    storage: Asset_Storage;
}

registry: Table(u64, Type_Entry);

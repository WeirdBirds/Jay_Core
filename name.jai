Name :: struct {
    id: u64;

    static :: ($src: string) -> Name {
        return #run,stallable -> Name {
             name :: #run Name.new(src);
             Asset_Registry.import_asset(src, name);
             return name;
        };
    }

    new :: (src: string) -> Name {
        #import "Hash";
        path_overwrite_separators(src);

        data := src.data;
        count := src.count;

        if src[0] == "/" {
            data += 1;
            count -=1;
        }

        copy := alloc_string(count);
        memcpy(copy.data, data, count);

        return Name.{ id = fnv1a_hash(data, count)};
    }
}

operator == :: inline (a: Name, b: Name) -> bool {
    return a.id == b.id;
}

operator == :: inline (a: Name, b: u64) -> bool #symmetric {
    return a.id == b;
}

#scope_file

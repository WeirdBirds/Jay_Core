Name :: struct {
    id: u64;

    new :: ($src: string) -> Name {
        return #run -> Name {
            #import "Hash";

            return Name.{ id = fnv1a_hash(src.data, src.count) };
        };
    }

    from_path :: ($src: string) -> Name {
        return #run -> Name {
            #import "Hash";

            normalized: [src.count]u8;
            out_count := 0;
            is_absolute := src.count > 0 && (src[0] == #char "/" || src[0] == #char "\\");
            i := 0;

            if is_absolute {
                normalized[out_count] = #char "/";
                out_count += 1;
            }

            while i < src.count {
                while i < src.count {
                    c := src[i];
                    if c != #char "/" && c != #char "\\"
                        break;
                    i += 1;
                }

                if i >= src.count
                    break;

                segment_start := i;

                while i < src.count {
                    c := src[i];
                    if c == #char "/" || c == #char "\\"
                        break;
                    i += 1;
                }

                segment_count := i - segment_start;
                if segment_count == 1 && src[segment_start] == #char "."
                    continue;

                if out_count > 0 && normalized[out_count - 1] != #char "/" {
                    normalized[out_count] = #char "/";
                    out_count += 1;
                }

                for segment_start..segment_start + segment_count - 1 {
                    normalized[out_count] = src[it];
                    out_count += 1;
                }
            }

            if out_count == 0 {
                normalized[out_count] = #char ".";
                out_count += 1;
            }

            return Name.{ id = fnv1a_hash(normalized.data, out_count) };
        };
    }

    from_path :: (src: string) -> Name {
        #import "Hash";

        normalized := NewArray(src.count, u8);
        defer free(normalized.data);
        out_count := 0;
        is_absolute := src.count > 0 && (src[0] == #char "/" || src[0] == #char "\\");
        i := 0;

        if is_absolute {
            normalized[out_count] = #char "/";
            out_count += 1;
        }

        while i < src.count {
            while i < src.count {
                c := src[i];
                if c != #char "/" && c != #char "\\"
                    break;
                i += 1;
            }

            if i >= src.count
                break;

            segment_start := i;

            while i < src.count {
                c := src[i];
                if c == #char "/" || c == #char "\\"
                    break;
                i += 1;
            }

            segment_count := i - segment_start;
            if segment_count == 1 && src[segment_start] == #char "."
                continue;

            if out_count > 0 && normalized[out_count - 1] != #char "/" {
                normalized[out_count] = #char "/";
                out_count += 1;
            }

            for segment_start..segment_start + segment_count - 1 {
                normalized[out_count] = src[it];
                out_count += 1;
            }
        }

        if out_count == 0 {
            normalized[out_count] = #char ".";
            out_count += 1;
        }

        return Name.{ id = fnv1a_hash(normalized.data, out_count) };
    }
}

operator == :: inline (a: Name, b: Name) -> bool {
    return a.id == b.id;
}

operator == :: inline (a: Name, b: u64) -> bool #symmetric {
    return a.id == b;
}

// procs_dummy :: Proc_Item.[];
// deps_dummy :: Type.[];

Proc_Item :: struct {
    name: string;
    args: []Type;
}

Mixer :: struct (in_mixins: ..Type, procs: []Proc_Item, _deps: []Type)  {
    mixins :: #run,stallable -> []Type {
        result: [..]Type;
        array_add(*result, ..in_mixins);
        array_add(*result, .._deps);
        return result;
    }
    #insert -> string {

        #import "Hash_Table";

        nodes := sort(mixins);

        log("Mixins is: %", nodes);

        builder: String_Builder = .{};

        calls: Table(string, String_Builder) = .{};

        type_indices: [..]u64;

        for procs {
            in_args := NewArray(it.args.count, string,, temp);
            for arg, index: it.args {
                if (cast(*Type_Info)arg).type == .POINTER {
                    arg_info := cast(*Type_Info_Pointer)arg;
                    arg_type_index := cast(u64)arg_info.pointer_to;
                    array_add_if_unique(*type_indices, arg_type_index);
                    in_args[index] = sprint("arg%: *type_%", index, arg_type_index);
                } else {
                    arg_type_index := reinterp(u64, arg);
                    array_add_if_unique(*type_indices, arg_type_index);
                    in_args[index] = sprint("arg%: type_%", index, arg_type_index);
                }
            }
            in_args_string := join(..in_args, ", ",, temp);
            find_or_add(*calls, sprint("% :: (%)", it.name, in_args_string));
        }

        for mix_t: nodes {
            success, n_index := array_find(mixins, mix_t);

            assert(success);

            it := cast(*Type_Info_Struct)mix_t;

            for member, m_index: it.members {
                if member.flags == .CONSTANT && member.type.type == .PROCEDURE {
                    proc_info := cast(*Type_Info_Procedure) member.type;

                    if procs.count > 0 {
                        args: [..] Type;

                        for arg, index: proc_info.argument_types {
                            array_add(*args, reinterp(Type, arg));
                        }

                        item := Proc_Item.{
                            member.name,
                            args
                        };

                        is_valid := false;

                        for procs {
                            if it.args.count != item.args.count then continue;
                            for index: 0..it.args.count-1 {
                                if it.args[index] != item.args[index] then continue;
                            }
                            if equal(it.name, item.name) {
                                is_valid = true;
                                break;
                            }
                        }

                        if !is_valid {
                            // print("\x1b[31m[Error] This mixer have specified list of procedures. The procedure \x1b[0m'%.%(...)'\x1b[31m is skipped because it's not in a list!\x1b[0m\n", it.name, member.name);
                            continue;
                        }
                    }

                    if proc_info.return_types.count > 0 {
                        print("\x1b[31m[Error] Node procedures should not have return values. The procedure \x1b[0m'%.%(...)'\x1b[31m is skipped!\x1b[0m\n", it.name, member.name);
                        continue;
                    }

                    in_args := NewArray(proc_info.argument_types.count, string,, temp);
                    args := NewArray(proc_info.argument_types.count, string,, temp);


                    for arg, index: proc_info.argument_types {
                        if (arg.type == .POINTER) {
                            arg_info := cast(*Type_Info_Pointer)arg;
                            arg_type_index := cast(u64)arg_info.pointer_to;
                            array_add_if_unique(*type_indices, arg_type_index);
                            in_args[index] = sprint("arg%: *type_%",index, arg_type_index);
                            args[index] = sprint("arg%",index);
                        } else {
                            arg_type_index := cast(u64)arg;
                            array_add_if_unique(*type_indices, arg_type_index);
                            in_args[index] = sprint("arg%: type_%",index, arg_type_index);
                            args[index] = sprint("arg%",index);
                        }

                    }
                    in_args_string := join(..in_args, ", ",, temp);
                    args_string := join(..args, ", ",, temp);

                    append(find_or_add(*calls, sprint("% :: (%)", member.name, in_args_string)), sprint("        mixins[%].%(%);\n", n_index, member.name, args_string,, temp));
                }
            }
        }

        for t_index: type_indices {
            print_to_builder(*builder, "    type_% :: #run -> Type { t_index := %; return reinterp(Type, t_index); }\n", t_index, t_index);
        }

        for call, type: calls {
            if type.count {
                print_to_builder(*builder, "    % {\n%\n\t}\n", type, builder_to_string(*call));
            }
        }

        return builder_to_string(*builder);
    }
}


#scope_file


operator == :: inline (a: Proc_Item, b: Proc_Item) -> bool {
    if a.args.count != b.args.count then return false;
    for index: 0..a.args.count-1 {
        if a.args[index] != b.args[index] then return false;
    }
    return equal(a.name, b.name);
}

Node_Info :: struct {
    value: Type;
    heat: s64;
    edges: [..] s64;
}

sort :: (mixins: []Type) -> []Type {
    result := NewArray(mixins.count, Type);
    nodes := NewArray(mixins.count, Node_Info);

    for mixin, m_index: mixins {
        m_info := cast(*Type_Info_Struct)mixin;
        nodes[m_index].value = mixin;
        for member: m_info.members {
            type := reinterp(Type, member.type);
            t_info:= (cast(**Type_Info_Struct) *member.type).*;

            if member.name == "before" {
                is_listed, b_index := array_find(mixins, type);
                if type == Type {
                    print("\x1b[31m[Error] 'before' declared as a type in % mixin, not a variable. Use 'before: %;' declaration\x1b[0m\n", m_info.name, type);
                    continue;
                }
                if !is_listed {
                    print("\x1b[31m[Error] % is not a mixer item, but declared as 'before' in\x1b[0m '%'\n", type, m_info.name);
                    continue;
                }

                if(!array_find(nodes[m_index].edges, b_index)) {
                    array_add(*nodes[m_index].edges, b_index);
                    nodes[b_index].heat += 1;
                }
            }
            if member.name == "after" {
                is_listed, b_index := array_find(mixins, type);
                if type == Type {
                    print("\x1b[31m[Error] 'after' declared as a type in % mixin, not a variable. Use 'after: %;' declaration\x1b[0m\n", m_info.name, type);
                    continue;
                }
                if !is_listed {
                    print("\x1b[31m[Error] % is not a mixer item, but declared as 'after' in\x1b[0m '%'\n", type, m_info.name);
                    continue;
                }
                if(!array_find(nodes[b_index].edges, m_index)) {
                    array_add(*nodes[b_index].edges, m_index);
                    nodes[m_index].heat += 1;
                }
            }
        }
    }

    for next, n_index: result {
        for *info, h_index: nodes {
            if info.heat == 0 {
                result[n_index] = info.value;
                next = mixins[h_index];
                info.heat = -1;
                for edge: info.edges {
                    nodes[edge].heat -= 1;
                }
                break;
            }
        }
    }
    return result;
}

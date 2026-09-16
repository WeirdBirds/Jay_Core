#import "Basic";
#import "Jay_Core";

Package :: #import "Jay_Package";

Test_Blob :: struct {
    a, b, c, d: s32;
}

Matrix_Blob :: struct {
    cells: [16]float32;
}

Fail_Blob :: struct {
    tag: s64;
}

Ready_Blob :: struct {
    a: s32;
    ready: bool;
}

load_calls: s64 = 0;
unload_calls: s64 = 0;

counting_load :: (slot: *Asset_Registry.Asset_Slot) -> bool {
    load_calls += 1;
    return slot.object != null;
}

counting_unload :: (slot: *Asset_Registry.Asset_Slot) {
    unload_calls += 1;
    if slot.object != null free(slot.object);
    slot.object = null;
}

failing_load :: (slot: *Asset_Registry.Asset_Slot) -> bool {
    load_calls += 1;
    return false;
}

ready_load :: (slot: *Asset_Registry.Asset_Slot) -> bool {
    load_calls += 1;
    if slot.object == null return false;
    o := cast(*Ready_Blob)slot.object;
    o.ready = true;
    return true;
}

main :: () {
    Asset_Registry.register_asset_type(Fail_Blob, failing_load, counting_unload);
    Asset_Registry.register_asset_type(Ready_Blob, ready_load, counting_unload);

    test_value_retain_get();
    test_value_dedup();
    test_value_distinct();
    test_refcount();
    test_stale_and_reuse();
    test_load_failure();
    test_file_backed();
    test_static_array_blob();
    test_load_finalizes();

    log("All Jay_Core asset tests passed.\n");
}

test_value_retain_get :: () {
    h := retain(Test_Blob.{1, 2, 3, 4});
    assert(is_valid(h));

    p := get_asset(h, Test_Blob);
    assert(p.a == 1 && p.b == 2 && p.c == 3 && p.d == 4);

    release(h);
    assert(!is_valid(h));
}

test_value_dedup :: () {
    h1 := retain(Test_Blob.{5, 6, 7, 8});
    h2 := retain(Test_Blob.{5, 6, 7, 8});
    assert(h1.index == h2.index && h1.generation == h2.generation);

    release(h1);
    assert(is_valid(h2));

    release(h2);
    assert(!is_valid(h2));
}

test_value_distinct :: () {
    h1 := retain(Test_Blob.{1, 1, 1, 1});
    h2 := retain(Test_Blob.{2, 2, 2, 2});
    assert(h1.index != h2.index);

    release(h1);
    release(h2);
    assert(!is_valid(h1) && !is_valid(h2));
}

test_refcount :: () {
    h1 := retain(Test_Blob.{3, 3, 3, 3});
    h2 := retain(Test_Blob.{3, 3, 3, 3});
    h3 := retain(Test_Blob.{3, 3, 3, 3});

    release(h1);
    release(h2);
    assert(is_valid(h3));

    p := get_asset(h3, Test_Blob);
    assert(p.a == 3);

    release(h3);
    assert(!is_valid(h3));
}

test_stale_and_reuse :: () {
    h1 := retain(Test_Blob.{9, 9, 9, 9});
    release(h1);
    assert(!is_valid(h1));

    h2 := retain(Test_Blob.{8, 8, 8, 8});
    assert(is_valid(h2));
    assert(h1.index != h2.index || h1.generation != h2.generation);
    assert(!is_valid(h1));

    release(h2);
}

test_load_failure :: () {
    l0 := load_calls;
    u0 := unload_calls;

    h := retain(Fail_Blob.{123});
    assert(is_null(h));
    assert(load_calls == l0 + 1);
    assert(unload_calls == u0 + 1);

    ok := retain(Test_Blob.{7, 7, 7, 7});
    assert(is_valid(ok));
    release(ok);
}

test_file_backed :: () {
    name := Name.new(tprint("/test/value_blob"));
    pkg := asset_package_path(name);
    defer free(pkg);
    Package.write(pkg, Test_Blob.{11, 22, 33, 44});

    h1 := retain(Test_Blob, name);
    assert(is_valid(h1));

    p := get_asset(h1, Test_Blob);
    assert(p.a == 11 && p.b == 22 && p.c == 33 && p.d == 44);

    h2 := retain(Test_Blob, name);
    assert(h1.index == h2.index && h1.generation == h2.generation);

    release(h1);
    assert(is_valid(h2));

    release(h2);
    assert(!is_valid(h2));

    missing := retain(Test_Blob, Name.new(tprint("/test/does_not_exist")));
    assert(is_null(missing));
}

test_load_finalizes :: () {
    h := retain(Ready_Blob.{42, false});
    assert(is_valid(h));

    p := get_asset(h, Ready_Blob);
    assert(p.a == 42 && p.ready);

    release(h);
    assert(!is_valid(h));
}

test_static_array_blob :: () {
    m: Matrix_Blob;
    for i: 0..15 m.cells[i] = cast(float32)(i * 2);

    h := retain(m);
    assert(is_valid(h));

    q := get_asset(h, Matrix_Blob);
    assert(q.cells[0] == 0 && q.cells[15] == 30);

    release(h);
    assert(!is_valid(h));
}

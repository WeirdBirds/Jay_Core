Packages :: #bake_arguments Mixer(procs=.[
    .{"init",           .[*Engine]},
    .{"before_begin",   .[*Engine]},
    .{"begin",          .[*Engine]},
    .{"after_begin",    .[*Engine]},
    .{"before_tick",    .[*Engine]},
    .{"tick",           .[*Engine]},
    .{"after_tick",     .[*Engine]},
    .{"before_end",     .[*Engine]},
    .{"end",            .[*Engine]},
    .{"after_end",      .[*Engine]}
], _deps = .[
    Lifecycle.InputComplete,
    Lifecycle.SimulationComplete,
    Lifecycle.RenderComplete
] );

Lifecycle :: struct {
    InputComplete :: struct {}
    SimulationComplete :: struct { after: InputComplete; }
    RenderComplete :: struct { after: SimulationComplete; }
}

Timer :: struct {
    time:             float64;
    delta_time:       float64;
    _last_tick_time:  Apollo_Time;
    _first_tick_time: Apollo_Time;
}

Engine :: struct($packages: Type) #modify {
    t_info := cast(*Type_Info)packages;

    if t_info.type != .STRUCT {
        print("\x1b[31m[Error] Unknown packages type (no struct):\x1b[0m %\n", packages);

        return false;
    }
    s_info := cast(*Type_Info_Struct)packages;

    if s_info.polymorph_source_struct != cast(*Type_Info_Struct)Packages {
        print("\x1b[31m[Error] Unknown packages type:\x1b[0m %\n", packages);
        print("\x1b[31m[Error] Use 'Packages(Your_Package1, Your_Package2)' here.");
        return false;
    }
    return true;
} {
    system_threads: Thread_Group = .{};
    is_running:     bool         = true;
    timer: Timer;
}

has_package :: inline (in_engine: *$Engine, $package: Type) -> bool {
    return array_find(engine.packages.in_mixins);
}

run :: (in_engine: *Engine) {
    in_engine.timer._first_tick_time = current_time_monotonic();
    
    in_engine.packages.before_begin(in_engine);
    in_engine.packages.begin(in_engine);
    in_engine.packages.after_begin(in_engine);

    while in_engine.is_running {

        current_tick := current_time_monotonic();
        in_engine.timer.time            = to_float64_seconds(current_tick - in_engine.timer._first_tick_time);
        in_engine.timer.delta_time      = to_float64_seconds(current_tick - in_engine.timer._last_tick_time);
        in_engine.timer._last_tick_time = current_tick;
        
        in_engine.packages.before_tick(in_engine);
        in_engine.packages.tick(in_engine);
        in_engine.packages.after_tick(in_engine);
    }

    in_engine.packages.before_end(in_engine);
    in_engine.packages.end(in_engine);
    in_engine.packages.after_end(in_engine);
}



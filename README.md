# Jay_Core

The central module of the Jay engine. It provides the main loop, a package composition system, hashed names, and an asset pipeline.

## Engine

`Engine` is a generic struct parameterized by a `Packages` type. You build a `Packages` by listing your package structs (each one is a module that hooks into the engine lifecycle), and `Engine` runs them in order.

The lifecycle has nine phases, called in this order:

1. `before_begin`
2. `begin`
3. `after_begin`
4. *main loop starts*
5. `before_tick` (every frame)
6. `tick` (every frame)
7. `after_tick` (every frame)
8. *main loop ends when `engine.is_running` is set to false*
9. `before_end`
10. `end`
11. `after_end`

Each package struct defines whichever of these callbacks it needs. The engine calls them all, in dependency order, every frame.

A built-in `Timer` tracks `time` (seconds since start) and `delta_time` (seconds since last tick).

### Lifecycle dependencies

Three dependency markers control ordering between packages:

- `Lifecycle.InputComplete`
- `Lifecycle.SimulationComplete`
- `Lifecycle.RenderComplete`

A package declares ordering with struct members like `after: Lifecycle.InputComplete;` or `before: Lifecycle.RenderComplete;`. The Mixer (see below) uses these to topologically sort packages at compile time.

## Mixer

The Mixer is a compile-time composition system. Given a list of package types and a set of procedure signatures, it:

1. Reads `before` / `after` dependency members from each package struct.
2. Topologically sorts the packages.
3. Generates combined procedures that call each package's matching callback in the sorted order.

All of this happens at compile time via `#insert` — there is no runtime dispatch or vtable.

## Name

`Name` is a hashed identifier — a `u64` produced by FNV-1a. Two ways to create one:

- `Name.new("player")` — hash a plain string (compile-time when the argument is constant).
- `Name.from_path("/assets/textures/wall.png")` — normalizes path separators and strips `.` segments before hashing, so `assets/textures/wall.png` and `assets\textures\wall.png` produce the same id.

`from_path` has both a compile-time (`$src`) and a runtime (`src`) overload.

Names are compared by id (`==` is overloaded for `Name` vs `Name` and `Name` vs `u64`).

## Assets

The asset system discovers files in `assets/`, matches them to handlers in `handlers/`, and packages them into `.jpkg` files under `bin/assets/` at compile time.

How it works:

1. `Asset_Registry` scans the `handlers/` directory. Each handler file (e.g. `png.jai`) exports an `import` procedure that reads a source file and returns a typed struct.
2. It scans `assets/` for source files. A file's extension is matched to a handler by name — `wall.png` uses `png.jai`.
3. At compile time, each matched asset is imported and serialized to `bin/assets/<name-hash>.jpkg`.
4. At runtime, `get_asset(Type, name)` lazily loads a `.jpkg` file into a typed hash table keyed by `Name.id`.

```jai
// Get a pointer to a loaded asset (loads from disk on first access)
tex := get_asset(Texture_Data, Name.from_path("/textures/wall.png"));

// Unload a single asset
unload_asset(Texture_Data, Name.from_path("/textures/wall.png"));

// Clear all assets of a type
clear_asset_registry(Texture_Data);
```

## Dependencies

- `Jay_Utils`
- `Jay_Package` (serialization for the asset pipeline)
- `Jay_Math`
- `Jay_Logger`
- Jai standard modules: `Basic`, `String`, `Thread`

# abi_fix.md — `Maybe(^T)` foreign-call ABI fix (32-bit x86)

Date: 2026-08-08
Status: implemented & verified

## Symptom
On 32-bit x86 only, passing `Maybe(^T)` (e.g. `Maybe(^Texture)`, `Maybe(^Rect)`)
to a foreign C function produced garbage: SDL reported
`Parameter 'texture' is invalid` even for `nil`, geometry/rendering silently failed.
x86_64 worked fine.

## Root cause
`Maybe(^T)` is a 1-variant union of an internally pointer-like type and lowers to an
LLVM **1-element struct `{ptr}`** (`lb_type_internal`, `Type_Union`,
`is_type_union_maybe_pointer_original_alignment`). The stored value is the real
pointer (null = `none`).

The foreign proc's LLVM signature used that struct type for the parameter
(`lb_type_internal_for_procedures_raw`). ABI classification then diverged:

- **x86_64 (SysV)**: small structs pass **directly in a register** -> C reads the pointer. Works by luck.
- **i386** (`lbAbi386::compute_arg_types`): *all* structs pass **indirectly (by pointer to the struct)**
  -> the C callee reads a pointer-to-struct as if it were the texture pointer -> garbage.

## Fix (Option A)
In `src/llvm_backend_general.cpp` (`lb_type_internal_for_procedures_raw`, param loop):
lower a union-maybe-pointer parameter to its **plain pointer LLVM type** instead of `{ptr}`:

```cpp
} else if (is_type_union_maybe_pointer(e_type)) {
    // Maybe(^T) is ABI-passed as the plain pointer value. Matches C's
    // nullable-pointer ABI (and what x86_64 SysV already does for the
    // 1-element {ptr} struct); without this, i386 passes the {ptr} struct
    // by pointer and the C callee reads a garbage pointer.
    param_type = lb_type(m, base_type(e_type)->Union.variants[0]);
}
```

The call site already transmutes the `{ptr}` value to the ABI type
(`OdinLLVMBuildTransmute`), extracting the correct pointer.

Effect: `Maybe(^T)` foreign parameters are passed by value as a plain pointer on
every target — exactly what x86_64 effectively did, now explicit and correct on i386 too.

## Validation
- Rebuilt the compiler (`build_odin.sh release-native`).
- Restored idiomatic `Maybe(^Texture)`/`Maybe(^Rect)`/`Maybe(^FRect)` in the SDL3 bindings
  (`vendor/odin/vendor/sdl3/sdl3_render.odin`) — previously worked around with plain `^T`.
- dxf app built & deployed on both emulators:
  - x86 (api30): 0 texture errors, viewport + model render.
  - x86_64 (pixel9): 0 texture errors, render unchanged.

## Files changed
- `src/llvm_backend_general.cpp` — the ABI fix (the only compiler change).
- `vendor/sdl3/sdl3_render.odin` — bindings back to idiomatic `Maybe(...)` (no functional change vs the `^T` workaround).

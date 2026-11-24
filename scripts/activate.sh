# Sourced by pixi on every `pixi shell` / `pixi run` (sourced, not exec'd).
# Prepares the conda-forge sysroot so the Swift toolchain can use it.
# Idempotent and fast, so it repairs itself after `pixi install` / `pixi clean`.

_TOOLS="$PIXI_PROJECT_ROOT/.pixi/tools"
_SWIFT="$_TOOLS/swift"
_SYSROOT="$CONDA_PREFIX/x86_64-conda-linux-gnu/sysroot"

export SDKROOT="$_SYSROOT"
export PATH="$_TOOLS/bin:$_SWIFT/usr/bin:$PATH"

mkdir -p "$_TOOLS/bin" "$_SYSROOT/usr/lib" "$_SYSROOT/usr/lib64" "$_SYSROOT/usr/lib/gcc/x86_64-linux-gnu"

# gcc (crtbegin.o, libgcc) under a target triple that clang recognizes
for _d in "$CONDA_PREFIX"/lib/gcc/x86_64-conda-linux-gnu/*/; do
  _d="${_d%/}"
  [ -d "$_d" ] && ln -sfn "$_d" "$_SYSROOT/usr/lib/gcc/x86_64-linux-gnu/$(basename "$_d")"
done

# linker without the conda triple prefix
for _l in ld ld.gold; do
  [ -e "$CONDA_PREFIX/bin/x86_64-conda-linux-gnu-$_l" ] && \
    ln -sfn "$CONDA_PREFIX/bin/x86_64-conda-linux-gnu-$_l" "$_TOOLS/bin/$_l"
done

# libstdc++ / libgcc_s (Swift runtime dependencies)
for _f in libstdc++.so libstdc++.so.6 libgcc_s.so libgcc_s.so.1; do
  [ -e "$CONDA_PREFIX/lib/$_f" ] && ln -sfn "$CONDA_PREFIX/lib/$_f" "$_SYSROOT/usr/lib64/$_f"
done

# Swift runtime – with -sdk, the driver looks for it in $SDK/usr/lib/swift
if [ -d "$_SWIFT/usr/lib/swift" ]; then
  ln -sfn "$_SWIFT/usr/lib/swift"        "$_SYSROOT/usr/lib/swift"
  ln -sfn "$_SWIFT/usr/lib/swift_static" "$_SYSROOT/usr/lib/swift_static"
fi

# Default sysroot for the toolchain's clang – works even when something (xtool) drops SDKROOT.
# Clang reads <triple>.cfg from the directory next to its binary; it only applies to the
# Linux target, so iOS builds (arm64-apple-ios) are unaffected.
if [ -d "$_SWIFT/usr/bin" ]; then
  _CFG="$_SWIFT/usr/bin/x86_64-unknown-linux-gnu.cfg"
  _WANT="--sysroot=$_SYSROOT"
  [ "$(cat "$_CFG" 2>/dev/null)" = "$_WANT" ] || printf '%s\n' "$_WANT" > "$_CFG"
fi

unset _CFG _WANT _TOOLS _SWIFT _SYSROOT _d _l _f

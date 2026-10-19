# xlang

An Xmake addon providing the `xclang` standalone toolchain.
It uses [Xclang](https://github.com/clice-io/xclang), including its target configurations,
bundled sysroots and runtime libraries. Requires Xmake 3.1.1 or later with addon support.

## Install

Until a release is tagged, install the Git branch after the recipe is available in your
configured package repository:

```sh
xmake addon --install "xlang main"
```

Or install the working copy:

```sh
xmake addon --install .
```

Then select the addon toolchain in your project:

```lua
add_addons("xlang")
set_toolchains("@addon/xlang/xclang")
set_languages("c11", "c++20")

target("hello")
    set_kind("binary")
    add_files("src/main.cpp")
```

Use an existing Xclang distribution:

```sh
xmake f -p linux -a x86_64 --sdk=/path/to/xclang
xmake
```

Alternatively, pass `--bin=/path/to/xclang/bin` or put its `bin` directory on `PATH`.
An explicit SDK/bindir is checked in isolation and does not fall back to another LLVM.
The selected distribution must contain `xclang`, `clang`, and the target's `.cfg` file.

## Download the SDK as a package

The `xclang` SDK package is defined in xmake-repo. Declare it and associate it with the
addon toolchain:

```lua
add_addons("xlang")
add_requires("xclang 23.1.2+10")
set_toolchains("@addon/xlang/xclang", {packages = "xclang"})
set_languages("c++20")

target("hello")
    set_kind("binary")
    add_files("src/main.cpp")
```

`xmake f -p linux -a arm64 -y` downloads the host SDK
and selects its Linux ARM64 target. Installing the addon alone does not download the SDK.

## Targets

| Platform | Target configuration examples |
| --- | --- |
| `linux` | `x86_64-unknown-linux-gnu`, `aarch64-unknown-linux-gnu` |
| `mingw` | `x86_64-w64-windows-gnu`, `aarch64-w64-windows-gnu` |
| `windows` | `x86_64-pc-windows-msvc`, `aarch64-pc-windows-msvc` |
| `macosx` | `x86_64-apple-darwin`, `aarch64-apple-darwin` |
| `cross` | Explicit triple supplied through `--cross=<triple>-` |

Availability depends on the selected SDK's `.cfg` files and sysroots. The addon does not
provision a Windows MSVC SDK. All compiler, linker and LLVM utility paths stay within
the selected distribution; runtime defaults match the original toolchain implementation.

## Tests

```sh
xmake lua tests/test.lua
```

This installs the working copy and tests namespaced addon resolution, target selection,
absolute tool paths, PATH discovery without `which`/`where`, and explicit-SDK isolation.
Discovery fixtures do not require a compiler. Set `XCLANG_SDK` or put `xclang` on `PATH`
to additionally check an actual distribution and build the C/C++/shared-library smoke project
for Linux, MinGW and macOS on both architectures. Compatible host binaries are also run.
Other target builds are not executed. No SDK is downloaded by the tests.

The runner isolates addon registration and caches in a temporary `XMAKE_GLOBALDIR`.
`XCLANG_SDK` is used by the test runner; normal project configuration uses `--sdk` or `--bin`.

## License

Apache-2.0. The toolchain implementation retains its Xmake copyright and license headers.

# xclang

An Xmake addon for [Xclang](https://github.com/clice-io/xclang), a Clang distribution
with target configurations, bundled sysroots and runtime libraries.
Requires Xmake 3.1.1 or later with addon support.

## Use the SDK package

The addon distributes the toolchain definition. The SDK package is provided by xmake-repo:

```lua
add_addons("xclang 1.0.2")
add_requires("xclang 23.1.2+10", {system = false})
set_languages("c++20")

target("hello")
    set_kind("binary")
    set_toolchains("@addon/xclang/xclang", {packages = "xclang"})
    add_files("src/main.cpp")
```

```sh
xmake -y
```

Xmake installs the addon first, then installs the SDK package. The `packages` option
binds the SDK to the addon toolchain, which locates its tools in the package's installation
directory. No manual addon installation, SDK path or PATH change is required.

The addon and SDK are both named `xclang`, but are resolved from `addons/` and `packages/`
respectively. Installing the addon alone does not download the SDK.
Omit either version constraint to use the latest version available from the repository.

For cross compilation, select the target platform and architecture as usual:

```sh
xmake f -p linux -a arm64 -y
xmake -y
```

The SDK package is selected for the host running the compiler; the toolchain selects
the requested target's `.cfg` file. See [examples/hello](examples/hello) for a runnable project.

## Use an existing SDK

Select the toolchain directly when supplying your own SDK:

```lua
add_addons("xclang")
set_languages("c++20")

target("hello")
    set_kind("binary")
    set_toolchains("@addon/xclang/xclang")
    add_files("src/main.cpp")
```

```sh
xmake f -p linux -a x86_64 --sdk=/path/to/xclang -y
xmake
```

Alternatively, pass `--bin=/path/to/xclang/bin` or put its `bin` directory on `PATH`.
An explicit SDK/bindir is checked in isolation and does not fall back to another LLVM.
The distribution must contain `xclang`, `clang`, and the target's `.cfg` file.

## Local development

To use the working copy instead of downloading the addon:

```sh
xmake addon --install .
```

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

The runner isolates addon registration and caches in temporary directories. It checks
addon resolution, package binding, target selection, absolute tool paths,
PATH discovery without `which`/`where`, and explicit-SDK isolation.
A first-install test uses a local repository and a simulated SDK to verify automatic addon
installation, SDK package installation and toolchain binding without network access.
It does not compile with the simulated SDK.

Set `XCLANG_SDK` or put `xclang` on PATH to additionally check a real distribution and build
the C/C++/shared-library smoke project for Linux, MinGW and macOS on both architectures.
Compatible host binaries are also run. Tests do not download a real SDK.
`XCLANG_SDK` is used by the test runner; normal configuration uses `--sdk` or `--bin`.

## License

Apache-2.0. The toolchain implementation retains its Xmake copyright and license headers.

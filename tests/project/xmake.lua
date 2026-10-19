add_addons("xclang")

set_languages("c11", "c++20")
add_rules("mode.debug", "mode.release")
target("helper")
    set_kind("static")
    set_toolchains("@addon/xclang/xclang")
    add_files("helper.c")
target("shared")
    set_kind("shared")
    set_toolchains("@addon/xclang/xclang")
    add_files("shared.cpp")
    add_defines("BUILD_SHARED")
target("smoke")
    set_kind("binary")
    set_toolchains("@addon/xclang/xclang")
    add_files("main.cpp")
    add_deps("helper", "shared")

    if is_plat("mingw", "windows") then
        add_files("version.rc")
    end

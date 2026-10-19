add_addons("xclang 1.0.2")
add_requires("xclang 23.1.2+10", {system = false})
set_languages("c++20")

target("hello")
    set_kind("binary")
    set_toolchains("@addon/xclang/xclang", {packages = "xclang"})
    add_files("src/main.cpp")

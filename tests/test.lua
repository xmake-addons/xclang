import("core.tool.toolchain")
import("core.package.addon")
import("lib.detect.find_tool")

-- Package installation runs in a different working directory.
local scriptdir = path.absolute(os.scriptdir())

-- A renamed xmake supplies a working --version command without requiring xclang.
-- The clang marker is never executed by these discovery tests.
function _fixture(callback)
    local root = os.tmpfile() .. "-xclang"
    local oldpath = os.getenv("PATH")
    local oldsdk = os.getenv("XCLANG_SDK")
    local oldprogramdir = os.getenv("XMAKE_PROGRAM_DIR")
    -- Non-embedded xmake needs its Lua scripts after the executable is copied.
    os.setenv("XMAKE_PROGRAM_DIR", os.programdir())
    local fixture = {}
    function fixture:write(name, content)
        local filename = path.join(root, name)
        io.writefile(filename, content or "")
        return filename
    end
    function fixture:sdk(name, target, manager)
        local bindir = path.join(root, name, "bin")
        os.mkdir(bindir)
        if manager ~= false then
            local filename = path.join(bindir, is_host("windows") and "xclang.exe" or "xclang")
            os.cp(os.programfile(), filename)
        end
        self:write(path.join(name, "bin", is_host("windows") and "clang.exe" or "clang"))
        self:write(path.join(name, "bin", target .. ".cfg"))
        return path.directory(bindir), bindir
    end
    local errors
    try {
        function () callback(fixture, root) end,
        catch { function (message) errors = message end }
    }
    os.setenv("PATH", oldpath)
    os.setenv("XCLANG_SDK", oldsdk)
    os.setenv("XMAKE_PROGRAM_DIR", oldprogramdir)
    os.tryrm(root)
    if errors then
        raise(errors)
    end
end

function _load(opt)
    return toolchain.load("@addon/xclang/xclang", opt)
end

function test_target_config_selection()
    _fixture(function (fixture)
        -- Each SDK has exactly one target configuration. This catches accidental
        -- fallback to the host ABI, including native Windows builds using MinGW.
        local targets = {
            {"mingw", "x86_64", "x86_64-w64-windows-gnu"},
            {"mingw", "arm64", "aarch64-w64-windows-gnu"},
            {"linux", "x86_64", "x86_64-unknown-linux-gnu"},
            {"linux", "arm64", "aarch64-unknown-linux-gnu"},
            {"macosx", "x86_64", "x86_64-apple-darwin"},
            {"macosx", "arm64", "aarch64-apple-darwin"},
            {"windows", "x64", "x86_64-pc-windows-msvc"},
            {"windows", "arm64", "aarch64-pc-windows-msvc"},
            {"cross", "arm64", "aarch64-unknown-linux-gnu", "aarch64-unknown-linux-gnu-"},
            {"cross", "arm64", "aarch64-w64-windows-gnu", "aarch64-w64-mingw32-"},
            {"cross", "x86_64", "x86_64-unknown-linux-gnu", "x86_64-linux-gnu-"}
        }
        for i, target in ipairs(targets) do
            local sdkdir, bindir = fixture:sdk("target-" .. i, target[3])
            local instance = _load({plat = target[1], arch = target[2], sdkdir = sdkdir, cross = target[4]})
            assert(instance:check())
            instance:load()
            for _, name in ipairs({"cxflags", "asflags", "ldflags", "shflags"}) do
                assert(table.contains(table.wrap(instance:get(name)), "--target=" .. target[3]))
            end
            if target[1] == "mingw" then
                assert(table.contains(table.wrap(instance:get("mrcflags")), "--target=" .. target[3]))
            end
            for _, name in ipairs({"cc", "cxx", "ld", "ar"}) do
                local program = instance:get("toolset." .. name)
                assert(path.is_absolute(program))
                _are_equal(path.translate(path.directory(program)):lower(), path.translate(bindir):lower())
            end
        end
    end)
end

function test_explicit_sdk_isolation()
    _fixture(function (fixture, root)
        local sdkdir, bindir = fixture:sdk("valid", "x86_64-w64-windows-gnu")
        -- Discovery must locate the SDK without external which/where utilities.
        os.setenv("PATH", bindir)
        os.setenv("XCLANG_SDK", nil)
        local instance = _load({plat = "mingw", arch = "x86_64"})
        assert(instance:check())
        _are_equal(path.translate(instance:bindir()):lower(), path.translate(bindir):lower())
        _are_equal(_find_sdk(), sdkdir)
        assert(not _load({plat = "mingw", arch = "x86_64", sdkdir = path.join(root, "missing")}):check())
        assert(not _load({plat = "mingw", arch = "x86_64", bindir = path.join(root, "missing-bin")}):check())
        local llvm = fixture:sdk("ordinary-llvm", "x86_64-w64-windows-gnu", false)
        assert(not _load({plat = "mingw", arch = "x86_64", sdkdir = llvm}):check())
        local wrongtarget = fixture:sdk("linux-only", "x86_64-unknown-linux-gnu")
        assert(not _load({plat = "mingw", arch = "x86_64", sdkdir = wrongtarget}):check())
        assert(_load({plat = "mingw", arch = "x86_64", bindir = bindir}):check())
    end)
end

function _find_sdk()
    local sdkdir = os.getenv("XCLANG_SDK")
    if not sdkdir then
        for _, dir in ipairs(path.splitenv(os.getenv("PATH") or "")) do
            local program = path.join(path.absolute(dir), is_host("windows") and "xclang.exe" or "xclang")
            if os.isfile(program) and find_tool("xclang", {program = program, force = true}) then
                sdkdir = path.directory(path.directory(program))
                break
            end
        end
    end
    return sdkdir
end

function test_installed_distribution()
    local sdkdir = _find_sdk()
    if not sdkdir then
        return print("Set XCLANG_SDK or put xclang on PATH to check a real distribution")
    end
    for _, target in ipairs({{"mingw", "x86_64"}, {"mingw", "arm64"}, {"linux", "x86_64"}, {"linux", "arm64"},
                             {"macosx", "x86_64"}, {"macosx", "arm64"}}) do
        local instance = _load({plat = target[1], arch = target[2], sdkdir = sdkdir})
        assert(instance:check())
        instance:load()
        local cc, name = instance:tool("cc")
        _are_equal(name, "clang")
        _are_equal(path.translate(path.directory(cc)):lower(), path.translate(instance:bindir()):lower())
    end
end

function test_build()
    local sdkdir = _find_sdk()
    if not sdkdir then
        return print("Set XCLANG_SDK or put xclang on PATH to build with a real distribution")
    end
    local projectdir = path.join(scriptdir, "project")
    for _, target in ipairs({{"mingw", "x86_64"}, {"mingw", "arm64"}, {"linux", "x86_64"}, {"linux", "arm64"},
                             {"macosx", "x86_64"}, {"macosx", "arm64"}}) do
        os.vrunv(os.programfile(), {"f", "-P", projectdir, "-c", "-y", "-p", target[1], "-a", target[2],
                                  "--toolchain=@addon/xclang/xclang", "--sdk=" .. sdkdir}, {curdir = projectdir})
        os.vrunv(os.programfile(), {"-P", projectdir, "-r"}, {curdir = projectdir})
        if (is_host("windows") and target[1] == "mingw") or (is_host("linux") and target[1] == "linux") or
           (is_host("macosx") and target[1] == "macosx") then
            local hostarch = os.arch()
            if (target[2] == "x86_64" and (hostarch == "x86_64" or hostarch == "x64")) or
               (target[2] == "arm64" and (hostarch == "arm64" or hostarch == "aarch64")) then
                os.vrunv(os.programfile(), {"run", "-P", projectdir, "smoke"}, {curdir = projectdir})
            end
        end
    end
end

function test_package_declaration()
    _fixture(function (fixture, root)
        fixture:write("package-project/xmake.lua", [[
add_addons("xclang")
add_requires("xclang", {system = false})
target("probe")
    set_kind("phony")
    set_toolchains("@addon/xclang/xclang", {packages = "xclang"})
]])
        local script = [[
import("core.project.project")
assert(table.contains(table.wrap(project.requires_str()), "xclang"), "missing SDK requirement")
local target = assert(project.target("probe"))
assert(table.contains(table.wrap(target:get("toolchains")), "@addon/xclang/xclang"), "missing addon toolchain")
assert(target:extraconf("toolchains", "@addon/xclang/xclang", "packages") == "xclang", "missing package binding")
]]
        os.vrunv(os.programfile(), {"lua", "-c", script}, {curdir = path.join(root, "package-project")})
    end)
end

function test_automatic_setup()
    _fixture(function (fixture, root)
        local sdkdir = fixture:sdk("sdk", "x86_64-w64-windows-gnu")
        local projectdir = path.join(root, "project")
        local repodir = path.join(root, "repo")
        local addonroot = path.directory(scriptdir)
        fixture:write("repo/addons/x/xclang/xmake.lua", string.format([[
package("xclang")
    set_kind("addon")
    set_sourcedir(%q)
]], addonroot))
        fixture:write("repo/packages/x/xclang/xmake.lua", string.format([[
package("xclang")
    set_kind("toolchain")
    set_sourcedir(%q)
    on_install(function (package)
        os.cp("bin", package:installdir())
        package:addenv("PATH", "bin")
    end)
]], sdkdir))
        fixture:write("project/xmake.lua", string.format([[
add_repositories("xclang-test " .. %q)
add_addons("xclang")
add_requires("xclang", {system = false})

target("probe")
    set_kind("phony")
    set_toolchains("@addon/xclang/xclang", {packages = "xclang"})
    on_config(function (target)
        local toolchain = assert(target:toolchain("xclang"))
        assert(toolchain:check())
        local packages = toolchain:packages()
        assert(#packages == 1 and packages[1]:name() == "xclang")
        assert(path.normalize(toolchain:bindir()) == path.normalize(path.join(packages[1]:installdir(), "bin")))
        io.writefile(path.join(os.projectdir(), "configured.txt"), "ok")
    end)
]], repodir))
        local opt = {curdir = projectdir, envs = {XMAKE_GLOBALDIR = path.join(root, "global")}}
        os.vrunv(os.programfile(), {"g", "--network=private"}, opt)
        os.vrunv(os.programfile(), {"f", "-y", "-p", "mingw", "-a", "x86_64"}, opt)
        _are_equal(io.readfile(path.join(projectdir, "configured.txt")), "ok")
        assert(io.load(path.join(projectdir, "xmake-addons.lock"))["xclang"])
    end)
end

function _are_equal(actual, expected)
    assert(actual == expected, "expected %s, got %s", expected, actual)
end

function main(...)
    if not table.contains({...}, "--installed") then
        local testdir = os.tmpfile() .. "-xclang"
        local envs = {XMAKE_GLOBALDIR = testdir}
        local errors
        try {
            function ()
                os.vrunv(os.programfile(), {"addon", "--install", "-y", path.directory(scriptdir)}, {envs = envs})
                os.vrunv(os.programfile(), {"lua", path.join(scriptdir, "test.lua"), "--installed"}, {envs = envs})
            end,
            catch {function (message) errors = message end}
        }
        os.tryrm(testdir)
        if errors then
            raise(errors)
        end
        return
    end
    local installed = addon.resolve_reference("@addon/xclang/xclang", "/", "toolchains")
    assert(os.isfile(path.join(installed.dir, installed.name, "xmake.lua")))
    test_package_declaration()
    test_automatic_setup()
    test_target_config_selection()
    test_explicit_sdk_isolation()
    test_installed_distribution()
    test_build()
    print("xclang addon tests passed")
end

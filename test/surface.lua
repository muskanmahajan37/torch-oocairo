require "test-setup"
require "lunit"
local Cairo = require "oocairo"

module("test.surface", lunit.testcase, package.seeall)

-- Some tests use this, but it isn't essential, so they will be skipped if
-- the 'memoryfile' module isn't installed.
local MemFile
do
    local ok
    ok, mod = pcall(require, "memoryfile")
    if ok then MemFile = mod end
end

teardown = clean_up_temp_files

local WOOD_FILENAME = "examples/images/wood1.png"
local WOOD_WIDTH, WOOD_HEIGHT = 96, 96

local function check_image_surface (surface, desc)
    assert_userdata(surface, desc .. ", userdata")
    assert_equal("cairo surface object", surface._NAME, desc .. ", mt name")
    assert_equal("image", surface:get_type(), desc .. ", type")
end

function test_image_surface_create ()
    for format, content in pairs({
        rgb24 = "color", argb32 = "color-alpha",
        a8 = "alpha", a1 = "alpha"
    }) do
        local surface = Cairo.image_surface_create(format, 23, 45)
        check_image_surface(surface, "format " .. format)
        assert_equal(format, surface:get_format())
        assert_equal(content, surface:get_content(), "content for " .. format)
        local wd, ht = surface:get_width(), surface:get_height()
        assert_equal(23, wd, "width for " .. format)
        assert_equal(45, ht, "height for " .. format)
    end
end

function test_image_surface_create_bad ()
    assert_error("bad format", function ()
        Cairo.image_surface_create("foo", 23, 45)
    end)
    assert_error("bad width type", function ()
        Cairo.image_surface_create("rgb24", "x", 23)
    end)
    assert_error("negative width value", function ()
        Cairo.image_surface_create("rgb24", -23, 45)
    end)
    assert_error("bad height type", function ()
        Cairo.image_surface_create("rgb24", 23, "x")
    end)
    assert_error("negative height value", function ()
        Cairo.image_surface_create("rgb24", 23, -45)
    end)
end

function test_surface_create_similar ()
    local base = assert(Cairo.image_surface_create("rgb24", 23, 45))
    for _, v in ipairs({ "color", "alpha", "color-alpha" }) do
        local surface = Cairo.surface_create_similar(base, v, 23, 45)
        assert_userdata(surface, "got userdata for " .. v)
        assert_equal("cairo surface object", surface._NAME,
                     "got surface object for " .. v)
        assert_equal(v, surface:get_content(), "right content")
    end
end

function test_surface_create_similar_bad ()
    local base = assert(Cairo.image_surface_create("rgb24", 23, 45))
    assert_error("bad format", function ()
        Cairo.surface_create_similar(base, "foo", 23, 45)
    end)
    assert_error("bad width type", function ()
        Cairo.surface_create_similar(base, "color", "x", 23)
    end)
    assert_error("negative width value", function ()
        Cairo.surface_create_similar(base, "color", -23, 45)
    end)
    assert_error("bad height type", function ()
        Cairo.surface_create_similar(base, "color", 23, "x")
    end)
    assert_error("negative height value", function ()
        Cairo.surface_create_similar(base, "color", 23, -45)
    end)
end

function test_device_offset ()
    local surface = Cairo.image_surface_create("rgb24", 23, 45)
    local x, y = surface:get_device_offset()
    assert_equal(0, x)
    assert_equal(0, y)
    surface:set_device_offset(-5, 3.2)
    x, y = surface:get_device_offset()
    assert_equal(-5, x)
    assert_equal(3.2, y)
end

function test_fallback_resolution ()
    local surface = Cairo.image_surface_create("rgb24", 23, 45)
    if surface.get_fallback_resolution then
        local x, y = surface:get_fallback_resolution()
        assert_equal(300, x)
        assert_equal(300, y)
        surface:set_fallback_resolution(123, 456)
        x, y = surface:get_fallback_resolution()
        assert_equal(123, x)
        assert_equal(456, y)
    else
        assert_nil(surface.get_fallback_resolution)
    end
end

if Cairo.HAS_SVG_SURFACE then
    function test_not_image_surface ()
        local surface = Cairo.svg_surface_create(tmpname(), 300, 200)
        assert_error("get_width on non-image surface",
                     function () surface:get_width() end)
        assert_error("get_height on non-image surface",
                     function () surface:get_height() end)
        assert_error("get_format on non-image surface",
                     function () surface:get_format() end)
    end
end

function test_not_pdf_or_ps_surface ()
    local surface = Cairo.image_surface_create("rgb24", 30, 20)
    assert_error("set_size on non-PDF or PostScript surface",
                 function () surface:set_size(40, 50) end)
end

if Cairo.HAS_PS_SURFACE then
    function test_not_ps_surface ()
        local surface = Cairo.image_surface_create("rgb24", 30, 20)
        assert_error("get_eps on non-PS surface",
                     function () surface:get_eps() end)
        assert_error("set_eps on non-PS surface",
                     function () surface:set_eps(true) end)
    end
end

local function check_wood_image_surface (surface)
    check_image_surface(surface, "load PNG from filename")
    assert_equal(WOOD_WIDTH, surface:get_width())
    assert_equal(WOOD_HEIGHT, surface:get_height())
end

if Cairo.HAS_PNG_FUNCTIONS then
    function test_create_from_png ()
        local surface = Cairo.image_surface_create_from_png(WOOD_FILENAME)
        check_wood_image_surface(surface)
    end

    function test_create_from_png_error ()
        assert_error("trying to load PNG file which doesn't exist", function ()
            Cairo.image_surface_create_from_png("nonexistent-file.png")
        end)
        assert_error("wrong type instead of file/filename", function ()
            Cairo.image_surface_create_from_png(false)
        end)
    end

    function test_create_from_png_stream ()
        local fh = assert(io.open(WOOD_FILENAME, "rb"))
        local surface = Cairo.image_surface_create_from_png(fh)
        fh:close()
        check_wood_image_surface(surface)
    end
end

if MemFile and Cairo.HAS_PNG_FUNCTIONS then
    function test_create_from_png_string ()
        local fh = assert(io.open(WOOD_FILENAME, "rb"))
        local data = fh:read("*a")
        fh:close()
        fh = MemFile.open(data)
        local surface = Cairo.image_surface_create_from_png(fh)
        fh:close()
        check_wood_image_surface(surface)
    end
end

local function check_data_is_png (data)
    assert_match("^\137PNG\13\10", data)
end
local function check_file_contains_png (filename)
    local fh = assert(io.open(filename, "rb"))
    local data = fh:read("*a")
    fh:close()
    check_data_is_png(data)
end

if Cairo.HAS_PNG_FUNCTIONS then
    function test_write_to_png ()
        local surface = Cairo.image_surface_create("rgb24", 23, 45)
        local filename = tmpname()
        surface:write_to_png(filename)
        check_file_contains_png(filename)
    end

    function test_write_to_png_stream ()
        local surface = Cairo.image_surface_create("rgb24", 23, 45)
        local filename = tmpname()
        local fh = assert(io.open(filename, "wb"))
        surface:write_to_png(fh)
        fh:close()
        check_file_contains_png(filename)
    end
end

if MemFile and Cairo.HAS_PNG_FUNCTIONS then
    function test_write_to_png_string ()
        local surface = Cairo.image_surface_create("rgb24", 23, 45)
        local fh = MemFile.open()
        surface:write_to_png(fh)
        check_data_is_png(tostring(fh))
        fh:close()
    end
end

function test_equality ()
    -- Create two userdatas containing the same pointer value (different
    -- objects in Lua, but the same objects in C, so should be equal).
    local surface1 = Cairo.image_surface_create("rgb24", 23, 45)
    local cr = Cairo.context_create(surface1)
    local surface2 = cr:get_target()
    assert_true(surface1 == surface2)

    -- Create a new, completely separate object, which should be distinct
    -- from any other.
    local surface3 = Cairo.image_surface_create("rgb24", 23, 45)
    assert_false(surface1 == surface3)
end

-- vi:ts=4 sw=4 expandtab

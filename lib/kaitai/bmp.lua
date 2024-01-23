-- This is a generated file! Please edit source .ksy file and use kaitai-struct-compiler to rebuild
--
-- This file is compatible with Lua 5.3

local class = include("lib/kaitai/class")
if KaitaiStruct == nil then
  include("lib/kaitai/kaitaistruct")
end
local enum = include("lib/kaitai/enum")
local stringstream = include("lib/kaitai/string_stream")
local str_decode = include("lib/kaitai/string_decode")
local utils = include("lib/kaitai/utils")

--
-- The **BMP file format**, also known as **bitmap image file** or **device independent
-- bitmap (DIB) file format** or simply a **bitmap**, is a raster graphics image file
-- format used to store bitmap digital images, independently of the display
-- device (such as a graphics adapter), especially on Microsoft Windows
-- and OS/2 operating systems.
--
-- ## Samples
--
-- Great collection of various BMP sample files:
-- [**BMP Suite Image List**](
--   http://entropymine.com/jason/bmpsuite/bmpsuite/html/bmpsuite.html
-- ) (by Jason Summers)
--
-- If only there was such a comprehensive sample suite for every file format! It's like
-- a dream for every developer of any binary file format parser. It contains a lot of
-- different types and variations of BMP files, even the tricky ones, where it's not clear
-- from the specification how to deal with them (marked there as "**q**uestionable").
--
-- If you make a program which will be able to read all the "**g**ood" and "**q**uestionable"
-- BMP files and won't crash on the "**b**ad" ones, it will definitely have one of the most
-- extensive support of BMP files in the universe!
--
-- ## BITMAPV2INFOHEADER and BITMAPV3INFOHEADER
--
-- A beneficial discussion on Adobe forum (archived):
-- [**Invalid BMP Format with Alpha channel**](
--   https://web.archive.org/web/20150127132443/https://forums.adobe.com/message/3272950
-- )
--
-- In 2010, someone noticed that Photoshop generated BMP with an odd type of header. There wasn't
-- any documentation available for this header at the time (and still isn't).
-- However, Chris Cox (former Adobe employee) claimed that they hadn't invented any type
-- of proprietary header and everything they were writing was taken directly
-- from the Microsoft documentation.
--
-- It showed up that the unknown header was called BITMAPV3INFOHEADER.
-- Although Microsoft has apparently requested and verified the use of the header,
-- the documentation on MSDN has probably got lost and they have probably
-- forgotten about this type of header.
--
-- This is the only source I could find about these structures, so we could't rely
-- on it so much, but I think supporting them as a read-only format won't harm anything.
-- Due to the fact that it isn't documented anywhere else, most applications don't support it.
--
-- All Windows headers at once (including mentioned BITMAPV2INFOHEADER and BITMAPV3INFOHEADER):
--
-- ![Bitmap headers overview](
--   https://web.archive.org/web/20190527043845/https://forums.adobe.com/servlet/JiveServlet/showImage/2-3273299-47801/BMP_Headers.png
-- )
--
-- ## Specs
--  * [Bitmap Storage (Windows Dev Center)](
--      https://learn.microsoft.com/en-us/windows/win32/gdi/bitmap-storage
--    )
--     * BITMAPFILEHEADER
--     * BITMAPINFOHEADER
--     * BITMAPV4HEADER
--     * BITMAPV5HEADER
--  * [OS/2 Bitmap File Format](
--       https://www.fileformat.info/format/os2bmp/egff.htm
--    )
--     * BITMAPFILEHEADER (OS2BMPFILEHEADER)
--     * BITMAPCOREHEADER (OS21XBITMAPHEADER)
--     * OS22XBITMAPHEADER
--  * [Microsoft Windows Bitmap](
--       http://netghost.narod.ru/gff/graphics/summary/micbmp.htm
--    )
--     * BITMAPFILEHEADER (WINBMPFILEHEADER)
--     * BITMAPCOREHEADER (WIN2XBITMAPHEADER)
--     * BITMAPINFOHEADER (WINNTBITMAPHEADER)
--     * BITMAPV4HEADER (WIN4XBITMAPHEADER)
Bmp = class.class(KaitaiStruct)

Bmp.Intent = enum.Enum {
  business = 1,
  graphics = 2,
  images = 4,
  abs_colorimetric = 8,
}

Bmp.ColorSpace = enum.Enum {
  calibrated_rgb = 0,
  profile_linked = 1279872587,
  profile_embedded = 1296188740,
  windows = 1466527264,
  s_rgb = 1934772034,
}

Bmp.Os2Rendering = enum.Enum {
  no_halftoning = 0,
  error_diffusion = 1,
  panda = 2,
  super_circle = 3,
}

Bmp.HeaderType = enum.Enum {
  bitmap_core_header = 12,
  bitmap_info_header = 40,
  bitmap_v2_info_header = 52,
  bitmap_v3_info_header = 56,
  os2_2x_bitmap_header = 64,
  bitmap_v4_header = 108,
  bitmap_v5_header = 124,
}

Bmp.Compressions = enum.Enum {
  rgb = 0,
  rle8 = 1,
  rle4 = 2,
  bitfields = 3,
  jpeg = 4,
  png = 5,
  alpha_bitfields = 6,
}

Bmp.Os2Compressions = enum.Enum {
  rgb = 0,
  rle8 = 1,
  rle4 = 2,
  huffman_1d = 3,
  rle24 = 4,
}

function Bmp:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Bmp:_read()
  self.file_hdr = Bmp.FileHeader(self._io, self, self._root)
  self._raw_dib_info = self._io:read_bytes((self.file_hdr.ofs_bitmap - 14))
  local _io = KaitaiStream(stringstream(self._raw_dib_info))
  self.dib_info = Bmp.BitmapInfo(_io, self, self._root)
  self._raw_bitmap = self._io:read_bytes_full()
  local _io = KaitaiStream(stringstream(self._raw_bitmap))
  self.bitmap = Bmp.Bitmap(_io, self, self._root)
end


--
-- See also: Source (https://learn.microsoft.com/en-us/windows/win32/api/wingdi/ns-wingdi-ciexyz)
Bmp.CieXyz = class.class(KaitaiStruct)

function Bmp.CieXyz:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Bmp.CieXyz:_read()
  self.x = Bmp.FixedPoint2Dot30(self._io, self, self._root)
  self.y = Bmp.FixedPoint2Dot30(self._io, self, self._root)
  self.z = Bmp.FixedPoint2Dot30(self._io, self, self._root)
end


Bmp.RgbRecord = class.class(KaitaiStruct)

function Bmp.RgbRecord:_init(has_reserved_field, io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self.has_reserved_field = has_reserved_field
  self:_read()
end

function Bmp.RgbRecord:_read()
  self.blue = self._io:read_u1()
  self.green = self._io:read_u1()
  self.red = self._io:read_u1()
  if self.has_reserved_field then
    self.reserved = self._io:read_u1()
  end
end


--
-- See also: Source (https://learn.microsoft.com/en-us/windows/win32/api/wingdi/ns-wingdi-bitmapv5header)
Bmp.BitmapV5Extension = class.class(KaitaiStruct)

function Bmp.BitmapV5Extension:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Bmp.BitmapV5Extension:_read()
  self.intent = Bmp.Intent(self._io:read_u4le())
  self.ofs_profile = self._io:read_u4le()
  self.len_profile = self._io:read_u4le()
  self.reserved = self._io:read_u4le()
end

Bmp.BitmapV5Extension.property.has_profile = {}
function Bmp.BitmapV5Extension.property.has_profile:get()
  if self._m_has_profile ~= nil then
    return self._m_has_profile
  end

  self._m_has_profile =  ((self._parent.bitmap_v4_ext.color_space_type == Bmp.ColorSpace.profile_linked) or (self._parent.bitmap_v4_ext.color_space_type == Bmp.ColorSpace.profile_embedded))
  return self._m_has_profile
end

--
-- See also: "If the profile is embedded, profile data is the actual profile, and if it is linked, the profile data is the null-terminated file name of the profile. This cannot be a Unicode string. It must be composed exclusively of characters from the Windows character set (code page 1252)." (https://learn.microsoft.com/en-us/windows/win32/wcs/using-structures-in-wcs-1-0)
Bmp.BitmapV5Extension.property.profile_data = {}
function Bmp.BitmapV5Extension.property.profile_data:get()
  if self._m_profile_data ~= nil then
    return self._m_profile_data
  end

  if self.has_profile then
    local _io = self._root._io
    local _pos = _io:pos()
    _io:seek((14 + self.ofs_profile))
    local _on = self._parent.bitmap_v4_ext.color_space_type == Bmp.ColorSpace.profile_linked
    if _on == true then
      self._m_profile_data = str_decode.decode(KaitaiStream.bytes_terminate(_io:read_bytes(self.len_profile), 0, false), "windows-1252")
    else
      self._m_profile_data = _io:read_bytes(self.len_profile)
    end
    _io:seek(_pos)
  end
  return self._m_profile_data
end

--
-- The offset, in bytes, from the beginning of the BITMAPV5HEADER structure to the start of the profile data.

Bmp.ColorMask = class.class(KaitaiStruct)

function Bmp.ColorMask:_init(has_alpha_mask, io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self.has_alpha_mask = has_alpha_mask
  self:_read()
end

function Bmp.ColorMask:_read()
  self.red_mask = self._io:read_u4le()
  self.green_mask = self._io:read_u4le()
  self.blue_mask = self._io:read_u4le()
  if self.has_alpha_mask then
    self.alpha_mask = self._io:read_u4le()
  end
end


--
-- See also: Source (https://learn.microsoft.com/en-us/windows/win32/api/wingdi/ns-wingdi-bitmapv4header)
Bmp.BitmapV4Extension = class.class(KaitaiStruct)

function Bmp.BitmapV4Extension:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Bmp.BitmapV4Extension:_read()
  self.color_space_type = Bmp.ColorSpace(self._io:read_u4le())
  self.endpoint_red = Bmp.CieXyz(self._io, self, self._root)
  self.endpoint_green = Bmp.CieXyz(self._io, self, self._root)
  self.endpoint_blue = Bmp.CieXyz(self._io, self, self._root)
  self.gamma_red = Bmp.FixedPoint16Dot16(self._io, self, self._root)
  self.gamma_blue = Bmp.FixedPoint16Dot16(self._io, self, self._root)
  self.gamma_green = Bmp.FixedPoint16Dot16(self._io, self, self._root)
end


--
-- See also: Source (https://learn.microsoft.com/en-us/previous-versions/dd183376(v=vs.85))
Bmp.BitmapInfoExtension = class.class(KaitaiStruct)

function Bmp.BitmapInfoExtension:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Bmp.BitmapInfoExtension:_read()
  if not(self._parent.extends_os2_2x_bitmap) then
    self.compression = Bmp.Compressions(self._io:read_u4le())
  end
  if self._parent.extends_os2_2x_bitmap then
    self.os2_compression = Bmp.Os2Compressions(self._io:read_u4le())
  end
  self.len_image = self._io:read_u4le()
  self.x_resolution = self._io:read_u4le()
  self.y_resolution = self._io:read_u4le()
  self.num_colors_used = self._io:read_u4le()
  self.num_colors_important = self._io:read_u4le()
end

--
-- If biCompression is BI_JPEG or BI_PNG, indicates the size of the JPEG or PNG image buffer.
-- This may be set to zero for BI_RGB bitmaps.

Bmp.FixedPoint2Dot30 = class.class(KaitaiStruct)

function Bmp.FixedPoint2Dot30:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Bmp.FixedPoint2Dot30:_read()
  self.raw = self._io:read_u4le()
end

Bmp.FixedPoint2Dot30.property.value = {}
function Bmp.FixedPoint2Dot30.property.value:get()
  if self._m_value ~= nil then
    return self._m_value
  end

  self._m_value = ((self.raw + 0.0) / (1 << 30))
  return self._m_value
end


--
-- Replace with an opaque type if you care about the pixels. You can look at
-- an example of a JavaScript implementation:
-- <https://github.com/generalmimon/bmptool/blob/master/src/Bitmap.js>
--
-- There is a proposal for adding bitmap data type to Kaitai Struct:
-- <https://github.com/kaitai-io/kaitai_struct/issues/188>
Bmp.Bitmap = class.class(KaitaiStruct)

function Bmp.Bitmap:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Bmp.Bitmap:_read()
end


--
-- See also: Source (https://learn.microsoft.com/en-us/windows/win32/api/wingdi/ns-wingdi-bitmapcoreheader)
-- See also: Source (https://www.fileformat.info/format/os2bmp/egff.htm#OS2BMP-DMYID.3.1)
Bmp.BitmapHeader = class.class(KaitaiStruct)

function Bmp.BitmapHeader:_init(len_header, io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self.len_header = len_header
  self:_read()
end

function Bmp.BitmapHeader:_read()
  local _on = self.is_core_header
  if _on == true then
    self.image_width = self._io:read_u2le()
  elseif _on == false then
    self.image_width = self._io:read_u4le()
  end
  local _on = self.is_core_header
  if _on == true then
    self.image_height_raw = self._io:read_s2le()
  elseif _on == false then
    self.image_height_raw = self._io:read_s4le()
  end
  self.num_planes = self._io:read_u2le()
  self.bits_per_pixel = self._io:read_u2le()
  if self.extends_bitmap_info then
    self.bitmap_info_ext = Bmp.BitmapInfoExtension(self._io, self, self._root)
  end
  if self.is_color_mask_here then
    self.color_mask = Bmp.ColorMask(self.len_header ~= Bmp.HeaderType.bitmap_v2_info_header.value, self._io, self, self._root)
  end
  if self.extends_os2_2x_bitmap then
    self.os2_2x_bitmap_ext = Bmp.Os22xBitmapExtension(self._io, self, self._root)
  end
  if self.extends_bitmap_v4 then
    self.bitmap_v4_ext = Bmp.BitmapV4Extension(self._io, self, self._root)
  end
  if self.extends_bitmap_v5 then
    self.bitmap_v5_ext = Bmp.BitmapV5Extension(self._io, self, self._root)
  end
end

Bmp.BitmapHeader.property.extends_bitmap_v4 = {}
function Bmp.BitmapHeader.property.extends_bitmap_v4:get()
  if self._m_extends_bitmap_v4 ~= nil then
    return self._m_extends_bitmap_v4
  end

  self._m_extends_bitmap_v4 = self.len_header >= Bmp.HeaderType.bitmap_v4_header.value
  return self._m_extends_bitmap_v4
end

Bmp.BitmapHeader.property.extends_os2_2x_bitmap = {}
function Bmp.BitmapHeader.property.extends_os2_2x_bitmap:get()
  if self._m_extends_os2_2x_bitmap ~= nil then
    return self._m_extends_os2_2x_bitmap
  end

  self._m_extends_os2_2x_bitmap = self.len_header == Bmp.HeaderType.os2_2x_bitmap_header.value
  return self._m_extends_os2_2x_bitmap
end

Bmp.BitmapHeader.property.uses_fixed_palette = {}
function Bmp.BitmapHeader.property.uses_fixed_palette:get()
  if self._m_uses_fixed_palette ~= nil then
    return self._m_uses_fixed_palette
  end

  self._m_uses_fixed_palette =  ((not( ((self.bits_per_pixel == 16) or (self.bits_per_pixel == 24) or (self.bits_per_pixel == 32)) )) and (not( ((self.extends_bitmap_info) and (not(self.extends_os2_2x_bitmap)) and ( ((self.bitmap_info_ext.compression == Bmp.Compressions.jpeg) or (self.bitmap_info_ext.compression == Bmp.Compressions.png)) )) )))
  return self._m_uses_fixed_palette
end

Bmp.BitmapHeader.property.extends_bitmap_info = {}
function Bmp.BitmapHeader.property.extends_bitmap_info:get()
  if self._m_extends_bitmap_info ~= nil then
    return self._m_extends_bitmap_info
  end

  self._m_extends_bitmap_info = self.len_header >= Bmp.HeaderType.bitmap_info_header.value
  return self._m_extends_bitmap_info
end

Bmp.BitmapHeader.property.image_height = {}
function Bmp.BitmapHeader.property.image_height:get()
  if self._m_image_height ~= nil then
    return self._m_image_height
  end

  self._m_image_height = utils.box_unwrap((self.image_height_raw < 0) and utils.box_wrap(-(self.image_height_raw)) or (self.image_height_raw))
  return self._m_image_height
end

Bmp.BitmapHeader.property.is_core_header = {}
function Bmp.BitmapHeader.property.is_core_header:get()
  if self._m_is_core_header ~= nil then
    return self._m_is_core_header
  end

  self._m_is_core_header = self.len_header == Bmp.HeaderType.bitmap_core_header.value
  return self._m_is_core_header
end

Bmp.BitmapHeader.property.extends_bitmap_v5 = {}
function Bmp.BitmapHeader.property.extends_bitmap_v5:get()
  if self._m_extends_bitmap_v5 ~= nil then
    return self._m_extends_bitmap_v5
  end

  self._m_extends_bitmap_v5 = self.len_header >= Bmp.HeaderType.bitmap_v5_header.value
  return self._m_extends_bitmap_v5
end

Bmp.BitmapHeader.property.is_color_mask_here = {}
function Bmp.BitmapHeader.property.is_color_mask_here:get()
  if self._m_is_color_mask_here ~= nil then
    return self._m_is_color_mask_here
  end

  self._m_is_color_mask_here =  ((self.len_header == Bmp.HeaderType.bitmap_v2_info_header.value) or (self.len_header == Bmp.HeaderType.bitmap_v3_info_header.value) or (self.extends_bitmap_v4))
  return self._m_is_color_mask_here
end

Bmp.BitmapHeader.property.bottom_up = {}
function Bmp.BitmapHeader.property.bottom_up:get()
  if self._m_bottom_up ~= nil then
    return self._m_bottom_up
  end

  self._m_bottom_up = self.image_height_raw > 0
  return self._m_bottom_up
end

--
-- Image width, px.
--
-- Image height, px (positive => bottom-up image, negative => top-down image).
--
-- Number of planes for target device, must be 1.
--
-- Number of bits per pixel that image buffer uses (1, 4, 8, 16, 24 or 32).

--
-- See also: Source (https://www.fileformat.info/format/os2bmp/egff.htm#OS2BMP-DMYID.3.2)
Bmp.Os22xBitmapExtension = class.class(KaitaiStruct)

function Bmp.Os22xBitmapExtension:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Bmp.Os22xBitmapExtension:_read()
  self.units = self._io:read_u2le()
  self.reserved = self._io:read_u2le()
  self.recording = self._io:read_u2le()
  self.rendering = Bmp.Os2Rendering(self._io:read_u2le())
  self.size1 = self._io:read_u4le()
  self.size2 = self._io:read_u4le()
  self.color_encoding = self._io:read_u4le()
  self.identifier = self._io:read_u4le()
end

--
-- Specifies how the bitmap scan lines are stored.
-- The only valid value for this field is 0, indicating that the bitmap is
-- stored from left to right and from the bottom up.
--
-- Specifies the halftoning algorithm used on the bitmap data.
--
-- rendering == os2_rendering::error_diffusion
--   => error damping as a percentage in the range 0 through 100
-- rendering == os2_rendering::panda or rendering == os2_rendering::super_circle
--   => X dimension of the pattern used in pixels
--
-- rendering == os2_rendering::error_diffusion
--   => not used
-- rendering == os2_rendering::panda or rendering == os2_rendering::super_circle
--   => Y dimension of the pattern used in pixels
--
-- Specifies the color model used to describe the bitmap data.
-- The only valid value is 0, indicating the RGB encoding scheme.
--
-- Application-specific value.

Bmp.FixedPoint16Dot16 = class.class(KaitaiStruct)

function Bmp.FixedPoint16Dot16:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Bmp.FixedPoint16Dot16:_read()
  self.raw = self._io:read_u4le()
end

Bmp.FixedPoint16Dot16.property.value = {}
function Bmp.FixedPoint16Dot16.property.value:get()
  if self._m_value ~= nil then
    return self._m_value
  end

  self._m_value = ((self.raw + 0.0) / (1 << 16))
  return self._m_value
end


Bmp.ColorTable = class.class(KaitaiStruct)

function Bmp.ColorTable:_init(has_reserved_field, num_colors, io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self.has_reserved_field = has_reserved_field
  self.num_colors = num_colors
  self:_read()
end

function Bmp.ColorTable:_read()
  self.colors = {}
  for i = 0, utils.box_unwrap(( ((self.num_colors > 0) and (self.num_colors < self.num_colors_present)) ) and utils.box_wrap(self.num_colors) or (self.num_colors_present)) - 1 do
    self.colors[i + 1] = Bmp.RgbRecord(self.has_reserved_field, self._io, self, self._root)
  end
end

Bmp.ColorTable.property.num_colors_present = {}
function Bmp.ColorTable.property.num_colors_present:get()
  if self._m_num_colors_present ~= nil then
    return self._m_num_colors_present
  end

  self._m_num_colors_present = math.floor(self._io:size() / utils.box_unwrap((self.has_reserved_field) and utils.box_wrap(4) or (3)))
  return self._m_num_colors_present
end

--
-- If equal to 0, the pallete should contain as many colors as can fit into the pixel value
-- according to the `bits_per_pixel` field (if `bits_per_pixel` = 8, then the pixel can
-- represent 2 ** 8 = 256 values, so exactly 256 colors should be present). For more flexibility,
-- it reads as many colors as it can until EOS is reached (and the image data begin).

--
-- See also: Source (https://learn.microsoft.com/en-us/windows/win32/api/wingdi/ns-wingdi-bitmapfileheader)
Bmp.FileHeader = class.class(KaitaiStruct)

function Bmp.FileHeader:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Bmp.FileHeader:_read()
  self.file_type = self._io:read_bytes(2)
  if not(self.file_type == "\066\077") then
    error("not equal, expected " ..  "\066\077" .. ", but got " .. self.file_type)
  end
  self.len_file = self._io:read_u4le()
  self.reserved1 = self._io:read_u2le()
  self.reserved2 = self._io:read_u2le()
  self.ofs_bitmap = self._io:read_s4le()
end

--
-- not reliable, mostly ignored by BMP decoders.
--
-- Offset to actual raw pixel data of the image.

--
-- See also: Source (https://learn.microsoft.com/en-us/windows/win32/api/wingdi/ns-wingdi-bitmapinfo)
Bmp.BitmapInfo = class.class(KaitaiStruct)

function Bmp.BitmapInfo:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Bmp.BitmapInfo:_read()
  self.len_header = self._io:read_u4le()
  self._raw_header = self._io:read_bytes((self.len_header - 4))
  local _io = KaitaiStream(stringstream(self._raw_header))
  self.header = Bmp.BitmapHeader(self.len_header, _io, self, self._root)
  if self.is_color_mask_here then
    self.color_mask = Bmp.ColorMask(self.header.bitmap_info_ext.compression == Bmp.Compressions.alpha_bitfields, self._io, self, self._root)
  end
  if not(self._io:is_eof()) then
    self._raw_color_table = self._io:read_bytes_full()
    local _io = KaitaiStream(stringstream(self._raw_color_table))
    self.color_table = Bmp.ColorTable(not(self.header.is_core_header), utils.box_unwrap((self.header.extends_bitmap_info) and utils.box_wrap(self.header.bitmap_info_ext.num_colors_used) or (0)), _io, self, self._root)
  end
end

Bmp.BitmapInfo.property.is_color_mask_given = {}
function Bmp.BitmapInfo.property.is_color_mask_given:get()
  if self._m_is_color_mask_given ~= nil then
    return self._m_is_color_mask_given
  end

  self._m_is_color_mask_given =  ((self.header.extends_bitmap_info) and ( ((self.header.bitmap_info_ext.compression == Bmp.Compressions.bitfields) or (self.header.bitmap_info_ext.compression == Bmp.Compressions.alpha_bitfields)) ) and ( ((self.is_color_mask_here) or (self.header.is_color_mask_here)) ))
  return self._m_is_color_mask_given
end

Bmp.BitmapInfo.property.color_mask_given = {}
function Bmp.BitmapInfo.property.color_mask_given:get()
  if self._m_color_mask_given ~= nil then
    return self._m_color_mask_given
  end

  if self.is_color_mask_given then
    self._m_color_mask_given = utils.box_unwrap((self.is_color_mask_here) and utils.box_wrap(self.color_mask) or (self.header.color_mask))
  end
  return self._m_color_mask_given
end

Bmp.BitmapInfo.property.color_mask_blue = {}
function Bmp.BitmapInfo.property.color_mask_blue:get()
  if self._m_color_mask_blue ~= nil then
    return self._m_color_mask_blue
  end

  self._m_color_mask_blue = utils.box_unwrap((self.is_color_mask_given) and utils.box_wrap(self.color_mask_given.blue_mask) or (utils.box_unwrap((self.header.bits_per_pixel == 16) and utils.box_wrap(31) or (utils.box_unwrap(( ((self.header.bits_per_pixel == 24) or (self.header.bits_per_pixel == 32)) ) and utils.box_wrap(255) or (0))))))
  return self._m_color_mask_blue
end

Bmp.BitmapInfo.property.color_mask_alpha = {}
function Bmp.BitmapInfo.property.color_mask_alpha:get()
  if self._m_color_mask_alpha ~= nil then
    return self._m_color_mask_alpha
  end

  self._m_color_mask_alpha = utils.box_unwrap(( ((self.is_color_mask_given) and (self.color_mask_given.has_alpha_mask)) ) and utils.box_wrap(self.color_mask_given.alpha_mask) or (0))
  return self._m_color_mask_alpha
end

Bmp.BitmapInfo.property.color_mask_green = {}
function Bmp.BitmapInfo.property.color_mask_green:get()
  if self._m_color_mask_green ~= nil then
    return self._m_color_mask_green
  end

  self._m_color_mask_green = utils.box_unwrap((self.is_color_mask_given) and utils.box_wrap(self.color_mask_given.green_mask) or (utils.box_unwrap((self.header.bits_per_pixel == 16) and utils.box_wrap(992) or (utils.box_unwrap(( ((self.header.bits_per_pixel == 24) or (self.header.bits_per_pixel == 32)) ) and utils.box_wrap(65280) or (0))))))
  return self._m_color_mask_green
end

Bmp.BitmapInfo.property.is_color_mask_here = {}
function Bmp.BitmapInfo.property.is_color_mask_here:get()
  if self._m_is_color_mask_here ~= nil then
    return self._m_is_color_mask_here
  end

  self._m_is_color_mask_here =  ((not(self._io:is_eof())) and (self.header.len_header == Bmp.HeaderType.bitmap_info_header.value) and ( ((self.header.bitmap_info_ext.compression == Bmp.Compressions.bitfields) or (self.header.bitmap_info_ext.compression == Bmp.Compressions.alpha_bitfields)) ))
  return self._m_is_color_mask_here
end

Bmp.BitmapInfo.property.color_mask_red = {}
function Bmp.BitmapInfo.property.color_mask_red:get()
  if self._m_color_mask_red ~= nil then
    return self._m_color_mask_red
  end

  self._m_color_mask_red = utils.box_unwrap((self.is_color_mask_given) and utils.box_wrap(self.color_mask_given.red_mask) or (utils.box_unwrap((self.header.bits_per_pixel == 16) and utils.box_wrap(31744) or (utils.box_unwrap(( ((self.header.bits_per_pixel == 24) or (self.header.bits_per_pixel == 32)) ) and utils.box_wrap(16711680) or (0))))))
  return self._m_color_mask_red
end

--
-- Valid only for BITMAPINFOHEADER, in all headers extending it the masks are contained in the header itself.

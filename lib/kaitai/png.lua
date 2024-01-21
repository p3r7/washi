-- This is a generated file! Please edit source .ksy file and use kaitai-struct-compiler to rebuild
--
-- This file is compatible with Lua 5.3

local class = require("lib/kaitai/class")
if KaitaiStruct == nil then
  include("lib/kaitai/kaitaistruct")
end
local enum = require("lib/kaitai/enum")
local str_decode = require("lib/kaitai/string_decode")
local stringstream = require("lib/kaitai/string_stream")
local utils = require("lib/kaitai/utils")

--
-- Test files for APNG can be found at the following locations:
--
--   * <https://philip.html5.org/tests/apng/tests.html>
--   * <http://littlesvr.ca/apng/>
Png = class.class(KaitaiStruct)

Png.PhysUnit = enum.Enum {
  unknown = 0,
  meter = 1,
}

Png.BlendOpValues = enum.Enum {
  source = 0,
  over = 1,
}

Png.CompressionMethods = enum.Enum {
  zlib = 0,
}

Png.DisposeOpValues = enum.Enum {
  none = 0,
  background = 1,
  previous = 2,
}

Png.ColorType = enum.Enum {
  greyscale = 0,
  truecolor = 2,
  indexed = 3,
  greyscale_alpha = 4,
  truecolor_alpha = 6,
}

function Png:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Png:_read()
  self.magic = self._io:read_bytes(8)
  if not(self.magic == "\137\080\078\071\013\010\026\010") then
    error("not equal, expected " ..  "\137\080\078\071\013\010\026\010" .. ", but got " .. self.magic)
  end
  self.ihdr_len = self._io:read_u4be()
  if not(self.ihdr_len == 13) then
    error("not equal, expected " ..  13 .. ", but got " .. self.ihdr_len)
  end
  self.ihdr_type = self._io:read_bytes(4)
  if not(self.ihdr_type == "\073\072\068\082") then
    error("not equal, expected " ..  "\073\072\068\082" .. ", but got " .. self.ihdr_type)
  end
  self.ihdr = Png.IhdrChunk(self._io, self, self._root)
  self.ihdr_crc = self._io:read_bytes(4)
  self.chunks = {}
  local i = 0
  while true do
    local _ = Png.Chunk(self._io, self, self._root)
    self.chunks[i + 1] = _
    if  ((_.type == "IEND") or (self._io:is_eof()))  then
      break
    end
    i = i + 1
  end
end


Png.Rgb = class.class(KaitaiStruct)

function Png.Rgb:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Png.Rgb:_read()
  self.r = self._io:read_u1()
  self.g = self._io:read_u1()
  self.b = self._io:read_u1()
end


Png.Chunk = class.class(KaitaiStruct)

function Png.Chunk:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Png.Chunk:_read()
  self.len = self._io:read_u4be()
  self.type = str_decode.decode(self._io:read_bytes(4), "UTF-8")
  local _on = self.type
  if _on == "iTXt" then
    self._raw_body = self._io:read_bytes(self.len)
    local _io = KaitaiStream(stringstream(self._raw_body))
    self.body = Png.InternationalTextChunk(_io, self, self._root)
  elseif _on == "gAMA" then
    self._raw_body = self._io:read_bytes(self.len)
    local _io = KaitaiStream(stringstream(self._raw_body))
    self.body = Png.GamaChunk(_io, self, self._root)
  elseif _on == "tIME" then
    self._raw_body = self._io:read_bytes(self.len)
    local _io = KaitaiStream(stringstream(self._raw_body))
    self.body = Png.TimeChunk(_io, self, self._root)
  elseif _on == "PLTE" then
    self._raw_body = self._io:read_bytes(self.len)
    local _io = KaitaiStream(stringstream(self._raw_body))
    self.body = Png.PlteChunk(_io, self, self._root)
  elseif _on == "bKGD" then
    self._raw_body = self._io:read_bytes(self.len)
    local _io = KaitaiStream(stringstream(self._raw_body))
    self.body = Png.BkgdChunk(_io, self, self._root)
  elseif _on == "pHYs" then
    self._raw_body = self._io:read_bytes(self.len)
    local _io = KaitaiStream(stringstream(self._raw_body))
    self.body = Png.PhysChunk(_io, self, self._root)
  elseif _on == "fdAT" then
    self._raw_body = self._io:read_bytes(self.len)
    local _io = KaitaiStream(stringstream(self._raw_body))
    self.body = Png.FrameDataChunk(_io, self, self._root)
  elseif _on == "tEXt" then
    self._raw_body = self._io:read_bytes(self.len)
    local _io = KaitaiStream(stringstream(self._raw_body))
    self.body = Png.TextChunk(_io, self, self._root)
  elseif _on == "cHRM" then
    self._raw_body = self._io:read_bytes(self.len)
    local _io = KaitaiStream(stringstream(self._raw_body))
    self.body = Png.ChrmChunk(_io, self, self._root)
  elseif _on == "acTL" then
    self._raw_body = self._io:read_bytes(self.len)
    local _io = KaitaiStream(stringstream(self._raw_body))
    self.body = Png.AnimationControlChunk(_io, self, self._root)
  elseif _on == "sRGB" then
    self._raw_body = self._io:read_bytes(self.len)
    local _io = KaitaiStream(stringstream(self._raw_body))
    self.body = Png.SrgbChunk(_io, self, self._root)
  elseif _on == "zTXt" then
    self._raw_body = self._io:read_bytes(self.len)
    local _io = KaitaiStream(stringstream(self._raw_body))
    self.body = Png.CompressedTextChunk(_io, self, self._root)
  elseif _on == "fcTL" then
    self._raw_body = self._io:read_bytes(self.len)
    local _io = KaitaiStream(stringstream(self._raw_body))
    self.body = Png.FrameControlChunk(_io, self, self._root)
  else
    self.body = self._io:read_bytes(self.len)
  end
  self.crc = self._io:read_bytes(4)
end


--
-- Background chunk for images with indexed palette.
Png.BkgdIndexed = class.class(KaitaiStruct)

function Png.BkgdIndexed:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Png.BkgdIndexed:_read()
  self.palette_index = self._io:read_u1()
end


Png.Point = class.class(KaitaiStruct)

function Png.Point:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Png.Point:_read()
  self.x_int = self._io:read_u4be()
  self.y_int = self._io:read_u4be()
end

Png.Point.property.x = {}
function Png.Point.property.x:get()
  if self._m_x ~= nil then
    return self._m_x
  end

  self._m_x = (self.x_int / 100000.0)
  return self._m_x
end

Png.Point.property.y = {}
function Png.Point.property.y:get()
  if self._m_y ~= nil then
    return self._m_y
  end

  self._m_y = (self.y_int / 100000.0)
  return self._m_y
end


--
-- Background chunk for greyscale images.
Png.BkgdGreyscale = class.class(KaitaiStruct)

function Png.BkgdGreyscale:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Png.BkgdGreyscale:_read()
  self.value = self._io:read_u2be()
end


--
-- See also: Source (https://www.w3.org/TR/png/#11cHRM)
Png.ChrmChunk = class.class(KaitaiStruct)

function Png.ChrmChunk:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Png.ChrmChunk:_read()
  self.white_point = Png.Point(self._io, self, self._root)
  self.red = Png.Point(self._io, self, self._root)
  self.green = Png.Point(self._io, self, self._root)
  self.blue = Png.Point(self._io, self, self._root)
end


--
-- See also: Source (https://www.w3.org/TR/png/#11IHDR)
Png.IhdrChunk = class.class(KaitaiStruct)

function Png.IhdrChunk:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Png.IhdrChunk:_read()
  self.width = self._io:read_u4be()
  self.height = self._io:read_u4be()
  self.bit_depth = self._io:read_u1()
  self.color_type = Png.ColorType(self._io:read_u1())
  self.compression_method = self._io:read_u1()
  self.filter_method = self._io:read_u1()
  self.interlace_method = self._io:read_u1()
end


--
-- See also: Source (https://www.w3.org/TR/png/#11PLTE)
Png.PlteChunk = class.class(KaitaiStruct)

function Png.PlteChunk:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Png.PlteChunk:_read()
  self.entries = {}
  local i = 0
  while not self._io:is_eof() do
    self.entries[i + 1] = Png.Rgb(self._io, self, self._root)
    i = i + 1
  end
end


--
-- See also: Source (https://www.w3.org/TR/png/#11sRGB)
Png.SrgbChunk = class.class(KaitaiStruct)

Png.SrgbChunk.Intent = enum.Enum {
  perceptual = 0,
  relative_colorimetric = 1,
  saturation = 2,
  absolute_colorimetric = 3,
}

function Png.SrgbChunk:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Png.SrgbChunk:_read()
  self.render_intent = Png.SrgbChunk.Intent(self._io:read_u1())
end


--
-- Compressed text chunk effectively allows to store key-value
-- string pairs in PNG container, compressing "value" part (which
-- can be quite lengthy) with zlib compression.
-- See also: Source (https://www.w3.org/TR/png/#11zTXt)
Png.CompressedTextChunk = class.class(KaitaiStruct)

function Png.CompressedTextChunk:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Png.CompressedTextChunk:_read()
  self.keyword = str_decode.decode(self._io:read_bytes_term(0, false, true, true), "UTF-8")
  self.compression_method = Png.CompressionMethods(self._io:read_u1())
  self._raw_text_datastream = self._io:read_bytes_full()
  self.text_datastream = KaitaiStream.process_zlib(self._raw_text_datastream)
end

--
-- Indicates purpose of the following text data.

--
-- See also: Source (https://wiki.mozilla.org/APNG_Specification#.60fdAT.60:_The_Frame_Data_Chunk)
Png.FrameDataChunk = class.class(KaitaiStruct)

function Png.FrameDataChunk:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Png.FrameDataChunk:_read()
  self.sequence_number = self._io:read_u4be()
  self.frame_data = self._io:read_bytes_full()
end

--
-- Sequence number of the animation chunk. The fcTL and fdAT chunks
-- have a 4 byte sequence number. Both chunk types share the sequence.
-- The first fcTL chunk must contain sequence number 0, and the sequence
-- numbers in the remaining fcTL and fdAT chunks must be in order, with
-- no gaps or duplicates.
--
-- Frame data for the frame. At least one fdAT chunk is required for
-- each frame. The compressed datastream is the concatenation of the
-- contents of the data fields of all the fdAT chunks within a frame.

--
-- Background chunk for truecolor images.
Png.BkgdTruecolor = class.class(KaitaiStruct)

function Png.BkgdTruecolor:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Png.BkgdTruecolor:_read()
  self.red = self._io:read_u2be()
  self.green = self._io:read_u2be()
  self.blue = self._io:read_u2be()
end


--
-- See also: Source (https://www.w3.org/TR/png/#11gAMA)
Png.GamaChunk = class.class(KaitaiStruct)

function Png.GamaChunk:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Png.GamaChunk:_read()
  self.gamma_int = self._io:read_u4be()
end

Png.GamaChunk.property.gamma_ratio = {}
function Png.GamaChunk.property.gamma_ratio:get()
  if self._m_gamma_ratio ~= nil then
    return self._m_gamma_ratio
  end

  self._m_gamma_ratio = (100000.0 / self.gamma_int)
  return self._m_gamma_ratio
end


--
-- Background chunk stores default background color to display this
-- image against. Contents depend on `color_type` of the image.
-- See also: Source (https://www.w3.org/TR/png/#11bKGD)
Png.BkgdChunk = class.class(KaitaiStruct)

function Png.BkgdChunk:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Png.BkgdChunk:_read()
  local _on = self._root.ihdr.color_type
  if _on == Png.ColorType.indexed then
    self.bkgd = Png.BkgdIndexed(self._io, self, self._root)
  elseif _on == Png.ColorType.truecolor_alpha then
    self.bkgd = Png.BkgdTruecolor(self._io, self, self._root)
  elseif _on == Png.ColorType.greyscale_alpha then
    self.bkgd = Png.BkgdGreyscale(self._io, self, self._root)
  elseif _on == Png.ColorType.truecolor then
    self.bkgd = Png.BkgdTruecolor(self._io, self, self._root)
  elseif _on == Png.ColorType.greyscale then
    self.bkgd = Png.BkgdGreyscale(self._io, self, self._root)
  end
end


--
-- "Physical size" chunk stores data that allows to translate
-- logical pixels into physical units (meters, etc) and vice-versa.
-- See also: Source (https://www.w3.org/TR/png/#11pHYs)
Png.PhysChunk = class.class(KaitaiStruct)

function Png.PhysChunk:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Png.PhysChunk:_read()
  self.pixels_per_unit_x = self._io:read_u4be()
  self.pixels_per_unit_y = self._io:read_u4be()
  self.unit = Png.PhysUnit(self._io:read_u1())
end

--
-- Number of pixels per physical unit (typically, 1 meter) by X
-- axis.
--
-- Number of pixels per physical unit (typically, 1 meter) by Y
-- axis.

--
-- See also: Source (https://wiki.mozilla.org/APNG_Specification#.60fcTL.60:_The_Frame_Control_Chunk)
Png.FrameControlChunk = class.class(KaitaiStruct)

function Png.FrameControlChunk:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Png.FrameControlChunk:_read()
  self.sequence_number = self._io:read_u4be()
  self.width = self._io:read_u4be()
  if not(self.width >= 1) then
    error("ValidationLessThanError")
  end
  if not(self.width <= self._root.ihdr.width) then
    error("ValidationGreaterThanError")
  end
  self.height = self._io:read_u4be()
  if not(self.height >= 1) then
    error("ValidationLessThanError")
  end
  if not(self.height <= self._root.ihdr.height) then
    error("ValidationGreaterThanError")
  end
  self.x_offset = self._io:read_u4be()
  if not(self.x_offset <= (self._root.ihdr.width - self.width)) then
    error("ValidationGreaterThanError")
  end
  self.y_offset = self._io:read_u4be()
  if not(self.y_offset <= (self._root.ihdr.height - self.height)) then
    error("ValidationGreaterThanError")
  end
  self.delay_num = self._io:read_u2be()
  self.delay_den = self._io:read_u2be()
  self.dispose_op = Png.DisposeOpValues(self._io:read_u1())
  self.blend_op = Png.BlendOpValues(self._io:read_u1())
end

--
-- Time to display this frame, in seconds.
Png.FrameControlChunk.property.delay = {}
function Png.FrameControlChunk.property.delay:get()
  if self._m_delay ~= nil then
    return self._m_delay
  end

  self._m_delay = (self.delay_num / utils.box_unwrap((self.delay_den == 0) and utils.box_wrap(100.0) or (self.delay_den)))
  return self._m_delay
end

--
-- Sequence number of the animation chunk.
--
-- Width of the following frame.
--
-- Height of the following frame.
--
-- X position at which to render the following frame.
--
-- Y position at which to render the following frame.
--
-- Frame delay fraction numerator.
--
-- Frame delay fraction denominator.
--
-- Type of frame area disposal to be done after rendering this frame.
--
-- Type of frame area rendering for this frame.

--
-- International text chunk effectively allows to store key-value string pairs in
-- PNG container. Both "key" (keyword) and "value" (text) parts are
-- given in pre-defined subset of iso8859-1 without control
-- characters.
-- See also: Source (https://www.w3.org/TR/png/#11iTXt)
Png.InternationalTextChunk = class.class(KaitaiStruct)

function Png.InternationalTextChunk:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Png.InternationalTextChunk:_read()
  self.keyword = str_decode.decode(self._io:read_bytes_term(0, false, true, true), "UTF-8")
  self.compression_flag = self._io:read_u1()
  self.compression_method = Png.CompressionMethods(self._io:read_u1())
  self.language_tag = str_decode.decode(self._io:read_bytes_term(0, false, true, true), "ASCII")
  self.translated_keyword = str_decode.decode(self._io:read_bytes_term(0, false, true, true), "UTF-8")
  self.text = str_decode.decode(self._io:read_bytes_full(), "UTF-8")
end

--
-- Indicates purpose of the following text data.
--
-- 0 = text is uncompressed, 1 = text is compressed with a
-- method specified in `compression_method`.
--
-- Human language used in `translated_keyword` and `text`
-- attributes - should be a language code conforming to ISO
-- 646.IRV:1991.
--
-- Keyword translated into language specified in
-- `language_tag`. Line breaks are not allowed.
--
-- Text contents ("value" of this key-value pair), written in
-- language specified in `language_tag`. Line breaks are
-- allowed.

--
-- Text chunk effectively allows to store key-value string pairs in
-- PNG container. Both "key" (keyword) and "value" (text) parts are
-- given in pre-defined subset of iso8859-1 without control
-- characters.
-- See also: Source (https://www.w3.org/TR/png/#11tEXt)
Png.TextChunk = class.class(KaitaiStruct)

function Png.TextChunk:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Png.TextChunk:_read()
  self.keyword = str_decode.decode(self._io:read_bytes_term(0, false, true, true), "iso8859-1")
  self.text = str_decode.decode(self._io:read_bytes_full(), "iso8859-1")
end

--
-- Indicates purpose of the following text data.

--
-- See also: Source (https://wiki.mozilla.org/APNG_Specification#.60acTL.60:_The_Animation_Control_Chunk)
Png.AnimationControlChunk = class.class(KaitaiStruct)

function Png.AnimationControlChunk:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Png.AnimationControlChunk:_read()
  self.num_frames = self._io:read_u4be()
  self.num_plays = self._io:read_u4be()
end

--
-- Number of frames, must be equal to the number of `frame_control_chunk`s.
--
-- Number of times to loop, 0 indicates infinite looping.

--
-- Time chunk stores time stamp of last modification of this image,
-- up to 1 second precision in UTC timezone.
-- See also: Source (https://www.w3.org/TR/png/#11tIME)
Png.TimeChunk = class.class(KaitaiStruct)

function Png.TimeChunk:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Png.TimeChunk:_read()
  self.year = self._io:read_u2be()
  self.month = self._io:read_u1()
  self.day = self._io:read_u1()
  self.hour = self._io:read_u1()
  self.minute = self._io:read_u1()
  self.second = self._io:read_u1()
end

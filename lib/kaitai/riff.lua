-- This is a generated file! Please edit source .ksy file and use kaitai-struct-compiler to rebuild
--
-- This file is compatible with Lua 5.3

local class = include("lib/kaitai/class")
if KaitaiStruct == nil then
  include("lib/kaitai/kaitaistruct")
end
local enum = include("lib/kaitai/enum")
local str_decode = include("lib/kaitai/string_decode")
local stringstream = include("lib/kaitai/string_stream")

--
-- The Resource Interchange File Format (RIFF) is a generic file container format
-- for storing data in tagged chunks. It is primarily used to store multimedia
-- such as sound and video, though it may also be used to store any arbitrary data.
--
-- The Microsoft implementation is mostly known through container formats
-- like AVI, ANI and WAV, which use RIFF as their basis.
-- See also: Source (https://www.johnloomis.org/cpe102/asgn/asgn1/riff.html)
Riff = class.class(KaitaiStruct)

Riff.Fourcc = enum.Enum {
  riff = 1179011410,
  info = 1330007625,
  list = 1414744396,
}

function Riff:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Riff:_read()
  self.chunk = Riff.Chunk(self._io, self, self._root)
end

Riff.property.chunk_id = {}
function Riff.property.chunk_id:get()
  if self._m_chunk_id ~= nil then
    return self._m_chunk_id
  end

  self._m_chunk_id = Riff.Fourcc(self.chunk.id)
  return self._m_chunk_id
end

Riff.property.is_riff_chunk = {}
function Riff.property.is_riff_chunk:get()
  if self._m_is_riff_chunk ~= nil then
    return self._m_is_riff_chunk
  end

  self._m_is_riff_chunk = self.chunk_id == Riff.Fourcc.riff
  return self._m_is_riff_chunk
end

Riff.property.parent_chunk_data = {}
function Riff.property.parent_chunk_data:get()
  if self._m_parent_chunk_data ~= nil then
    return self._m_parent_chunk_data
  end

  if self.is_riff_chunk then
    local _io = self.chunk.data_slot._io
    local _pos = _io:pos()
    _io:seek(0)
    self._m_parent_chunk_data = Riff.ParentChunkData(_io, self, self._root)
    _io:seek(_pos)
  end
  return self._m_parent_chunk_data
end

Riff.property.subchunks = {}
function Riff.property.subchunks:get()
  if self._m_subchunks ~= nil then
    return self._m_subchunks
  end

  if self.is_riff_chunk then
    local _io = self.parent_chunk_data.subchunks_slot._io
    local _pos = _io:pos()
    _io:seek(0)
    self._m_subchunks = {}
    local i = 0
    while not _io:is_eof() do
      self._m_subchunks[i + 1] = Riff.ChunkType(_io, self, self._root)
      i = i + 1
    end
    _io:seek(_pos)
  end
  return self._m_subchunks
end


Riff.ListChunkData = class.class(KaitaiStruct)

function Riff.ListChunkData:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Riff.ListChunkData:_read()
  if self.parent_chunk_data_ofs < 0 then
    self.save_parent_chunk_data_ofs = self._io:read_bytes(0)
  end
  self.parent_chunk_data = Riff.ParentChunkData(self._io, self, self._root)
end

Riff.ListChunkData.property.parent_chunk_data_ofs = {}
function Riff.ListChunkData.property.parent_chunk_data_ofs:get()
  if self._m_parent_chunk_data_ofs ~= nil then
    return self._m_parent_chunk_data_ofs
  end

  self._m_parent_chunk_data_ofs = self._io:pos()
  return self._m_parent_chunk_data_ofs
end

Riff.ListChunkData.property.form_type = {}
function Riff.ListChunkData.property.form_type:get()
  if self._m_form_type ~= nil then
    return self._m_form_type
  end

  self._m_form_type = Riff.Fourcc(self.parent_chunk_data.form_type)
  return self._m_form_type
end

Riff.ListChunkData.property.form_type_readable = {}
function Riff.ListChunkData.property.form_type_readable:get()
  if self._m_form_type_readable ~= nil then
    return self._m_form_type_readable
  end

  local _pos = self._io:pos()
  self._io:seek(self.parent_chunk_data_ofs)
  self._m_form_type_readable = str_decode.decode(self._io:read_bytes(4), "ASCII")
  self._io:seek(_pos)
  return self._m_form_type_readable
end

Riff.ListChunkData.property.subchunks = {}
function Riff.ListChunkData.property.subchunks:get()
  if self._m_subchunks ~= nil then
    return self._m_subchunks
  end

  local _io = self.parent_chunk_data.subchunks_slot._io
  local _pos = _io:pos()
  _io:seek(0)
  self._m_subchunks = {}
  local i = 0
  while not _io:is_eof() do
    local _on = self.form_type
    if _on == Riff.Fourcc.info then
      self._m_subchunks[i + 1] = Riff.InfoSubchunk(_io, self, self._root)
    else
      self._m_subchunks[i + 1] = Riff.ChunkType(_io, self, self._root)
    end
    i = i + 1
  end
  _io:seek(_pos)
  return self._m_subchunks
end


Riff.Chunk = class.class(KaitaiStruct)

function Riff.Chunk:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Riff.Chunk:_read()
  self.id = self._io:read_u4le()
  self.len = self._io:read_u4le()
  self._raw_data_slot = self._io:read_bytes(self.len)
  local _io = KaitaiStream(stringstream(self._raw_data_slot))
  self.data_slot = Riff.Chunk.Slot(_io, self, self._root)
  self.pad_byte = self._io:read_bytes((self.len % 2))
end


Riff.Chunk.Slot = class.class(KaitaiStruct)

function Riff.Chunk.Slot:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Riff.Chunk.Slot:_read()
end


Riff.ParentChunkData = class.class(KaitaiStruct)

function Riff.ParentChunkData:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Riff.ParentChunkData:_read()
  self.form_type = self._io:read_u4le()
  self._raw_subchunks_slot = self._io:read_bytes_full()
  local _io = KaitaiStream(stringstream(self._raw_subchunks_slot))
  self.subchunks_slot = Riff.ParentChunkData.Slot(_io, self, self._root)
end


Riff.ParentChunkData.Slot = class.class(KaitaiStruct)

function Riff.ParentChunkData.Slot:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Riff.ParentChunkData.Slot:_read()
end


--
-- All registered subchunks in the INFO chunk are NULL-terminated strings,
-- but the unregistered might not be. By convention, the registered
-- chunk IDs are in uppercase and the unregistered IDs are in lowercase.
--
-- If the chunk ID of an INFO subchunk contains a lowercase
-- letter, this chunk is considered as unregistered and thus we can make
-- no assumptions about the type of data.
Riff.InfoSubchunk = class.class(KaitaiStruct)

function Riff.InfoSubchunk:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Riff.InfoSubchunk:_read()
  if self.chunk_ofs < 0 then
    self.save_chunk_ofs = self._io:read_bytes(0)
  end
  self.chunk = Riff.Chunk(self._io, self, self._root)
end

Riff.InfoSubchunk.property.chunk_data = {}
function Riff.InfoSubchunk.property.chunk_data:get()
  if self._m_chunk_data ~= nil then
    return self._m_chunk_data
  end

  local _io = self.chunk.data_slot._io
  local _pos = _io:pos()
  _io:seek(0)
  local _on = self.is_unregistered_tag
  if _on == false then
    self._m_chunk_data = str_decode.decode(_io:read_bytes_term(0, false, true, true), "UTF-8")
  end
  _io:seek(_pos)
  return self._m_chunk_data
end

--
-- Check if chunk_id contains lowercase characters ([a-z], ASCII 97 = a, ASCII 122 = z).
Riff.InfoSubchunk.property.is_unregistered_tag = {}
function Riff.InfoSubchunk.property.is_unregistered_tag:get()
  if self._m_is_unregistered_tag ~= nil then
    return self._m_is_unregistered_tag
  end

  self._m_is_unregistered_tag =  (( ((string.byte(self.id_chars, 0 + 1) >= 97) and (string.byte(self.id_chars, 0 + 1) <= 122)) ) or ( ((string.byte(self.id_chars, 1 + 1) >= 97) and (string.byte(self.id_chars, 1 + 1) <= 122)) ) or ( ((string.byte(self.id_chars, 2 + 1) >= 97) and (string.byte(self.id_chars, 2 + 1) <= 122)) ) or ( ((string.byte(self.id_chars, 3 + 1) >= 97) and (string.byte(self.id_chars, 3 + 1) <= 122)) ))
  return self._m_is_unregistered_tag
end

Riff.InfoSubchunk.property.id_chars = {}
function Riff.InfoSubchunk.property.id_chars:get()
  if self._m_id_chars ~= nil then
    return self._m_id_chars
  end

  local _pos = self._io:pos()
  self._io:seek(self.chunk_ofs)
  self._m_id_chars = self._io:read_bytes(4)
  self._io:seek(_pos)
  return self._m_id_chars
end

Riff.InfoSubchunk.property.chunk_id_readable = {}
function Riff.InfoSubchunk.property.chunk_id_readable:get()
  if self._m_chunk_id_readable ~= nil then
    return self._m_chunk_id_readable
  end

  self._m_chunk_id_readable = str_decode.decode(self.id_chars, "ASCII")
  return self._m_chunk_id_readable
end

Riff.InfoSubchunk.property.chunk_ofs = {}
function Riff.InfoSubchunk.property.chunk_ofs:get()
  if self._m_chunk_ofs ~= nil then
    return self._m_chunk_ofs
  end

  self._m_chunk_ofs = self._io:pos()
  return self._m_chunk_ofs
end


Riff.ChunkType = class.class(KaitaiStruct)

function Riff.ChunkType:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Riff.ChunkType:_read()
  if self.chunk_ofs < 0 then
    self.save_chunk_ofs = self._io:read_bytes(0)
  end
  self.chunk = Riff.Chunk(self._io, self, self._root)
end

Riff.ChunkType.property.chunk_ofs = {}
function Riff.ChunkType.property.chunk_ofs:get()
  if self._m_chunk_ofs ~= nil then
    return self._m_chunk_ofs
  end

  self._m_chunk_ofs = self._io:pos()
  return self._m_chunk_ofs
end

Riff.ChunkType.property.chunk_id = {}
function Riff.ChunkType.property.chunk_id:get()
  if self._m_chunk_id ~= nil then
    return self._m_chunk_id
  end

  self._m_chunk_id = Riff.Fourcc(self.chunk.id)
  return self._m_chunk_id
end

Riff.ChunkType.property.chunk_id_readable = {}
function Riff.ChunkType.property.chunk_id_readable:get()
  if self._m_chunk_id_readable ~= nil then
    return self._m_chunk_id_readable
  end

  local _pos = self._io:pos()
  self._io:seek(self.chunk_ofs)
  self._m_chunk_id_readable = str_decode.decode(self._io:read_bytes(4), "ASCII")
  self._io:seek(_pos)
  return self._m_chunk_id_readable
end

Riff.ChunkType.property.chunk_data = {}
function Riff.ChunkType.property.chunk_data:get()
  if self._m_chunk_data ~= nil then
    return self._m_chunk_data
  end

  local _io = self.chunk.data_slot._io
  local _pos = _io:pos()
  _io:seek(0)
  local _on = self.chunk_id
  if _on == Riff.Fourcc.list then
    self._m_chunk_data = Riff.ListChunkData(_io, self, self._root)
  end
  _io:seek(_pos)
  return self._m_chunk_data
end

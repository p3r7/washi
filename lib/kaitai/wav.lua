-- This is a generated file! Please edit source .ksy file and use kaitai-struct-compiler to rebuild
--
-- This file is compatible with Lua 5.3

local class = include("lib/kaitai/class")
if KaitaiStruct == nil then
  include("lib/kaitai/kaitaistruct")
end
if Riff == nil then
  include("lib/kaitai/riff")
end
local enum = include("lib/kaitai/enum")
local str_decode = include("lib/kaitai/string_decode")

--
-- The WAVE file format is a subset of Microsoft's RIFF specification for the
-- storage of multimedia files. A RIFF file starts out with a file header
-- followed by a sequence of data chunks. A WAVE file is often just a RIFF
-- file with a single "WAVE" chunk which consists of two sub-chunks --
-- a "fmt " chunk specifying the data format and a "data" chunk containing
-- the actual sample data, although other chunks exist and are used.
--
-- An extension of the file format is the Broadcast Wave Format (BWF) for radio
-- broadcasts. Sample files can be found at:
--
-- <https://www.bbc.co.uk/rd/publications/saqas>
--
-- This Kaitai implementation was written by John Byrd of Gigantic Software
-- (jbyrd@giganticsoftware.com), and it is likely to contain bugs.
-- See also: Source (http://soundfile.sapp.org/doc/WaveFormat/)
-- See also: Source (https://www.mmsp.ece.mcgill.ca/Documents/AudioFormats/WAVE/WAVE.html)
-- See also: Source (https://web.archive.org/web/20101031101749/http://www.ebu.ch/fr/technical/publications/userguides/bwf_user_guide.php)
Wav = class.class(KaitaiStruct)

Wav.WFormatTagType = enum.Enum {
  unknown = 0,
  pcm = 1,
  adpcm = 2,
  ieee_float = 3,
  vselp = 4,
  ibm_cvsd = 5,
  alaw = 6,
  mulaw = 7,
  dts = 8,
  drm = 9,
  wmavoice9 = 10,
  wmavoice10 = 11,
  oki_adpcm = 16,
  dvi_adpcm = 17,
  mediaspace_adpcm = 18,
  sierra_adpcm = 19,
  g723_adpcm = 20,
  digistd = 21,
  digifix = 22,
  dialogic_oki_adpcm = 23,
  mediavision_adpcm = 24,
  cu_codec = 25,
  hp_dyn_voice = 26,
  yamaha_adpcm = 32,
  sonarc = 33,
  dspgroup_truespeech = 34,
  echosc1 = 35,
  audiofile_af36 = 36,
  aptx = 37,
  audiofile_af10 = 38,
  prosody_1612 = 39,
  lrc = 40,
  dolby_ac2 = 48,
  gsm610 = 49,
  msnaudio = 50,
  antex_adpcme = 51,
  control_res_vqlpc = 52,
  digireal = 53,
  digiadpcm = 54,
  control_res_cr10 = 55,
  nms_vbxadpcm = 56,
  cs_imaadpcm = 57,
  echosc3 = 58,
  rockwell_adpcm = 59,
  rockwell_digitalk = 60,
  xebec = 61,
  g721_adpcm = 64,
  g728_celp = 65,
  msg723 = 66,
  intel_g723_1 = 67,
  intel_g729 = 68,
  sharp_g726 = 69,
  mpeg = 80,
  rt24 = 82,
  pac = 83,
  mpeglayer3 = 85,
  lucent_g723 = 89,
  cirrus = 96,
  espcm = 97,
  voxware = 98,
  canopus_atrac = 99,
  g726_adpcm = 100,
  g722_adpcm = 101,
  dsat = 102,
  dsat_display = 103,
  voxware_byte_aligned = 105,
  voxware_ac8 = 112,
  voxware_ac10 = 113,
  voxware_ac16 = 114,
  voxware_ac20 = 115,
  voxware_rt24 = 116,
  voxware_rt29 = 117,
  voxware_rt29hw = 118,
  voxware_vr12 = 119,
  voxware_vr18 = 120,
  voxware_tq40 = 121,
  voxware_sc3 = 122,
  voxware_sc3_1 = 123,
  softsound = 128,
  voxware_tq60 = 129,
  msrt24 = 130,
  g729a = 131,
  mvi_mvi2 = 132,
  df_g726 = 133,
  df_gsm610 = 134,
  isiaudio = 136,
  onlive = 137,
  multitude_ft_sx20 = 138,
  infocom_its_g721_adpcm = 139,
  convedia_g729 = 140,
  congruency = 141,
  sbc24 = 145,
  dolby_ac3_spdif = 146,
  mediasonic_g723 = 147,
  prosody_8kbps = 148,
  zyxel_adpcm = 151,
  philips_lpcbb = 152,
  packed = 153,
  malden_phonytalk = 160,
  racal_recorder_gsm = 161,
  racal_recorder_g720_a = 162,
  racal_recorder_g723_1 = 163,
  racal_recorder_tetra_acelp = 164,
  nec_aac = 176,
  raw_aac1 = 255,
  rhetorex_adpcm = 256,
  irat = 257,
  vivo_g723 = 273,
  vivo_siren = 274,
  philips_celp = 288,
  philips_grundig = 289,
  digital_g723 = 291,
  sanyo_ld_adpcm = 293,
  siprolab_aceplnet = 304,
  siprolab_acelp4800 = 305,
  siprolab_acelp8v3 = 306,
  siprolab_g729 = 307,
  siprolab_g729a = 308,
  siprolab_kelvin = 309,
  voiceage_amr = 310,
  g726adpcm = 320,
  dictaphone_celp68 = 321,
  dictaphone_celp54 = 322,
  qualcomm_purevoice = 336,
  qualcomm_halfrate = 337,
  tubgsm = 341,
  msaudio1 = 352,
  wmaudio2 = 353,
  wmaudio3 = 354,
  wmaudio_lossless = 355,
  wmaspdif = 356,
  unisys_nap_adpcm = 368,
  unisys_nap_ulaw = 369,
  unisys_nap_alaw = 370,
  unisys_nap_16k = 371,
  sycom_acm_syc008 = 372,
  sycom_acm_syc701_g726l = 373,
  sycom_acm_syc701_celp54 = 374,
  sycom_acm_syc701_celp68 = 375,
  knowledge_adventure_adpcm = 376,
  fraunhofer_iis_mpeg2_aac = 384,
  dts_ds = 400,
  creative_adpcm = 512,
  creative_fastspeech8 = 514,
  creative_fastspeech10 = 515,
  uher_adpcm = 528,
  ulead_dv_audio = 533,
  ulead_dv_audio_1 = 534,
  quarterdeck = 544,
  ilink_vc = 560,
  raw_sport = 576,
  esst_ac3 = 577,
  generic_passthru = 585,
  ipi_hsx = 592,
  ipi_rpelp = 593,
  cs2 = 608,
  sony_scx = 624,
  sony_scy = 625,
  sony_atrac3 = 626,
  sony_spc = 627,
  telum_audio = 640,
  telum_ia_audio = 641,
  norcom_voice_systems_adpcm = 645,
  fm_towns_snd = 768,
  micronas = 848,
  micronas_celp833 = 849,
  btv_digital = 1024,
  intel_music_coder = 1025,
  indeo_audio = 1026,
  qdesign_music = 1104,
  on2_vp7_audio = 1280,
  on2_vp6_audio = 1281,
  vme_vmpcm = 1664,
  tpc = 1665,
  lightwave_lossless = 2222,
  oligsm = 4096,
  oliadpcm = 4097,
  olicelp = 4098,
  olisbc = 4099,
  oliopr = 4100,
  lh_codec = 4352,
  lh_codec_celp = 4353,
  lh_codec_sbc8 = 4354,
  lh_codec_sbc12 = 4355,
  lh_codec_sbc16 = 4356,
  norris = 5120,
  isiaudio_2 = 5121,
  soundspace_musicompress = 5376,
  mpeg_adts_aac = 5632,
  mpeg_raw_aac = 5633,
  mpeg_loas = 5634,
  nokia_mpeg_adts_aac = 5640,
  nokia_mpeg_raw_aac = 5641,
  vodafone_mpeg_adts_aac = 5642,
  vodafone_mpeg_raw_aac = 5643,
  mpeg_heaac = 5648,
  voxware_rt24_speech = 6172,
  sonicfoundry_lossless = 6513,
  innings_telecom_adpcm = 6521,
  lucent_sx8300p = 7175,
  lucent_sx5363s = 7180,
  cuseeme = 7939,
  ntcsoft_alf2cm_acm = 8132,
  dvm = 8192,
  dts2 = 8193,
  makeavis = 13075,
  divio_mpeg4_aac = 16707,
  nokia_adaptive_multirate = 16897,
  divio_g726 = 16963,
  lead_speech = 17228,
  lead_vorbis = 22092,
  wavpack_audio = 22358,
  ogg_vorbis_mode_1 = 26447,
  ogg_vorbis_mode_2 = 26448,
  ogg_vorbis_mode_3 = 26449,
  ogg_vorbis_mode_1_plus = 26479,
  ogg_vorbis_mode_2_plus = 26480,
  ogg_vorbis_mode_3_plus = 26481,
  threecom_nbx = 28672,
  faad_aac = 28781,
  amr_nb = 29537,
  amr_wb = 29538,
  amr_wp = 29539,
  gsm_amr_cbr = 31265,
  gsm_amr_vbr_sid = 31266,
  comverse_infosys_g723_1 = 41216,
  comverse_infosys_avqsbc = 41217,
  comverse_infosys_sbc = 41218,
  symbol_g729_a = 41219,
  voiceage_amr_wb = 41220,
  ingenient_g726 = 41221,
  mpeg4_aac = 41222,
  encore_g726 = 41223,
  zoll_asao = 41224,
  speex_voice = 41225,
  vianix_masc = 41226,
  wm9_spectrum_analyzer = 41227,
  wmf_spectrum_anayzer = 41228,
  gsm_610 = 41229,
  gsm_620 = 41230,
  gsm_660 = 41231,
  gsm_690 = 41232,
  gsm_adaptive_multirate_wb = 41233,
  polycom_g722 = 41234,
  polycom_g728 = 41235,
  polycom_g729_a = 41236,
  polycom_siren = 41237,
  global_ip_ilbc = 41238,
  radiotime_time_shift_radio = 41239,
  nice_aca = 41240,
  nice_adpcm = 41241,
  vocord_g721 = 41242,
  vocord_g726 = 41243,
  vocord_g722_1 = 41244,
  vocord_g728 = 41245,
  vocord_g729 = 41246,
  vocord_g729_a = 41247,
  vocord_g723_1 = 41248,
  vocord_lbc = 41249,
  nice_g728 = 41250,
  france_telecom_g729 = 41251,
  codian = 41252,
  flac = 61868,
  extensible = 65534,
  development = 65535,
}

Wav.Fourcc = enum.Enum {
  id3 = 540238953,
  cue = 543520099,
  fmt = 544501094,
  wave = 1163280727,
  riff = 1179011410,
  peak = 1262568784,
  ixml = 1280137321,
  info = 1330007625,
  list = 1414744396,
  pmx = 1481461855,
  chna = 1634625635,
  data = 1635017060,
  umid = 1684630901,
  minf = 1718511981,
  axml = 1819113569,
  regn = 1852269938,
  afsp = 1886611041,
  fact = 1952670054,
  bext = 1954047330,
}

function Wav:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Wav:_read()
  self.chunk = Riff.Chunk(self._io, self, self._root)
end

Wav.property.subchunks = {}
function Wav.property.subchunks:get()
  if self._m_subchunks ~= nil then
    return self._m_subchunks
  end

  if self.is_form_type_wave then
    local _io = self.parent_chunk_data.subchunks_slot._io
    local _pos = _io:pos()
    _io:seek(0)
    self._m_subchunks = {}
    local i = 0
    while not _io:is_eof() do
      self._m_subchunks[i + 1] = Wav.ChunkType(_io, self, self._root)
      i = i + 1
    end
    _io:seek(_pos)
  end
  return self._m_subchunks
end

Wav.property.parent_chunk_data = {}
function Wav.property.parent_chunk_data:get()
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

Wav.property.is_form_type_wave = {}
function Wav.property.is_form_type_wave:get()
  if self._m_is_form_type_wave ~= nil then
    return self._m_is_form_type_wave
  end

  self._m_is_form_type_wave =  ((self.is_riff_chunk) and (self.form_type == Wav.Fourcc.wave))
  return self._m_is_form_type_wave
end

Wav.property.is_riff_chunk = {}
function Wav.property.is_riff_chunk:get()
  if self._m_is_riff_chunk ~= nil then
    return self._m_is_riff_chunk
  end

  self._m_is_riff_chunk = self.chunk_id == Wav.Fourcc.riff
  return self._m_is_riff_chunk
end

Wav.property.chunk_id = {}
function Wav.property.chunk_id:get()
  if self._m_chunk_id ~= nil then
    return self._m_chunk_id
  end

  self._m_chunk_id = Wav.Fourcc(self.chunk.id)
  return self._m_chunk_id
end

Wav.property.form_type = {}
function Wav.property.form_type:get()
  if self._m_form_type ~= nil then
    return self._m_form_type
  end

  self._m_form_type = Wav.Fourcc(self.parent_chunk_data.form_type)
  return self._m_form_type
end


Wav.SampleType = class.class(KaitaiStruct)

function Wav.SampleType:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Wav.SampleType:_read()
  self.sample = self._io:read_u2le()
end


Wav.FormatChunkType = class.class(KaitaiStruct)

function Wav.FormatChunkType:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Wav.FormatChunkType:_read()
  self.w_format_tag = Wav.WFormatTagType(self._io:read_u2le())
  self.n_channels = self._io:read_u2le()
  self.n_samples_per_sec = self._io:read_u4le()
  self.n_avg_bytes_per_sec = self._io:read_u4le()
  self.n_block_align = self._io:read_u2le()
  self.w_bits_per_sample = self._io:read_u2le()
  if not(self.is_basic_pcm) then
    self.cb_size = self._io:read_u2le()
  end
  if self.is_cb_size_meaningful then
    self.w_valid_bits_per_sample = self._io:read_u2le()
  end
  if self.is_extensible then
    self.channel_mask_and_subformat = Wav.ChannelMaskAndSubformatType(self._io, self, self._root)
  end
end

Wav.FormatChunkType.property.is_extensible = {}
function Wav.FormatChunkType.property.is_extensible:get()
  if self._m_is_extensible ~= nil then
    return self._m_is_extensible
  end

  self._m_is_extensible = self.w_format_tag == Wav.WFormatTagType.extensible
  return self._m_is_extensible
end

Wav.FormatChunkType.property.is_basic_pcm = {}
function Wav.FormatChunkType.property.is_basic_pcm:get()
  if self._m_is_basic_pcm ~= nil then
    return self._m_is_basic_pcm
  end

  self._m_is_basic_pcm = self.w_format_tag == Wav.WFormatTagType.pcm
  return self._m_is_basic_pcm
end

Wav.FormatChunkType.property.is_basic_float = {}
function Wav.FormatChunkType.property.is_basic_float:get()
  if self._m_is_basic_float ~= nil then
    return self._m_is_basic_float
  end

  self._m_is_basic_float = self.w_format_tag == Wav.WFormatTagType.ieee_float
  return self._m_is_basic_float
end

Wav.FormatChunkType.property.is_cb_size_meaningful = {}
function Wav.FormatChunkType.property.is_cb_size_meaningful:get()
  if self._m_is_cb_size_meaningful ~= nil then
    return self._m_is_cb_size_meaningful
  end

  self._m_is_cb_size_meaningful =  ((not(self.is_basic_pcm)) and (self.cb_size ~= 0))
  return self._m_is_cb_size_meaningful
end


Wav.PmxChunkType = class.class(KaitaiStruct)

function Wav.PmxChunkType:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Wav.PmxChunkType:_read()
  self.data = str_decode.decode(self._io:read_bytes_full(), "UTF-8")
end

--
-- XMP data.
-- See also: Source (https://github.com/adobe/XMP-Toolkit-SDK/blob/v2022.06/docs/XMPSpecificationPart3.pdf)

--
-- required for all non-PCM formats
-- (`w_format_tag != w_format_tag_type::pcm` or `not is_basic_pcm` in
-- `format_chunk_type` context)
Wav.FactChunkType = class.class(KaitaiStruct)

function Wav.FactChunkType:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Wav.FactChunkType:_read()
  self.num_samples_per_channel = self._io:read_u4le()
end


Wav.GuidType = class.class(KaitaiStruct)

function Wav.GuidType:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Wav.GuidType:_read()
  self.data1 = self._io:read_u4le()
  self.data2 = self._io:read_u2le()
  self.data3 = self._io:read_u2le()
  self.data4 = self._io:read_u4be()
  self.data4a = self._io:read_u4be()
end


--
-- See also: Source (https://en.wikipedia.org/wiki/IXML)
Wav.IxmlChunkType = class.class(KaitaiStruct)

function Wav.IxmlChunkType:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Wav.IxmlChunkType:_read()
  self.data = str_decode.decode(self._io:read_bytes_full(), "UTF-8")
end


Wav.InfoChunkType = class.class(KaitaiStruct)

function Wav.InfoChunkType:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Wav.InfoChunkType:_read()
  self.chunk = Riff.Chunk(self._io, self, self._root)
end

Wav.InfoChunkType.property.chunk_data = {}
function Wav.InfoChunkType.property.chunk_data:get()
  if self._m_chunk_data ~= nil then
    return self._m_chunk_data
  end

  local _io = self.chunk.data_slot._io
  local _pos = _io:pos()
  _io:seek(0)
  self._m_chunk_data = str_decode.decode(_io:read_bytes_term(0, false, true, true), "ASCII")
  _io:seek(_pos)
  return self._m_chunk_data
end


Wav.CuePointType = class.class(KaitaiStruct)

function Wav.CuePointType:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Wav.CuePointType:_read()
  self.dw_name = self._io:read_u4le()
  self.dw_position = self._io:read_u4le()
  self.fcc_chunk = self._io:read_u4le()
  self.dw_chunk_start = self._io:read_u4le()
  self.dw_block_start = self._io:read_u4le()
  self.dw_sample_offset = self._io:read_u4le()
end


Wav.DataChunkType = class.class(KaitaiStruct)

function Wav.DataChunkType:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Wav.DataChunkType:_read()
  self.data = self._io:read_bytes_full()
end


Wav.SamplesType = class.class(KaitaiStruct)

function Wav.SamplesType:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Wav.SamplesType:_read()
  self.samples = self._io:read_u4le()
end


Wav.ChannelMaskAndSubformatType = class.class(KaitaiStruct)

function Wav.ChannelMaskAndSubformatType:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Wav.ChannelMaskAndSubformatType:_read()
  self.dw_channel_mask = Wav.ChannelMaskType(self._io, self, self._root)
  self.subformat = Wav.GuidType(self._io, self, self._root)
end


Wav.CueChunkType = class.class(KaitaiStruct)

function Wav.CueChunkType:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Wav.CueChunkType:_read()
  self.dw_cue_points = self._io:read_u4le()
  self.cue_points = {}
  for i = 0, self.dw_cue_points - 1 do
    self.cue_points[i + 1] = Wav.CuePointType(self._io, self, self._root)
  end
end


Wav.ListChunkType = class.class(KaitaiStruct)

function Wav.ListChunkType:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Wav.ListChunkType:_read()
  self.parent_chunk_data = Riff.ParentChunkData(self._io, self, self._root)
end

Wav.ListChunkType.property.form_type = {}
function Wav.ListChunkType.property.form_type:get()
  if self._m_form_type ~= nil then
    return self._m_form_type
  end

  self._m_form_type = Wav.Fourcc(self.parent_chunk_data.form_type)
  return self._m_form_type
end

Wav.ListChunkType.property.subchunks = {}
function Wav.ListChunkType.property.subchunks:get()
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
    if _on == Wav.Fourcc.info then
      self._m_subchunks[i + 1] = Wav.InfoChunkType(_io, self, self._root)
    end
    i = i + 1
  end
  _io:seek(_pos)
  return self._m_subchunks
end


Wav.ChannelMaskType = class.class(KaitaiStruct)

function Wav.ChannelMaskType:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Wav.ChannelMaskType:_read()
  self.front_right_of_center = self._io:read_bits_int_be(1) ~= 0
  self.front_left_of_center = self._io:read_bits_int_be(1) ~= 0
  self.back_right = self._io:read_bits_int_be(1) ~= 0
  self.back_left = self._io:read_bits_int_be(1) ~= 0
  self.low_frequency = self._io:read_bits_int_be(1) ~= 0
  self.front_center = self._io:read_bits_int_be(1) ~= 0
  self.front_right = self._io:read_bits_int_be(1) ~= 0
  self.front_left = self._io:read_bits_int_be(1) ~= 0
  self.top_center = self._io:read_bits_int_be(1) ~= 0
  self.side_right = self._io:read_bits_int_be(1) ~= 0
  self.side_left = self._io:read_bits_int_be(1) ~= 0
  self.back_center = self._io:read_bits_int_be(1) ~= 0
  self.top_back_left = self._io:read_bits_int_be(1) ~= 0
  self.top_front_right = self._io:read_bits_int_be(1) ~= 0
  self.top_front_center = self._io:read_bits_int_be(1) ~= 0
  self.top_front_left = self._io:read_bits_int_be(1) ~= 0
  self.unused1 = self._io:read_bits_int_be(6)
  self.top_back_right = self._io:read_bits_int_be(1) ~= 0
  self.top_back_center = self._io:read_bits_int_be(1) ~= 0
  self.unused2 = self._io:read_bits_int_be(8)
end


--
-- See also: Source (https://www.mmsp.ece.mcgill.ca/Documents/Downloads/AFsp/)
Wav.AfspChunkType = class.class(KaitaiStruct)

function Wav.AfspChunkType:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Wav.AfspChunkType:_read()
  self.magic = self._io:read_bytes(4)
  if not(self.magic == "\065\070\115\112") then
    error("not equal, expected " ..  "\065\070\115\112" .. ", but got " .. self.magic)
  end
  self.info_records = {}
  local i = 0
  while not self._io:is_eof() do
    self.info_records[i + 1] = str_decode.decode(self._io:read_bytes_term(0, false, true, true), "ASCII")
    i = i + 1
  end
end

--
-- An array of AFsp information records, in the `<field_name>: <value>`
-- format (e.g. "`program: CopyAudio`"). The list of existing information
-- record types are available in the `doc-ref` links.
-- See also: Source (https://www.mmsp.ece.mcgill.ca/Documents/Software/Packages/AFsp/libtsp/AF/AFsetInfo.html)
-- See also: Source (https://www.mmsp.ece.mcgill.ca/Documents/Software/Packages/AFsp/libtsp/AF/AFprintInfoRecs.html)

--
-- See also: Source (https://tech.ebu.ch/docs/tech/tech3285s5.pdf)
Wav.AxmlChunkType = class.class(KaitaiStruct)

function Wav.AxmlChunkType:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Wav.AxmlChunkType:_read()
  self.data = str_decode.decode(self._io:read_bytes_full(), "UTF-8")
end


Wav.ChunkType = class.class(KaitaiStruct)

function Wav.ChunkType:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Wav.ChunkType:_read()
  self.chunk = Riff.Chunk(self._io, self, self._root)
end

Wav.ChunkType.property.chunk_id = {}
function Wav.ChunkType.property.chunk_id:get()
  if self._m_chunk_id ~= nil then
    return self._m_chunk_id
  end

  self._m_chunk_id = Wav.Fourcc(self.chunk.id)
  return self._m_chunk_id
end

Wav.ChunkType.property.chunk_data = {}
function Wav.ChunkType.property.chunk_data:get()
  if self._m_chunk_data ~= nil then
    return self._m_chunk_data
  end

  local _io = self.chunk.data_slot._io
  local _pos = _io:pos()
  _io:seek(0)
  local _on = self.chunk_id
  if _on == Wav.Fourcc.fact then
    self._m_chunk_data = Wav.FactChunkType(_io, self, self._root)
  elseif _on == Wav.Fourcc.list then
    self._m_chunk_data = Wav.ListChunkType(_io, self, self._root)
  elseif _on == Wav.Fourcc.fmt then
    self._m_chunk_data = Wav.FormatChunkType(_io, self, self._root)
  elseif _on == Wav.Fourcc.afsp then
    self._m_chunk_data = Wav.AfspChunkType(_io, self, self._root)
  elseif _on == Wav.Fourcc.bext then
    self._m_chunk_data = Wav.BextChunkType(_io, self, self._root)
  elseif _on == Wav.Fourcc.cue then
    self._m_chunk_data = Wav.CueChunkType(_io, self, self._root)
  elseif _on == Wav.Fourcc.ixml then
    self._m_chunk_data = Wav.IxmlChunkType(_io, self, self._root)
  elseif _on == Wav.Fourcc.pmx then
    self._m_chunk_data = Wav.PmxChunkType(_io, self, self._root)
  elseif _on == Wav.Fourcc.axml then
    self._m_chunk_data = Wav.AxmlChunkType(_io, self, self._root)
  elseif _on == Wav.Fourcc.data then
    self._m_chunk_data = Wav.DataChunkType(_io, self, self._root)
  end
  _io:seek(_pos)
  return self._m_chunk_data
end


--
-- See also: Source (https://en.wikipedia.org/wiki/Broadcast_Wave_Format)
Wav.BextChunkType = class.class(KaitaiStruct)

function Wav.BextChunkType:_init(io, parent, root)
  KaitaiStruct._init(self, io)
  self._parent = parent
  self._root = root or self
  self:_read()
end

function Wav.BextChunkType:_read()
  self.description = str_decode.decode(KaitaiStream.bytes_terminate(self._io:read_bytes(256), 0, false), "ASCII")
  self.originator = str_decode.decode(KaitaiStream.bytes_terminate(self._io:read_bytes(32), 0, false), "ASCII")
  self.originator_reference = str_decode.decode(KaitaiStream.bytes_terminate(self._io:read_bytes(32), 0, false), "ASCII")
  self.origination_date = str_decode.decode(self._io:read_bytes(10), "ASCII")
  self.origination_time = str_decode.decode(self._io:read_bytes(8), "ASCII")
  self.time_reference_low = self._io:read_u4le()
  self.time_reference_high = self._io:read_u4le()
  self.version = self._io:read_u2le()
  self.umid = self._io:read_bytes(64)
  self.loudness_value = self._io:read_u2le()
  self.loudness_range = self._io:read_u2le()
  self.max_true_peak_level = self._io:read_u2le()
  self.max_momentary_loudness = self._io:read_u2le()
  self.max_short_term_loudness = self._io:read_u2le()
end

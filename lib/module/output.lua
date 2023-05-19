-- haleseq. module/output

local nb = include("haleseq/lib/nb/lib/nb")
local In = include("haleseq/lib/submodule/in")

include("haleseq/lib/consts")


-- ------------------------------------------------------------------------

local Output = {}
Output.__index = Output


-- ------------------------------------------------------------------------
-- constructors

function Output.new(id)
  local p = setmetatable({}, Output)

  local label = id -- A, B, C...
  local llabel = string.lower(label)

  p.id = label
  p.kind = "output"
  p.fqid = "output".."_"..llabel

  p.ins = {}

  p.i = In.new(p.fqid, p)

  p.nb_playing_note = nil

  return p
end


function Output:process_ins()
  if self.i.updated then
    self:nb_play_volts(self.i.v)
  end
end

-- ------------------------------------------------------------------------
-- init

function Output:init_params()
  local label = self.id -- A, B, C...
  local llabel = string.lower(label)

  params:add_group("track_"..llabel, label, 1)

  -- NB: right now, 1:1 mapping between outs & nb voices
  -- might want to change that!
  -- nb:add_param("track_out_nb_voice_"..llabel, "nb Voice "..label)
  nb:add_param("nb_voice_"..llabel, "nb Voice "..label)
end

function Output.init(id, ins_map)
  local o = Output.new(id)
  o:init_params()

  if ins_map ~= nil then
    ins_map[o.i.id] = o.i
  end

  return o
end


-- ------------------------------------------------------------------------
-- playback

function Output:get_nb_player()
  local llabel = string.lower(self.id)
  return params:lookup_param("nb_voice_"..llabel):get_player()
end

function Output:nb_note_off()
  if nb_playing_note ~= nil then
    local player = self:get_nb_player()
    player:note_off(nb_playing_note)
    nb_playing_note = nil
  end
end

function Output:nb_note_on(note, vel)
  if vel == nil then vel = 1.0 end

  local player = self:get_nb_player()
  player:note_on(note, vel)
  nb_playing_note = note
end

function Output:nb_play(note, vel)
  self:nb_note_off()
  self:nb_note_on(note, vel)
end

function Output:nb_play_volts(volts, vel)
  local note = round(util.linlin(0, V_MAX, 0, 127, volts))
  self:nb_play(note, vel)
end


-- ------------------------------------------------------------------------

return Output

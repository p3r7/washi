-- washi. module/output

local Output = {}
Output.__index = Output


-- ------------------------------------------------------------------------
-- deps

local ControlSpec = require "controlspec"

local nb = include("washi/lib/nb/lib/nb")

local In = include("washi/lib/submodule/in")
local Comparator = include("washi/lib/submodule/comparator")

local paperface = include("washi/lib/paperface")

include("washi/lib/consts")


-- ------------------------------------------------------------------------
-- static conf

local TRIG_DUR_MIN = 1
local TRIG_DUR_MAX = 25
local TRIG_DUR_DEFAULT = 10

local specs = {}
specs.VELOCITY = ControlSpec.new(0, 1, 'lin', 0, 1, "")


-- ------------------------------------------------------------------------
-- constructors

function Output.new(id, STATE,
                   page_id, x, y)
  local p = setmetatable({}, Output)

  local label = id -- 1, 2, 3...
  local llabel = string.lower(label)

  p.id = label
  p.kind = "output"
  p.fqid = "output".."_"..llabel

  -- --------------------------------

  p.STATE = STATE

  -- --------------------------------
  -- screen

  p.page = page_id
  p.x = x
  p.y = y

  -- --------------------------------
  -- i/o

  p.ins = {}

  p.i = In.new(p.fqid, p, nil, x, y)
  p.i_trig = Comparator.new(p.fqid..'_trig', p, nil, x+1, y)
  p.i_dur = In.new(p.fqid..'_dur', p, nil, x, y+1)
  p.i_vel = In.new(p.fqid..'_vel', p, nil, x+1, y+1)
  p.i_mod = In.new(p.fqid..'_mod', p, nil, x+2, y+1)

  p.nb_playing_note = nil

  return p
end

function Output:init_params()
  local label = self.id

  params:add_group("track_"..label, "Output #"..label, 9)

  -- NB: right now, 1:1 mapping between outs & nb voices
  nb:add_param("nb_voice_"..label, "nb Voice "..label)

  local OUT_MODES = {'notes+mod', 'notes', 'mod'}
  params:add_option(self.fqid .. "_mode", "Mode", OUT_MODES, tab.key(OUT_MODES, 'notes+mod'))

  params:add{type = "number", id = self.fqid .. "_trig_dur", name = "Trig Dur", min = TRIG_DUR_MIN, max = TRIG_DUR_MAX, default = TRIG_DUR_DEFAULT}
  params:add{type = "control", id = self.fqid.."_vel", name = "Velocity", controlspec = specs.VELOCITY}

  local OCTAVE_RANGE_MODES = {'filter', 'fold'}
  params:add_option("out_octave_mode_"..label, "Octave Fit Mode", OCTAVE_RANGE_MODES, tab.key(OCTAVE_RANGE_MODES, 'filter'))

  params:add{type = "number", id = "out_octave_min_"..label, name = "Min Octave", min = -2, max = 8, default = -2}
  params:add{type = "number", id = "out_octave_max_"..label, name = "Max Octave", min = -2, max = 8, default = 8}

  local OFF_ON = {'off', 'on'}
  params:add_option(self.fqid .. "_bend", "Note Bend", OFF_ON, tab.key(OFF_ON, 'off'))
end

function Output.init(id, STATE,
                    page_id, x, y)
  local o = Output.new(id, STATE,
                       page_id, x, y)
  o:init_params()

  if STATE ~= nil then
    STATE.ins[o.i.id] = o.i
    STATE.ins[o.i_trig.id] = o.i_trig
    STATE.ins[o.i_dur.id] = o.i_dur
    STATE.ins[o.i_vel.id] = o.i_vel
    STATE.ins[o.i_mod.id] = o.i_mod
  end

  return o
end


-- ------------------------------------------------------------------------
-- internal logic

function Output:is_triggered_spe()

  -- as links to its trig in
  if not (tab.count(self.i_trig.incoming_vals) == 0
          or (tab.count(self.i_trig.incoming_vals) == 1 and tkeys(self.i_trig.incoming_vals)[1] == 'GLOBAL')) then
    return false
  end

  if not self.i.changed then
    return false
  end

  local found_one = false
  for from_out_label, v in pairs(self.i.incoming_vals) do
    if from_out_label ~= "GLOBAL" and found_one then
      return false
    end
    if util.string_starts(from_out_label, 'haleseq_') then -- TODO: filter to only keep A, B, C... + ABCD
      found_one = true
    end
  end

  return found_one
end

function Output:process_ins()
  if self.i_dur.changed then
    params:set(self.fqid .. "_trig_dur", round(util.linlin(0, V_MAX, TRIG_DUR_MIN, TRIG_DUR_MAX, self.i_dur.v)))
  end
  if self.i_vel.changed then
    params:set(self.fqid .. "_vel", util.linlin(0, V_MAX, 0.0, 1.0, self.i_vel.v))
  end

  local triggered = (self.i_trig.triggered and self.i_trig.status == 1)
  local triggered_spe = self:is_triggered_spe()

  if tab.contains({'notes+mod', 'notes'}, params:string(self.fqid .. "_mode")) and (triggered or triggered_spe) then -- FIXME: make retrigger on TIE but not SKIP
    self:nb_play_volts(self.i.v)
  end

  if tab.contains({'notes+mod', 'mod'}, params:string(self.fqid .. "_mode")) and self.i_mod.changed then
    self:nb_modulate_volts(self.i_mod.v)
  end

end

function Output:get_nb_player()
  local label = self.id
  return params:lookup_param("nb_voice_"..label):get_player()
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

function Output:nb_note(note, vel, beat_div)
  if vel == nil then vel = 1.0 end

  local player = self:get_nb_player()
  player:play_note(note, vel, beat_div)
  nb_playing_note = note
end

function Output:nb_bend(note, st)
  local player = self:get_nb_player()
  player:pitch_bend(note, st)
end

function Output:nb_play(note, bend_st)
  local llabel = string.lower(self.id)

  self:nb_note_off()

  local octave = math.floor(note / 12 - 2)
  if octave < params:get("out_octave_min_"..llabel) then
    if params:string("out_octave_mode_"..llabel) == 'filter' then
      return
    else -- fold
      while octave < params:get("out_octave_min_"..llabel) do
        note = note + 12
        octave = math.floor(note / 12 - 2)
      end
    end
  end
  if octave > params:get("out_octave_max_"..llabel) then
    if params:string("out_octave_mode_"..llabel) == 'filter' then
      return
    else -- fold
      while octave > params:get("out_octave_max_"..llabel) do
        note = note - 12
        octave = math.floor(note / 12 - 2)
      end
    end
  end

  local vel = params:get(self.fqid .. "_vel")

  -- self:nb_note_on(note, vel)
  self:nb_note(note, vel, params:get(self.fqid .. "_trig_dur")/100)

  if bend_st ~= nil and bend_st ~= 0 then
    self:nb_bend(note, bend_st)
  end
end

function Output:nb_play_volts(volts)
  local note = round(util.linlin(0, V_MAX, 0, 127, volts))

  local bend_st = nil
  if params:string(self.fqid .. "_bend") == 'on' then
    local bend_volts = volts - util.linlin(0, 127, 0, V_MAX, note)
    -- NB: really really not sure about this calculation
    -- my bend_volts is in Volts * 1000 (due to precision of V_MAX)
    -- instinctively i'd say that i'd need to also divide by V_MAX, but that give too low a value...
    bend_st = bend_volts / 12
  end

  self:nb_play(note, bend_st)
end

function Output:nb_modulate_volts(volts)
  local player = self:get_nb_player()
  player:modulate(volts/V_MAX)
end


-- ------------------------------------------------------------------------
-- grid

function Output:grid_redraw(g)
  paperface.module_grid_redraw(self, g)
end


-- ------------------------------------------------------------------------
-- screen

function Output:redraw()
  paperface.module_redraw(self)
end

-- ------------------------------------------------------------------------

return Output

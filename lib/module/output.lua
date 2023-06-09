-- washi. module/output

local Output = {}
Output.__index = Output


-- ------------------------------------------------------------------------
-- deps

local nb = include("washi/lib/nb/lib/nb")
local In = include("washi/lib/submodule/in")

local paperface = include("washi/lib/paperface")

include("washi/lib/consts")


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

  p.screen = page_id
  p.x = x
  p.y = y

  -- --------------------------------
  -- i/o

  p.ins = {}

  p.i = In.new(p.fqid, p, nil, x, y)

  p.nb_playing_note = nil

  return p
end

function Output:init_params()
  local label = self.id

  params:add_group("track_"..label, "Output #"..label, 5)

  -- NB: right now, 1:1 mapping between outs & nb voices
  -- might want to change that!
  -- nb:add_param("track_out_nb_voice_"..llabel, "nb Voice "..label)
  nb:add_param("nb_voice_"..label, "nb Voice "..label)

  local OCTAVE_RANGE_MODES = {'filter', 'fold'}
  params:add_option("out_octave_mode_"..label, "Octave Fit Mode", OCTAVE_RANGE_MODES, tab.key(OCTAVE_RANGE_MODES, 'filter'))

  params:add{type = "number", id = "out_octave_min_"..label, name = "Min Octave", min = -2, max = 8, default = -2}
  params:add{type = "number", id = "out_octave_max_"..label, name = "Max Octave", min = -2, max = 8, default = 8}
end

function Output.init(id, STATE,
                    page_id, x, y)
  local o = Output.new(id, STATE,
                       page_id, x, y)
  o:init_params()

  if STATE ~= nil then
    STATE.ins[o.i.id] = o.i
  end

  return o
end


-- ------------------------------------------------------------------------
-- internal logic

function Output:process_ins()
  if self.i.changed then -- FIXME: make retrigger on TIE but not SKIP
    self:nb_play_volts(self.i.v)
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

function Output:nb_play(note, vel)
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

  self:nb_note_on(note, vel)
end

function Output:nb_play_volts(volts, vel)
  local note = round(util.linlin(0, V_MAX, 0, 127, volts))
  self:nb_play(note, vel)
end


-- ------------------------------------------------------------------------
-- screen

function Output:redraw()
  local trig = (math.abs(os.clock() - self.i.last_changed_t) < LINK_TRIG_DRAW_T)
  paperface.main_in(paperface.grid_to_screen_x(self.i.x), paperface.grid_to_screen_y(self.i.y), trig)
end

-- ------------------------------------------------------------------------

return Output

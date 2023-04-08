-- haleseq.
-- @eigen
--
--      8 stage       complex
--
--     sequencing    programmer
--
--    ▼ instructions below ▼
--
-- original idea by @hale


-- ------------------------------------------------------------------------
-- deps

local lattice = require "lattice"
local musicutil = require "musicutil"

local nb = include("haleseq/lib/nb/lib/nb")

local Stage = include("haleseq/lib/stage")
include("haleseq/lib/core")


-- ------------------------------------------------------------------------
-- conf

local FPS = 15
local GRID_FPS = 15

local STEPS_GRID_X_OFFSET = 4

local NB_STEPS = 8
local NB_VSTEPS = 4

local MCLOCK_DIVS = 64


-- ------------------------------------------------------------------------
-- state

local s_lattice

local g = nil
local has_grid = false

local g_knob = nil
local g_btn = nil

function grid_connect_maybe(_g)
  if not has_grid then
    g = grid.connect()
    if g.device ~= nil then
      g.key = grid_key
      has_grid = true
    end
  end
end

function grid_remove_maybe(_g)
  if g.device.port == _g.port then
    -- current grid got deconnected
    has_grid = false
  end
end


-- ------------------------------------------------------------------------
-- state - sequence values

local is_resetting = false

local prev_step = nil
local step = 1
local vstep = 1

local last_step_t = 0
local last_vstep_t = 0

local stages = {}
local seqvals = {}

local last_preset_t = 0

local V_MAX = 1000
local V_NB_OCTAVES = 10
local V_TRIG = 500

local PULSE_T = 0.02 --FIXME: don't use os.clock() but a lattice clock for stable gate beahvior


function init_stages(nb)
  for x=1,nb do
    stages[x] = Stage:new()
  end
end

function init_seqvals(nbx, nby)
  for x=1,nbx do
    seqvals[x] = {}
    for y=1,nby do
      seqvals[x][y] = V_MAX/2
    end
  end
end

function randomize_seqvals_octaves()
  local nbx = tab.count(seqvals)
  local nby = tab.count(seqvals[1])

  srand(math.random(10000))

  local octave = 3
  local octave_v = V_MAX / V_NB_OCTAVES
  for y=1,nby do
    for x=1,nbx do
      local note = math.random(octave_v + 1) - 1
      seqvals[x][y] = octave * octave_v + note
    end
    octave = octave + 1
  end
end

function randomize_seqvals_blip_bloop()
  local nbx = tab.count(seqvals)
  local nby = tab.count(seqvals[1])

  srand(math.random(10000))

  for y=1,nby do
    for x=1,nbx do
      local note = math.random(round(3*V_MAX/4) + 1) - 1
      seqvals[x][y] = note
    end
  end
end

function randomize_seqvals_scale(root_note)
  local nbx = tab.count(seqvals)
  local nby = tab.count(seqvals[1])

  local octaves = {1, 2, 3, 4}

  srand(math.random(10000))

  local chord_root_freq = tab.key(musicutil.NOTE_NAMES, root_note) - 1
  local scale = musicutil.generate_scale_of_length(chord_root_freq, nbx)
  local nb_notes_in_scale = tab.count(scale)

  for y=1,nby do
    for x=1,nbx do
      local note = scale[math.random(nb_notes_in_scale)] + 12 * octaves[math.random(4)]
      seqvals[x][y] = round(util.linlin(0, 127, 0, V_MAX, note))
    end
  end
end

function are_all_stage_skip(are_all_stage_skip)
  local nb_skipped = 0

  local start = params:get("preset")
  if are_all_stage_skip then
    start = 1
  end

  for s=start,NB_STEPS do
    if stages[s]:get_mode() == Stage.M_SKIP then
      nb_skipped = nb_skipped + 1
    end
  end
  return (nb_skipped == (NB_STEPS-start+1))
end

-- ------------------------------------------------------------------------
-- playback

local nb_playing_notes = {}

local last_enc_note_play_t = 0

function note_play(s, vs)
  local player = params:lookup_param("nb_voice_"..vs):get_player()

  if nb_playing_notes[vs] ~= nil then
    player:note_off(nb_playing_notes[vs])
    nb_playing_notes[vs] = nil
  end

  local v = 0
  if vs > NB_VSTEPS then -- special multiplexed step
    v = seqvals[s][vstep]
  else
    v = seqvals[s][vs]
  end

  local note = round(util.linlin(0, V_MAX, 0, 127, v))
  -- local vel = 0.8
  local vel = 1

  -- print("playing "..note)

  player:note_on(note, vel)
  nb_playing_notes[vs] = note
end

function curr_note_play(vs)
  local s = step
  if stages[s]:get_mode() == Stage.M_TIE and prev_step ~= nil then
    s = prev_step
  end
  note_play(s, vs)
end

function all_notes_off()
  for vs=1,NB_VSTEPS+1 do
    if nb_playing_notes[vs] ~= nil then
      player:note_off(nb_playing_notes[vs])
      nb_playing_notes[vs] = nil
    end
  end
end


-- ------------------------------------------------------------------------
-- sequence

local next_step = nil
local clock_acum = 0
local reverse = false
local hold = false

local next_vstep = nil
local vclock_acum = 0
local vreverse = false

-- base1 modulo
function mod1(v, m)
  return ((v - 1) % m) + 1
end

function is_whole_number(v)
  return (v%1 == 0)
end

function clock_div_opt_v(o)
  local m = {
    ['off'] = 0,
    ['1/1'] = 1,
    ['1/2'] = 2,
    ['1/4'] = 4,
    ['1/8'] = 8,
    ['1/16'] = 16,
    ['1/32'] = 32,
    ['1/64'] = 64,
  }
  return m[o]
end

function clock_tick(forced)
  local clock_div = clock_div_opt_v(params:string("clock_div"))
  if not forced then
    clock_acum = clock_acum + clock_div / MCLOCK_DIVS
  end

  -- NB: if clock is off (clock_div at 0), take immediate effect
  --     otherwise, wait for quantization
  if next_step ~= nil and ((clock_div == 0) or (clock_acum >= 1)) then
    if (clock_acum >= 1) then
      clock_acum = 0
    end
    step = next_step
    next_step = nil
    last_step_t = os.clock()
    return true
  end

  if clock_acum < 1 then
    return false
  end
  clock_acum = 0

  if hold then
    return false
  end

  if are_all_stage_skip(is_resetting) then
    return false
  end

  if stages[step]:get_mode() ~= Stage.M_TIE then
    prev_step = step
  end

  local sign = reverse and -1 or 1

  step = mod1(step + sign, NB_STEPS)

  -- skip until at preset
  if not is_resetting then
    while step < params:get("preset") do
      step = mod1(step + sign, NB_STEPS)
    end
  end
  -- skip stages in skip mode
  while stages[step]:get_mode() == Stage.M_SKIP do
    local sign = reverse and -1 or 1
    step = mod1(step + sign, NB_STEPS)
  end
  if step >= params:get("preset") then
    is_resetting = false
  end
  -- skip until at preset (2)
  if not is_resetting then
    while step < params:get("preset") do
      step = mod1(step + sign, NB_STEPS)
    end
  end

  last_step_t = os.clock()
  return true
end

function vclock_tick(forced)

  local vclock_div = clock_div_opt_v(params:string("vclock_div"))
  if not forced then
    vclock_acum = vclock_acum + vclock_div / MCLOCK_DIVS
  end

  -- NB: if clock is off (clock_div at 0), take immediate effect
  --     otherwise, wait for quantization
  if next_vstep ~= nil and ((vclock_div == 0) or (vclock_acum >= 1)) then
    if (vclock_acum >= 1) then
      vclock_acum = 0
    end
    vstep = next_vstep
    next_vstep = nil
    last_vstep_t = os.clock()
    return true
  end

  if vclock_acum < 1 then
    return false
  end
  vclock_acum = 0

  if next_vstep ~= nil then
    vstep = next_vstep
    next_vstep = nil
    last_vstep_t = os.clock()
    return true
  end

  local sign = vreverse and -1 or 1

  vstep = mod1(vstep + sign, NB_VSTEPS)

  last_vstep_t = os.clock()
  return true
end

function mclock_tick(t, forced)
  local ticked = clock_tick(forced)
  local vticked = vclock_tick(forced)

  if ticked then
    for vs=1,NB_VSTEPS do
      curr_note_play(vs)
    end
  end
  if ticked or vticked then
    curr_note_play(NB_VSTEPS+1)
  end
end

function reset()
  is_resetting = true
  next_step = 1
end

function reset_preset()
  next_step = params:get("preset")
end

function vreset()
  next_vstep = 1
end


-- ------------------------------------------------------------------------
-- script lifecycle

local redraw_clock
local grid_redraw_clock

function get_first_nb_voice_midi_param_option_id(voice_id)
  local nb_voices = params:lookup_param("nb_voice_"..voice_id).options
  for i, v in ipairs(nb_voices) do
    if util.string_starts(v, "midi: ") and not (util.string_starts(v, "midi: nb ") or util.string_starts(v, "midi: virtual ")) then
      return i
    end
  end
end

function init()
  screen.aa(0)
  screen.line_width(1)

  s_lattice = lattice:new{}

  grid_connect_maybe()

  -- --------------------------------
  -- state

  init_stages(NB_STEPS)
  init_seqvals(NB_STEPS, NB_VSTEPS)

  -- --------------------------------
  -- params

  params:add{type = "number", id = "preset", name = "Preset", min = 1, max = NB_STEPS, default = 1}
  params:set_action("preset",
                    function(v)
                      last_preset_t = os.clock()
                      reset_preset()
                    end
  )

  params:add_trigger("fw", "Forward")
  params:set_action("fw",
                    function(v)
                      clock_acum = clock_acum + 1
                      mclock_tick(nil, true)
                    end
  )
  params:add_trigger("bw", "Backward")
  params:set_action("bw",
                    function(v)
                      local reverse_prev = reverse
                      reverse = true
                      clock_acum = clock_acum + 1
                      mclock_tick(nil, true)
                      reverse = reverse_prev
                    end
  )
  params:add_trigger("vfw", "VForward")
  params:set_action("vfw",
                    function(v)
                      vclock_acum = vclock_acum + 1
                      mclock_tick(nil, true)
                    end
  )
  params:add_trigger("vbw", "VBackward")
  params:set_action("vbw",
                    function(v)
                      local vreverse_prev = vreverse
                      vreverse = true
                      vclock_acum = vclock_acum + 1
                      mclock_tick(nil, true)
                      vreverse = vreverse_prev
                    end
  )


  local RND_MODES = {'Scale', 'Blip Bloop'}
  params:add_trigger("rnd_seqs", "Randomize Seqs")
  params:set_action("rnd_seqs",
                    function(v)
                      if params:string("rnd_seq_mode") == 'Scale' then
                        randomize_seqvals_scale(params:string("rnd_seq_root"))
                      else
                        randomize_seqvals_blip_bloop()
                      end
                    end
  )
  params:add_option("rnd_seq_mode", "Rnd Mode", RND_MODES, tab.key(RND_MODES, 'Scale'))
  params:set_action("rnd_seq_mode",
                    function(v)
                      if RND_MODES[v] == 'Scale' then
                        params:show("rnd_seq_root")
                      else
                        params:hide("rnd_seq_root")
                      end
                      _menu.rebuild_params()
                    end
  )
  params:add_option("rnd_seq_root", "Rnd Scale", musicutil.NOTE_NAMES, tab.key(musicutil.NOTE_NAMES, 'C'))

  local CLOCK_DIVS = {'off', '1/1', '1/2', '1/4', '1/8', '1/16', '1/32', '1/64'}
  params:add_option("clock_div", "Clock Div", CLOCK_DIVS, tab.key(CLOCK_DIVS, '1/16'))
  params:add_option("vclock_div", "VClock Div", CLOCK_DIVS, tab.key(CLOCK_DIVS, '1/2'))

  local label_all = ""
  for vs=1, NB_VSTEPS + 1 do
    local label = ""
    if vs == NB_VSTEPS + 1 then
      label = label_all
    else
      label = string.char(string.byte("A") + vs - 1)
      label_all = label_all..label
    end

    local llabel = string.lower(label)

    params:add_group("track_"..llabel, label, 1)
    nb:add_param("track_out_nb_voice_"..llabel, "nb Voice "..label)
  end

  nb.voice_count = NB_VSTEPS + 1
  nb:init()
  for vs=1, NB_VSTEPS + 1 do
    nb_playing_notes[vs] = nil
    nb:add_param("nb_voice_"..vs, "nb Voice "..vs)
  end
  nb:add_player_params()

  -- FIXME: can't be set at init like that...
  -- NB: bind multiplexed voice to first midi out if found
  -- local vs_mux = NB_VSTEPS + 1
  -- local p_id = get_first_nb_voice_midi_param_option_id(vs_mux)
  -- if p_id ~= nil then
  --   params:set("nb_voice_"..vs_mux, p_id)
  -- end

  -- NB: randomize seqs
  params:set("rnd_seqs", 1)

  redraw_clock = clock.run(
    function()
      local step_s = 1 / FPS
      while true do
        clock.sleep(step_s)
        redraw()
      end
  end)
  grid_redraw_clock = clock.run(
    function()
      local step_s = 1 / GRID_FPS
      while true do
        clock.sleep(step_s)
        grid_redraw()
      end
  end)

  local sprocket = s_lattice:new_sprocket{
    action = mclock_tick,
    division = 1/MCLOCK_DIVS,
    enabled = true
  }
  s_lattice:start()
end

function cleanup()
  all_notes_off()
  clock.cancel(redraw_clock)
  clock.cancel(grid_redraw_clock)
  s_lattice:destroy()
end


-- ------------------------------------------------------------------------
-- grid

local G_Y_PRESS = 8
local G_Y_KNOB = 2

function grid_redraw()
  g:all(0)

  local l = 3

  for s=1,NB_STEPS do
    l = 3
    local x = s + STEPS_GRID_X_OFFSET
    local y = 1

    g:led(x, y, 1)     -- trig out
    y = y + 1
    g:led(x, y, 1)     -- trig in
    for vs=1,NB_VSTEPS do
      if (step == s) and (vstep == vs) then
        l = 15
      else
        l = round(util.linlin(0, V_MAX, 0, 12, seqvals[s][vs]))
      end
      g:led(x, G_Y_KNOB+vs, l) -- value
    end
    y = y + NB_VSTEPS + 1
    --                -- <pad>
    l = (params:get("preset") == s) and 5 or 1
    g:led(x, y, l)   -- tie / run / skip
    l = 1
    if next_step ~= nil then
      if next_step == s then
        l = 5
      elseif step == s then
        l = 2
      end
    elseif step == s then
      l = 10
    end
    g:led(x, G_Y_PRESS, l)   -- press / select in
  end

  local x = STEPS_GRID_X_OFFSET + NB_STEPS + 1
  for vs=1,NB_VSTEPS do
    l = (vstep == vs) and 5 or 1
    g:led(x, 2+vs, l) -- v out
  end

  g:led(16, 1, 5) -- vreset
  g:led(16, 2, 1) -- vclock
  g:led(16, 3, 5) -- reset
  g:led(16, 4, 3) -- hold
  g:led(16, 5, 5) -- preset
  g:led(16, 6, 3) -- reverse
  g:led(16, 7, 3) -- clock
  -- preset manual

  g:refresh()
end

function grid_key(x, y, z)
  if x > STEPS_GRID_X_OFFSET and x <= STEPS_GRID_X_OFFSET + NB_STEPS then
    if y == G_Y_PRESS then
      if (z >= 1) then
        local s = x - STEPS_GRID_X_OFFSET
        g_btn = s
        params:set("preset", s)
        last_preset_t = os.clock()
        -- mclock_tick(nil, true)
      else
        g_btn = false
      end
      return
    end
    if y == 7 and z >= 1 then
      local s = x - STEPS_GRID_X_OFFSET
      stages[s]:mode_cycle()
      return
    end
    if y >= G_Y_KNOB and y < G_Y_KNOB + NB_STEPS then
      if z >= 1 then
        local s = x - STEPS_GRID_X_OFFSET
        local vs = y - G_Y_KNOB
        g_knob = {s, vs}
      else
        g_knob = nil
      end
    end
  end

  if x == 16 and y == 1 and z >= 1 then
    vreset()
    return
  end
  if x == 16 and y == 3 and z >= 1 then
    reset()
    return
  end
  if x == 16 and y == 4 then
    hold = (z >= 1)
    return
  end
  if x == 16 and y == 5 and z >= 1 then
    reset_preset()
    return
  end
  if x == 16 and y == 6 then
    reverse = (z >= 1)
    return
  end
end

-- ------------------------------------------------------------------------
-- controls

function enc(n, d)

  if g_knob ~= nil then
    local v = g_knob[1]
    local vs = g_knob[2]
    seqvals[v][vs] = util.clamp(seqvals[v][vs] + d*5, 0, V_MAX)
    if (math.abs(os.clock() - last_enc_note_play_t) >= PULSE_T) then
      note_play(v, vs) -- retrig note to get a preview
      last_enc_note_play_t = os.clock()
    end
    return
  end

  if n == 1 then
    params:set("clock_tempo", params:get("clock_tempo") + d)
    return
  end
  if n == 2 then
    local sign = math.floor(d/math.abs(d))
    params:set("clock_div", params:get("clock_div") + sign)
    return
  end
  if n == 3 then
    local sign = math.floor(d/math.abs(d))
    params:set("vclock_div", params:get("vclock_div") + sign)
    return
  end
end

-- ------------------------------------------------------------------------
-- screen

local SCREEN_W = 128
local SCREEN_H = 64

local SCREEN_LEVEL_LABEL = 3
local SCREEN_LEVEL_LABEL_SPE = 5

local SCREEN_STAGE_W = 9
-- local SCREEN_STAGE_Y_OFFSET = 12
local SCREEN_STAGE_Y_OFFSET = 1

function draw_nana(x, y, fill)
  screen.aa(1)
  screen.level(10)
  local radius = math.floor((SCREEN_STAGE_W/2) - 1)
  screen.move(x + radius + 1, y)
  screen.circle(x + radius + 1, y + radius + 1, radius)
  if fill then
    screen.fill()
  else
    screen.stroke()
  end
end

-- panel graphic (square)
function draw_trig_out_label(x, y, l)
  screen.aa(0)

  if l == nil then l = SCREEN_LEVEL_LABEL end
  screen.level(l)

  screen.rect(x, y, SCREEN_STAGE_W, SCREEN_STAGE_W)
  screen.stroke()
end


function draw_trig_out(x, y, trig)
  draw_trig_out_label(x, y)
  if trig then
    draw_nana(x, y, trig)
  end
end

function draw_trig_out_special(x, y, trig)
  draw_trig_out_label(x, y, SCREEN_LEVEL_LABEL_SPE)
  if trig then
    draw_nana(x, y, trig)
  end
end

-- panel graphic (triangle)
function draw_trig_in_label(x, y, l)
  screen.aa(0)

  if l == nil then l = SCREEN_LEVEL_LABEL end
  screen.level(l)

  -- NB: for some reason looks better if doing a stroke in between
  screen.move(x, y)
  screen.line(x + SCREEN_STAGE_W / 2, y + SCREEN_STAGE_W / 2)
  screen.stroke()
  screen.move(x + SCREEN_STAGE_W / 2, y + SCREEN_STAGE_W / 2)
  screen.line(x + SCREEN_STAGE_W, y)
  screen.stroke()
end

function draw_trig_in_label_filled(x, y, l)
  screen.aa(0)

  if l == nil then l = SCREEN_LEVEL_LABEL end
  screen.level(l)

  screen.move(x, y)
  screen.line(x + SCREEN_STAGE_W / 2, y + SCREEN_STAGE_W / 2)
  screen.line(x + SCREEN_STAGE_W, y)
  screen.fill()
end

function draw_trig_in(x, y, trig)
  draw_trig_in_label(x, y)
  -- nana
  if trig then
    draw_nana(x, y, trig)
  end
end

function draw_trig_in_special(x, y, trig)
  draw_trig_in_label_filled(x, y, SCREEN_LEVEL_LABEL_SPE)
  -- nana
  if trig then
    draw_nana(x, y, trig)
  end
end

function draw_mode_run(x, y)
  screen.aa(1)
  screen.level(5)
  screen.pixel(round(x + SCREEN_STAGE_W / 2), round(y + SCREEN_STAGE_W / 2))
end

function draw_mode_tie(x, y)
  screen.aa(1)
  screen.level(5)
  screen.move(x, round(y + SCREEN_STAGE_W/2))
  screen.line(x + SCREEN_STAGE_W, round(y + SCREEN_STAGE_W/2))
end

function draw_mode_skip(x, y)
  screen.aa(0)
  screen.level(5)
  screen.move(x, y)
  screen.line(x + SCREEN_STAGE_W, y + SCREEN_STAGE_W)
  screen.stroke()
  screen.move(x + SCREEN_STAGE_W, y)
  screen.line(x, y + SCREEN_STAGE_W)
  screen.stroke()
end

function draw_preset(x, y)
  draw_nana(x, y, false)
end

function draw_knob(x, y, v)
  -- draw_nana(x, y, false)
  local radius = (SCREEN_STAGE_W/2) - 1
  local KNOB_BLINDSPOT_PERCENT = 10

  x = x + SCREEN_STAGE_W/2
  y = y + SCREEN_STAGE_W/2
  v2 = v - (V_MAX / 4)

  screen.aa(1)

  screen.move(round(x), round(y)+radius)

  -- screen.move(x, y)
  -- screen.line(x, y+radius)

  screen.arc(round(x), round(y), radius, math.pi/2, math.pi/2 + util.linlin(0, V_MAX, 0, math.pi * 2, v))
  screen.stroke()
  screen.move(x, y)
  screen.line(x + radius * cos(v2/V_MAX) * -1, y + radius * sin(v2/V_MAX))
  screen.stroke()
  -- screen.fill()
end

function redraw_stage(x, y, s)
  -- trig out
  local at = (step == s)
  local trig = at and (math.abs(os.clock() - last_step_t) < PULSE_T)
  draw_trig_out(x, y, trig)
  if not trig and at then
    draw_nana(x, y, false)
  end

  -- trig in
  y = y + SCREEN_STAGE_W
  if params:get("preset") == s then
      -- draw_preset(x, y)
    draw_trig_in_special(x, y, (g_btn == s))
  else
    draw_trig_in(x, y, (g_btn == s))
  end

  -- vals
  for vs=1,NB_VSTEPS do
    y = y + SCREEN_STAGE_W
    draw_knob(x, y, seqvals[s][vs])
  end

  -- mode
  y = y + SCREEN_STAGE_W
  local mode = stages[s]:get_mode()
  if mode == Stage.M_RUN then
    draw_mode_run(x, y)
  elseif mode == Stage.M_TIE then
    draw_mode_tie(x, y)
  elseif mode == Stage.M_SKIP then
    draw_mode_skip(x, y)
  end

end

function redraw()
  screen.clear()

  screen.level(15)

  -- clock(s)
  screen.move(0, 8)
  screen.text(params:get("clock_tempo") .. " BPM ")
  screen.move(0, 18)
  screen.text(params:string("clock_div"))
  screen.move(0, 28)
  screen.text(params:string("vclock_div"))

  -- seq
  local x = (SCREEN_W - (NB_STEPS * SCREEN_STAGE_W)) / 2
  for s=1,NB_STEPS do
    redraw_stage(x, SCREEN_STAGE_Y_OFFSET, s)
    x = x + SCREEN_STAGE_W
  end

  -- vseq
  local y = SCREEN_STAGE_Y_OFFSET + 2 * SCREEN_STAGE_W
  for vs=1,NB_VSTEPS do
    local at = (vstep == vs)
    local trig = at and (math.abs(os.clock() - last_vstep_t) < PULSE_T)
    draw_trig_out(x, y, trig)
    if not trig and at then
      draw_nana(x, y, false)
    end
    y = y + SCREEN_STAGE_W
  end

  -- preset gate out
  local y = SCREEN_STAGE_Y_OFFSET
  draw_trig_out_special(x, y, math.abs(os.clock() - last_preset_t) < PULSE_T)

  screen.update()
end

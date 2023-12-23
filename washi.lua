-- washi.
-- @eigen
--
--
--
--
--
--    ▼ instructions below ▼
--
-- based on the work of:
-- - Serge Tcherepnin
-- - Rex Probe
-- - Ken Stone
-- - Dakota Melin (@hale)


-- ------------------------------------------------------------------------
-- deps

local lattice = require "lattice"
local musicutil = require "musicutil"
local UI = require "ui"

nb = include("washi/lib/nb/lib/nb")
local inspect = include("washi/lib/inspect")

local paperface = include("washi/lib/paperface")
local patching = include("washi/lib/patching")
local Scope = include("washi/lib/scope")

local patch = include("washi/lib/patch")

-- modules
local NornsClock = include("washi/lib/module/norns_clock")
local QuantizedClock = include("washi/lib/module/quantized_clock")
local PulseDivider = include("washi/lib/module/pulse_divider")
local Rvg = include("washi/lib/module/rvg")
local LfoBank = include("washi/lib/module/lfo_bank")
local Haleseq = include("washi/lib/module/haleseq")
local Output = include("washi/lib/module/output")

local kbdutil
if seamstress ~= nil then
  include("washi/lib/seamstress_norns_compat")
  kbdutil = include("washi/lib/kbdutil")
end

include("washi/lib/core")
include("washi/lib/consts")


-- ------------------------------------------------------------------------
-- conf

-- local NB_HALESEQS = 1
local NB_HALESEQS = 2
local NB_OUTS = 6

local norns_clock
local quantized_clocks
local pulse_dividers = {}
local rvgs = {}
local lfos = {}
local haleseqs = {}
local outputs = {}

local page_list = {'clock', 'mod'}
for h=1, NB_HALESEQS do
  table.insert(page_list, 'haleseq '..h)
end
table.insert(page_list, 'outputs')
local pages = UI.Pages.new(1, #page_list)
pages:set_index(tab.key(page_list, 'haleseq 1'))
-- pages:set_index(tab.key(page_list, 'outputs'))

local DIAL_W = 20

local dialScaling = UI.Dial.new(SCREEN_W/4, SCREEN_H * 3/4 - DIAL_W/2, -- x / y
                                DIAL_W, -- size
                                1.0, -- v
                                -1.0, 1.0, -- min / max
                                nil, -- rounding (increments)
                                0, -- start v
                                {0} -- markers
)
local dialOffset = UI.Dial.new(SCREEN_W/4 + SCREEN_W/2 - DIAL_W, SCREEN_H * 3/4 - DIAL_W/2,
                               DIAL_W,
                               0,
                               0, 10,
                               nil,
                               0,
                               {0, 250, 500, 750},
                               "V")


-- ------------------------------------------------------------------------
-- patching

ins = {}
outs = {}
links = {}
link_props = {}
coords_to_nana = {}

STATE = {
  -- super clock counter
  superclk_t = 0,

  -- patch
  ins = ins,
  outs = outs,
  links = links,
  link_props = link_props,

  -- panel coords to banana LUT
  coords_to_nana = coords_to_nana,

  -- screen
  screen_dirty = true,

  -- grid
  grid_mode = M_PLAY,
  selected_nana = nil,
  selected_link = nil,
  scope = nil,

  -- for 64 grids...
  grid_cursor = 1,
  grid_cursor_active = false,
}

local function add_link(from_id, to_id)
  patching.add_link(links, from_id, to_id)
end

local function remove_link(from_id, to_id)
  patching.remove_link(links, from_id, to_id)
end

local function toggle_link(from_id, to_id)
  local action = patching.toggle_link(links, from_id, to_id)
  if action == A_ADDED then
    STATE.selected_link = {from_id, to_id}
  else -- A_REMOVED
    if STATE.selected_link ~= nil
      and are_coords_same(STATE.selected_link, {from_id, to_id}) then
      STATE.selected_link = nil
    end
  end
end

local function are_linked(from_id, to_id)
  return patching.are_linked(links, from_id, to_id)
end

local function get_out_first_link_maybe(o)
  local from_id = o.id
  if links[from_id] == nil or tab.count(links[from_id]) == 0 then
    return
  end

  local to_id = links[from_id][1]

  return {from_id, to_id}
end

local function get_in_first_link_maybe(i)
  for from_out_label, _v in pairs(i.incoming_vals) do
    if from_out_label ~= 'GLOBAL' then
      return {from_out_label, i.id}
    end
  end
end

local function get_first_link_maybe(nana)
  if nana.kind == 'out' then
    return get_out_first_link_maybe(nana)
  else
    return get_in_first_link_maybe(nana)
  end
end

local function fire_and_propagate(in_label, initial_v)
  return patching.fire_and_propagate(outs, ins, links, link_props,
                                     in_label, initial_v)
end


-- ------------------------------------------------------------------------
-- state

local s_lattice

local g = nil
local has_grid = false

local g_knob = nil
local g_btn = nil


function should_display_grid_cursor()
  return (has_grid and g.cols < SCREEN_STAGE_X_NB)
end


function grid_connect_maybe(_g)
  if not has_grid then
    g = grid.connect()
    if g.device ~= nil then
      g.key = grid_key
      has_grid = true
      STATE.grid_cursor = 1
      STATE.grid_cursor_active = (g.cols < SCREEN_STAGE_X_NB)
    end
  end
end


function grid_remove_maybe(_g)
  if g.device.port == _g.port then
    -- current grid got deconnected
    has_grid = false
    STATE.grid_cursor_active = false
  end
end


local function get_current_haleseq()
  local curr_page = page_list[pages.index]
  for i=1,NB_HALESEQS do
    if curr_page == "haleseq "..i then
      return haleseqs[i]
    end
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
local last_preset_t = 0

local stages = {}
local seqvals = {}

local V_MAX = 1000
local V_NB_OCTAVES = 10
local V_TRIG = 500


-- ------------------------------------------------------------------------
-- playback

local last_enc_note_play_t = 0

function all_notes_off()
  for _, o in ipairs(outputs) do
    o:nb_note_off()
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

local mclock_acum = 0
local last_mclock_tick_t = 0

is_doing_stuff = false

function mclock_tick(t, forced)
  if mclock_acum % (MCLOCK_DIVS / NB_BARS) == 0 then
    last_mclock_tick_t = STATE.superclk_t
  end
  if not forced then
    mclock_acum = mclock_acum + 1
  end

  if is_doing_stuff then
    return
  end

  is_doing_stuff = true

  fire_and_propagate("norns_clock", V_MAX/2)
  fire_and_propagate("norns_clock", 0)

  is_doing_stuff = false
end


-- ------------------------------------------------------------------------
-- script lifecycle

local redraw_clock
local grid_redraw_clock
local super_clock

function get_first_nb_voice_midi_param_option_id(voice_id)
  local nb_voices = params:lookup_param("nb_voice_"..voice_id).options
  for i, v in ipairs(nb_voices) do
    if util.string_starts(v, "midi: ") and not (util.string_starts(v, "midi: nb ") or util.string_starts(v, "midi: virtual ")) then
      return i
    end
  end
end

local PATCH_CONF_EXT = ".washipatch"

params.action_read = function(filename, name, pset_number)
  local conf = dofile(filename..PATCH_CONF_EXT)

  for i, hc in ipairs(conf.haleseqs) do
    if haleseqs[i] ~= nil then
      treplace(haleseqs[i].seqvals, hc)
    end
  end

  treplace(links, conf.links)
  treplace(link_props, conf.link_props)
end

params.action_write = function(filename, name, pset_number)
  local conf = {}

  conf.version = "0.1"

  conf.haleseqs = {}
  for i, h in ipairs(haleseqs) do
	conf.haleseqs[i] = h.seqvals
  end

  conf.links = links
  conf.link_props = link_props

  local confStr = inspect(conf)
  local f, err = io.open(filename..PATCH_CONF_EXT, "wb")
  if err then
    print("FAILED TO WRITE "..filename..PATCH_CONF_EXT)
    return
  end
  f:write("return "..confStr)
  io.close(f)
end

params.action_delete = function(filename, name, pset_number)
  os.execute("rm -f" .. filename .. PATCH_CONF_EXT)
end

if seamstress then
  midi.add = function (dev, is_input)
    if not is_input then
      print("new midi out detected: "..dev.name)
      nb.add_midi_player_seamstress(dev)
      -- update all
      for _, o in ipairs(outputs) do
        -- patched to update if already set
        nb:add_param("nb_voice_" .. o.id, "nb Voice " .. o.id)
      end
    end
  end
end


function init()
  screen.aa(0)
  screen.line_width(1)

  if seamstress then
     screen.set_size(SCREEN_W, SCREEN_H, 5)
  end

  s_lattice = lattice:new{}

  grid_connect_maybe()

  nb.voice_count = NB_OUTS
  nb:init()

  local scope = Scope.new('popup', STATE)
  STATE.scope = scope

  -- stages[5].o = 2

  -- --------------------------------
  -- global params

  params:add_trigger("init_patch", "Init Patch")
  params:set_action("init_patch",
                    function(_v)
                      patch.init(STATE)
                    end
  )

  params:add_trigger("clear_patch", "Clear Patch")
  params:set_action("clear_patch",
                    function(_v)
                      patch.clear(STATE)
                    end
  )

  params:add_trigger("rnd_all", "Randomize All")
  params:set_action("rnd_all",
                    function(_v)
                      params:set("rnd_seq_root", math.random(#musicutil.NOTE_NAMES))
                      params:set("rnd_seqs", 1)
                      patch.random(STATE, pulse_dividers, rvgs, lfos, haleseqs, outputs)
                    end
  )

  params:add_trigger("rnd_patch", "Randomize Patch")
  params:set_action("rnd_patch",
                    function(_v)
                      patch.random(STATE, pulse_dividers, rvgs, lfos, haleseqs, outputs)
                    end
  )

  params:add_trigger("rnd_seqs", "Randomize Seqs")
  params:set_action("rnd_seqs",
                    function(_v)
                      for _, h in ipairs(haleseqs) do
                        local fqid = h.fqid
                        params:set(fqid.."_rnd_seqs", 1)
                      end
                    end
  )

  local RND_MODES = {'Scale', 'Blip Bloop'}
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

  params:add{type = "number", id = "pulse_width", name = "Pulse Width", min = 1, max = 100, default = 10}


  -- --------------------------------
  -- modules

  params:add_separator("modules", "modules")

  norns_clock = NornsClock.init(STATE,
                                tab.key(page_list, 'clock'), 2, 1)
  quantized_clocks = QuantizedClock.init("global", STATE, MCLOCK_DIVS, CLOCK_DIV_DENOMS,
                                         tab.key(page_list, 'clock'), 4, 1)

  pulse_dividers[1] = PulseDivider.init(1, STATE, nil,
                                        tab.key(page_list, 'clock'), 9, 1)

  rvgs[1] = Rvg.init(1, STATE,
                     tab.key(page_list, 'mod'), 2, 1)
  lfos[1] = LfoBank.init(1, STATE,
                         LFO_PHASES, {},
                         tab.key(page_list, 'mod'), 5, 1)
  local BRATIO = 10
  lfos[2] = LfoBank.init(2, STATE,
                         {0, 2, 7, 44, 58, 79, 122},
                         {37/BRATIO, 27/BRATIO, 6.51/BRATIO, 3/BRATIO, 1.52/BRATIO, 1.21/BRATIO, 1/BRATIO},
                         tab.key(page_list, 'mod'), 10, 1)

  for i=1,NB_HALESEQS do
    local h = Haleseq.init(i, STATE, NB_STEPS, NB_VSTEPS,
                           tab.key(page_list, 'haleseq '..i), 0, 0)
    haleseqs[i] = h
  end

  params:add_separator("outputs", "outputs")

  local ox = 2
  for o=1,NB_OUTS do
    local label = ""..o
    if o ~= 1 and mod1(o,2) == 1 then
      ox = ox + 4
    end
    local oy = mod1(o,2) * 3
    outputs[o] = Output.init(label, STATE,
                             tab.key(page_list, 'outputs'), ox, oy)
  end

  patch.init(STATE)


  -- --------------------------------

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
        if STATE.screen_dirty then
          redraw()
          STATE.screen_dirty = false
        end
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

  super_clock = clock.run(
    function()
      while true do
        clock.sleep(SCLOCK_FREQ)
        STATE.superclk_t = STATE.superclk_t + SCLOCK_FREQ
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

  STATE.scope:cleanup()
  for _, rvg in ipairs(rvgs) do
    rvg:cleanup()
  end
  for _, lfo in ipairs(lfos) do
    lfo:cleanup()
  end

  s_lattice:destroy()
end


-- ------------------------------------------------------------------------
-- ux - linking

function select_or_link(nana)
  if (nana.kind == 'in' or nana.kind == 'comparator') then
    if (STATE.selected_nana ~= nil and STATE.selected_nana.kind == 'out') then
      if STATE.grid_mode == M_LINK then
        local action = toggle_link(STATE.selected_nana.id, nana.id)
      elseif STATE.grid_mode == M_EDIT and are_linked(STATE.selected_nana.id, nana.id) then
        STATE.selected_link = {STATE.selected_nana.id, nana.id}
      end
    else
      STATE.selected_nana = nana
      STATE.selected_link = get_first_link_maybe(STATE.selected_nana)
    end
  end

  if nana.kind == 'out' then
    if (STATE.selected_nana ~= nil and (STATE.selected_nana.kind == 'in' or STATE.selected_nana.kind == 'comparator')) then
      if STATE.grid_mode == M_LINK then
        toggle_link(nana.id, STATE.selected_nana.id)
      elseif STATE.grid_mode == M_EDIT and are_linked(nana.id, STATE.selected_nana.id) then
        STATE.selected_link = {nana.id, STATE.selected_nana.id}
      end
    else
      STATE.selected_nana = nana
      STATE.selected_link = get_first_link_maybe(STATE.selected_nana)
    end
  end
end

-- ------------------------------------------------------------------------
-- grid

local G_Y_PRESS = 8
local G_Y_KNOB = 2

local grid_redraw_counter = 0


function grid_redraw()
  grid_redraw_counter = grid_redraw_counter + 1

  g:all(0)

  local curr_page = page_list[pages.index]

  if curr_page == 'clock' then
    norns_clock:grid_redraw(g, quantized_clocks.mclock_mult_trig)
    quantized_clocks:grid_redraw(g)
    pulse_dividers[1]:grid_redraw(g)
  elseif curr_page == 'mod' then
    rvgs[1]:grid_redraw(g)
    lfos[1]:grid_redraw(g)
    lfos[2]:grid_redraw(g)
  elseif curr_page == 'outputs' then
    for _, o in ipairs(outputs) do
      o:grid_redraw(g)
    end
  else
    local h = get_current_haleseq()
    if h ~= nil then
      h:grid_redraw(g)
    end
  end

  local l

  -- mode
  l = grid_level_radio(g, (STATE.grid_mode == M_PLAY), grid_redraw_counter)
  g:led(1, 1, l) -- play
  l = grid_level_radio(g, (STATE.grid_mode == M_SCOPE), grid_redraw_counter)
  g:led(2, 1, l) -- scope
  l = grid_level_radio(g, (STATE.grid_mode == M_LINK), grid_redraw_counter)
  g:led(3, 1, l) -- link
  l = grid_level_radio(g, (STATE.grid_mode == M_EDIT), grid_redraw_counter)
  g:led(4, 1, l) -- edit

  -- prev / next
  if should_display_grid_cursor() then
    l = (STATE.grid_cursor > 1) and 10 or 2
    g:led(g.cols - 1, 1, l) -- prev
    l = STATE.grid_cursor + g.cols - 1 == SCREEN_STAGE_X_NB and 2 or 10
    g:led(g.cols , 1, l)    -- next
  end

  g:refresh()
end

function grid_key(x, y, z)

  -- mode
  if y == 1 and x == 1 and z >= 1 then
    STATE.grid_mode = M_PLAY
    -- STATE.selected_nana = nil
    -- STATE.selected_link = nil
    STATE.scope:clear()
    STATE.screen_dirty = true
    return
  elseif y == 1 and x == 2 and z >= 1 then
    STATE.grid_mode = M_SCOPE
    -- STATE.selected_nana = nil
    -- STATE.selected_link = nil
    STATE.screen_dirty = true
    return
  elseif y == 1 and x == 3 and z >= 1 then
    STATE.grid_mode = M_LINK
    STATE.scope:clear()
    STATE.screen_dirty = true
    return
  elseif y == 1 and x == 4 and z >= 1 then
    STATE.grid_mode = M_EDIT
    STATE.scope:clear()
    STATE.screen_dirty = true
    return
  end

  -- prev/next
  if should_display_grid_cursor() then
    if y == 1 and z >= 1 and ((x == g.cols-1) or (x == g.cols)) then
      local prev_v = STATE.grid_cursor
      local sign = (x == g.cols-1) and -1 or 1
      STATE.grid_cursor = util.clamp(STATE.grid_cursor + sign, 1, SCREEN_STAGE_X_NB - g.cols + 1)
      if STATE.grid_cursor ~= prev_v then
        STATE.scope:clear()
      end
      STATE.screen_dirty = true
      return
    end
  end


  local curr_page = pages.index

  local screen_coord = curr_page.."."..paperface.grid_x_to_panel_x(g, x).."."..paperface.grid_y_to_panel_y(g, y)
  if should_display_grid_cursor() then
    screen_coord = curr_page.."."..paperface.grid_x_to_panel_x(g, x, STATE.grid_cursor - 1).."."..paperface.grid_y_to_panel_y(g, y)
  end

  local nana = STATE.coords_to_nana[screen_coord]
  if nana ~= nil then

    if STATE.grid_mode == M_SCOPE then
      if (z >= 1) then
        STATE.scope:assoc(nana)
      else
        STATE.scope:clear()
      end
      STATE.screen_dirty = true
      return
    end

    if z >= 1 then
      select_or_link(nana)
    end

    -- if (nana.kind == 'in' or nana.kind == 'comparator') and z >= 1 then
    --   if (STATE.selected_nana ~= nil and STATE.selected_nana.kind == 'out') then
    --     if STATE.grid_mode == M_LINK then
    --       local action = toggle_link(STATE.selected_nana.id, nana.id)
    --     elseif STATE.grid_mode == M_EDIT and are_linked(STATE.selected_nana.id, nana.id) then
    --       STATE.selected_link = {STATE.selected_nana.id, nana.id}
    --     end
    --   else
    --     STATE.selected_nana = nana
    --     STATE.selected_link = get_first_link_maybe(STATE.selected_nana)
    --   end
    -- end

    -- if nana.kind == 'out' and z >= 1 then
    --   if (STATE.selected_nana ~= nil and (STATE.selected_nana.kind == 'in' or STATE.selected_nana.kind == 'comparator')) then
    --     if STATE.grid_mode == M_LINK then
    --       toggle_link(nana.id, STATE.selected_nana.id)
    --     elseif STATE.grid_mode == M_EDIT and are_linked(nana.id, STATE.selected_nana.id) then
    --       STATE.selected_link = {nana.id, STATE.selected_nana.id}
    --     end
    --   else
    --     STATE.selected_nana = nana
    --     STATE.selected_link = get_first_link_maybe(STATE.selected_nana)
    --   end
    -- end
  else
    STATE.scope:clear()
    STATE.selected_nana = nil
    STATE.selected_link = nil
  end

  if STATE.grid_mode ~= M_PLAY then
    STATE.screen_dirty = true
    return
  end

  local h = get_current_haleseq()
  if h ~= nil then
    h:grid_key(x, y, z)
    STATE.screen_dirty = true
  end

end


-- ------------------------------------------------------------------------
-- mouse

screen.click = function(x, y, state, button)

  if state >= 1 then
    local curr_page = pages.index
    local screen_coord = curr_page.."."..paperface.screen_x_to_panel_grid(x).."."..paperface.screen_y_to_panel_grid(y)
    local nana = STATE.coords_to_nana[screen_coord]

    if nana == nil then
      STATE.scope:clear()
      STATE.selected_nana = nil
      STATE.selected_link = nil
      STATE.grid_mode = M_SCOPE
      return
    end

    if button == 1 then -- left click
      STATE.grid_mode = M_LINK
      select_or_link(nana)
    end

    if button == 3 then --right click
      STATE.grid_mode = M_SCOPE
      STATE.scope:assoc(nana)
    end

  end
end


-- ------------------------------------------------------------------------
-- keys / encs

if seamstress then
  screen.key = function(char, modifiers, is_repeat, state)

    if char == nil then
      return
    end

    if type(char) == "string" then
      if char == "s" and state >= 1 then
        STATE.grid_mode = M_SCOPE
      end

      if char == "r" and state >= 1 then
        if #modifiers == 0 then
          params:set("rnd_seqs", 1)
        elseif kbdutil.isShift(modifiers) then
          params:set("rnd_all", 1)
        end
      end

      if char == "i" and kbdutil.isShift(modifiers) and state >= 1 then
        params:set("init_patch", 1)
      end

      if char == "c" and kbdutil.isShift(modifiers) and state >= 1 then
        params:set("clear_patch", 1)
      end
    end

    if char.name ~= nil then
      if char.name == "up" and state >= 1 then
        STATE.scope:clear()
        pages:set_index_delta(-1, false)
      end
      if char.name == "down" and state >= 1 then
        STATE.scope:clear()
        pages:set_index_delta(1, false)
      end
    end

    STATE.screen_dirty = true
  end
end

local k1 = false
local k3 = false

function key(n, v)

  -- single modifiers
  if n == 1 then
    k1 = (v == 1)
  end
  if n == 3 then
    k3 = (v == 1)
  end

  if k1 and k3 then
    params:set("rnd_all", 1)
    STATE.screen_dirty = true
  end
end

function enc(n, d)
  local curr_page = page_list[pages.index]

  if STATE.grid_mode == M_EDIT and (n == 2 or n == 3) then
    if STATE.selected_link ~= nil then
      local from_id = STATE.selected_link[1]
      local to_id = STATE.selected_link[2]
      local lprops = patching.get_or_init_link_props(link_props, from_id, to_id)
      if n == 2 then
        lprops.scaling = util.clamp(lprops.scaling + (d/20), -1.0, 1.0)
      elseif n == 3 then
        lprops.offset = util.clamp(lprops.offset + d * 5, 0, V_MAX)
      end
    end
    STATE.screen_dirty = true
    return
  end

  if curr_page == "clock" then
    if n == 2 then
      local sign = math.floor(d/math.abs(d))
      params:set("pulse_divider_1_clock_div", params:get("pulse_divider_1_clock_div") + sign)
      return
    end
  end

  local h = get_current_haleseq()
  if h ~= nil then
    local id = h:get_id()

    if h:is_editing_knob() then
      h:knob(n, d)

      -- retrig note to get a preview
      if ((STATE.superclk_t - last_enc_note_play_t) >= trig_threshold_time()) then
        local vs = h:knob_vs()
        local volts = h:knob_volts()

        local target_in_labels = links[h.cv_outs[vs].id]
        if target_in_labels ~= nil then
          for _, in_label in ipairs(target_in_labels) do
            if util.string_starts(in_label, "output_") then
              local o = ins[in_label].parent
              o:nb_play_volts(volts)
            end
          end
        end

        local target_in_labels_mux = links[h.cv_outs[h.nb_vsteps+1].id]
        if target_in_labels_mux ~= nil then
          for _, in_label in ipairs(target_in_labels_mux) do
            if util.string_starts(in_label, "output_") then
              local o = ins[in_label].parent
              o:nb_play_volts(volts)
            end
          end
        end

        last_enc_note_play_t = STATE.superclk_t
      end

      STATE.screen_dirty = true
      return
    end

    if n == 2 then
      local sign = math.floor(d/math.abs(d))
      params:set("clock_div_"..id, params:get("clock_div_"..id) + sign)
      return
    end
    if n == 3 then
      local sign = math.floor(d/math.abs(d))
      params:set("vclock_div_"..id, params:get("vclock_div_"..id) + sign)
      return
    end

  end

  if n == 1 then
    if k1 and should_display_grid_cursor() then
      local prev_v = STATE.grid_cursor
      local sign = math.floor(d/math.abs(d))
      STATE.grid_cursor = util.clamp(STATE.grid_cursor + sign, 1, SCREEN_STAGE_X_NB - g.cols + 1)
      if STATE.grid_cursor ~= prev_v then
        STATE.scope:clear()
      end
      STATE.screen_dirty = true
      return
    end

    -- params:set("clock_tempo", params:get("clock_tempo") + d)
    STATE.scope:clear()
    pages:set_index_delta(d, false)
    STATE.screen_dirty = true
    return
  end
end


-- ------------------------------------------------------------------------
-- screen

function redraw_clock_screen()

  -- NB: `norns_clock` & `quantized_clocks` act a single module
  -- here we're faking the display of the' link bewteen the 2 as a clock multiplier while it's in fact implemented as a clock divider
  -- hence why we're manually drawing the links and showing the trigger ins independently of the real inputs' ins.
  quantized_clocks:redraw()
  norns_clock:redraw(quantized_clocks.mclock_mult_trig)
  if quantized_clocks.mclock_mult_trig then
    paperface.draw_link(norns_clock.x, norns_clock.y, 1, quantized_clocks.x, quantized_clocks.y, 1, 1)
  end

  pulse_dividers[1]:redraw()
end

function redraw_link_edit()
  local x = SCREEN_W/4
  local y = SCREEN_H/4
  local w = SCREEN_W/2
  local h = SCREEN_H/2

  local from_id = STATE.selected_link[1]
  local to_id = STATE.selected_link[2]
  local lprops = patching.get_or_init_link_props(link_props, from_id, to_id)
  local v = patching.get_link_v(link_props, outs[from_id], ins[to_id])
  STATE.scope:sample_raw(v)

  local scope_x = SCREEN_W/4
  local scope_y = SCREEN_H/8
  local scope_w = SCREEN_W/2
  local scope_h = (SCREEN_H * 3/4) * 1/2
  STATE.scope:redraw(scope_x, scope_y, scope_w, scope_h)

  screen.level(2)
  local offset_pixel_v = util.linlin(0, V_MAX, 0, scope_h-2, lprops.offset)
  local offset_pixel_y = scope_y + scope_h - offset_pixel_v
  screen.move(scope_x, offset_pixel_y)
  screen.line(scope_x + scope_w, offset_pixel_y)
  screen.stroke()

  dialScaling:set_value(lprops.scaling)
  dialScaling:redraw()
  dialOffset:set_value(util.linlin(0, V_MAX, 0, 10, lprops.offset))
  dialOffset:redraw()
end

function redraw()
  screen.clear()

  pages:redraw()

  screen.level(15)

  local curr_page = page_list[pages.index]
  if curr_page == 'clock' then
    redraw_clock_screen()
  elseif curr_page == 'mod' then
    rvgs[1]:redraw()
    lfos[1]:redraw()
    screen.level(SCREEN_LEVEL_LABEL)
    for i, phase in ipairs(LFO_PHASES) do
      if tab.contains({0, 90, 180, 270}, phase) then
        local x = paperface.panel_grid_to_screen_x(lfos[1].x + 1) + SCREEN_STAGE_W + 2
        local y = paperface.panel_grid_to_screen_y(i) + SCREEN_LABEL_Y_OFFSET
        screen.move(x, y)
        if norns then phase = phase.."°" end
        screen.text(phase)
      end
    end
    lfos[2]:redraw()
    screen.level(SCREEN_LEVEL_LABEL)
    local x = paperface.panel_grid_to_screen_x(lfos[2].x + 1) + SCREEN_STAGE_W + 2
    local yf = paperface.panel_grid_to_screen_y(1) + SCREEN_LABEL_Y_OFFSET
    local ys = paperface.panel_grid_to_screen_y(7) + SCREEN_LABEL_Y_OFFSET
    screen.move(x, yf)
    screen.text("f")
    screen.move(x, ys)
    screen.text("s")
  elseif curr_page == 'outputs' then
    for _, o in ipairs(outputs) do
      o:redraw()
    end
  else
    local h = get_current_haleseq()
    if h ~= nil then
      h:redraw()
    end
  end

  if should_display_grid_cursor() then
    screen.aa(0)
    screen.level(4)
    local x0 = paperface.panel_grid_to_screen_x(STATE.grid_cursor)
    if x0 == 0 then
      x0 = 1
    end
    local x1 = paperface.panel_grid_to_screen_x(STATE.grid_cursor + g.cols)
    local y0 = paperface.panel_grid_to_screen_y(1)
    local y1 = paperface.panel_grid_to_screen_y(SCREEN_STAGE_Y_NB+1)
    screen.rect(x0, 1, (x1 - x0), (y1 - y0))
    screen.stroke()
  end

  if STATE.scope:is_on() then
    STATE.scope:redraw(SCREEN_W/4, SCREEN_H/4, SCREEN_W/2, SCREEN_H/2)
  end

  local draw_mode = DRAW_M_NORMAL
  if (STATE.grid_mode == M_LINK or STATE.grid_mode == M_EDIT) then
    draw_mode = DRAW_M_TAME
  end
  -- print(draw_mode)
  paperface.redraw_active_links(outs, ins,
                                pages.index, draw_mode)

  if STATE.grid_mode == M_EDIT and STATE.selected_link ~= nil then
    redraw_link_edit()
    local from_id = STATE.selected_link[1]
    local to_id = STATE.selected_link[2]
    paperface.redraw_link(outs[from_id], ins[to_id], pages.index, DRAW_M_FOCUS)
  elseif STATE.selected_nana ~= nil then
    -- TODO: here
    paperface.redraw_nana_links(outs, ins, links,
                                STATE.selected_nana, pages.index, DRAW_M_FOCUS)
  end

  screen.update()
end

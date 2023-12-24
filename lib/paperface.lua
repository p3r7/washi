-- washi. paperface
--
-- norns' screen represent a panel, comprised of 7 rows & 17 columns
-- each cell of the grid is 9x9 pixels (`SCREEN_STAGE_W`)

local paperface = {}


-- ------------------------------------------------------------------------
-- deps

local Stage = include("washi/lib/submodule/stage")
local patching = include("washi/lib/patching")

include("washi/lib/consts")


-- ------------------------------------------------------------------------
-- panel grid

function paperface.panel_to_grid_x(g, v)
  return g.cols - SCREEN_STAGE_X_NB + v
end

function paperface.panel_to_grid_x_offset(g, v, offset)
  return v - offset
end

function paperface.panel_to_grid_y(g, v)
  return g.rows - SCREEN_STAGE_Y_NB + v
end

function paperface.grid_x_to_panel_x(g, v, offset)
  if offset ~= nil then
    return v + offset
  end

  return v - (g.cols - SCREEN_STAGE_X_NB)
end

function paperface.grid_y_to_panel_y(g, v)
  return v - (g.rows - SCREEN_STAGE_Y_NB)
end

function paperface.panel_grid_to_screen_x(v)
  return (v-1) * SCREEN_STAGE_W
end

function paperface.panel_grid_to_screen_y(v)
  return paperface.panel_grid_to_screen_x(v) + SCREEN_STAGE_Y_OFFSET
end

function paperface.screen_x_to_panel_grid(v)
  return math.floor((v / SCREEN_STAGE_W) + 1)
end

function paperface.screen_y_to_panel_grid(v)
  return math.floor(paperface.screen_x_to_panel_grid(v - SCREEN_STAGE_Y_OFFSET ))
end


-- ------------------------------------------------------------------------
-- grid

function paperface.panel_to_grid_redraw(px, py, g, l, grid_cursor)
  if l == nil then l = 3 end

  local x
  if grid_cursor ~= nil then
    local grid_offset = grid_cursor - 1
    x = paperface.panel_to_grid_x_offset(g, px, grid_offset)
  else
    x = paperface.panel_to_grid_x(g, px)
  end
  local y = paperface.panel_to_grid_y(g, py)

  if x <= 0 or x > g.cols then
    return
  end

  g:led(x, y, l)
end

function paperface.in_grid_redraw(i, g, l)
  if i.x == nil or i.y == nil then
    return
  end

  if l == nil then l = 3 end

  local x
  if i.parent.STATE.grid_cursor_active then
    local grid_offset = i.parent.STATE.grid_cursor - 1
    x = paperface.panel_to_grid_x_offset(g, i.x, grid_offset)
  else
    x = paperface.panel_to_grid_x(g, i.x)
  end
  local y = paperface.panel_to_grid_y(g, i.y)

  if x <= 0 or x > g.cols then
    return
  end

  local scock_t = i.parent.STATE.superclk_t
  if i.kind == 'comparator' then
    local triggered = ( i.status == 1
                        or ((scock_t - i.last_up_t) < LINK_TRIG_DRAW_T) )
    if triggered then
      l = 10
    end
  elseif i.kind == 'in' then
    local triggered = ( (scock_t - i.last_changed_t) < LINK_TRIG_DRAW_T )
    if triggered then
      l = 10
    end
  end

  g:led(x, y, l)
end

function paperface.out_grid_redraw(o, g, l)
  if o.x == nil or o.y == nil then
    return
  end

  if l == nil then l = 3 end

  local x
  if o.parent.STATE.grid_cursor_active then
    local grid_offset = o.parent.STATE.grid_cursor - 1
    x = paperface.panel_to_grid_x_offset(g, o.x, grid_offset)
  else
    x = paperface.panel_to_grid_x(g, o.x)
  end
  local y = paperface.panel_to_grid_y(g, o.y)

  if x <= 0 or x > g.cols then
    return
  end

  local sclock_t = o.parent.STATE.superclk_t
  if ( (sclock_t - o.last_changed_t) < LINK_TRIG_DRAW_T ) then
    l = 10
  end
  g:led(x, y, l)
end

function paperface.module_grid_redraw(m, g)
  if m.ins ~= nil then
    for _, i_label in ipairs(m.ins) do
      local i = m.STATE.ins[i_label]
      if i ~= nil then
        paperface.in_grid_redraw(i, g)
      end
    end
  end

  if m.outs ~= nil then
    for _, o_label in pairs(m.outs) do
      local o = m.STATE.outs[o_label]
      if o ~= nil then
        paperface.out_grid_redraw(o, g)
      end
    end
  end
end

-- ------------------------------------------------------------------------
-- screen - switches

function draw_mode_run(x, y)
  screen.aa(0)
  screen.level(5)
  screen.pixel(math.floor(x + SCREEN_STAGE_W / 2), math.floor(y + SCREEN_STAGE_W / 2))
  screen.stroke()
end

function draw_mode_tie(x, y)
  screen.aa(0)
  screen.level(5)
  screen.move(x, round(y + SCREEN_STAGE_W/2))
  screen.line(x + SCREEN_STAGE_W, round(y + SCREEN_STAGE_W/2))
  screen.stroke()
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

function paperface.mode_switch(x, y, mode)
  if mode == Stage.M_RUN then
    draw_mode_run(x, y)
  elseif mode == Stage.M_TIE then
    draw_mode_tie(x, y)
  elseif mode == Stage.M_SKIP then
    draw_mode_skip(x, y)
  end
end


-- ------------------------------------------------------------------------
-- screen - knobs

function paperface.knob(x, y, v, l)

  if l then
    screen.level(l)
  end

  local radius = (SCREEN_STAGE_W/2) - 1
  -- local KNB_BLINDSPOT_PCT = 10
  local KNB_BLINDSPOT_PCT = 0

  -- NB: drawing an arc slightly overshoots compared to the equivalent x,y coords
  local ARC_OVERSHOOT_COMP = 0.2

  x = x + SCREEN_STAGE_W/2 - 0.5
  y = y + SCREEN_STAGE_W/2 - 0.5

  local v_offset = - (V_MAX / 4)
  local v_blind_pct = KNB_BLINDSPOT_PCT * V_MAX / 100
  local v2 = v + v_offset + (v_blind_pct/4)
  local v_max = V_MAX + v_blind_pct

  screen.aa(1)

  local arc_start_x = x + radius * cos((v_offset + (v_blind_pct/4))/v_max) * -1
  local arc_start_y = y + radius * sin((v_offset + (v_blind_pct/4))/v_max)

  local arc_end_x = x + radius * cos(v2/v_max) * -1
  local arc_end_y = y + radius * sin(v2/v_max)

  local arc_start = KNB_BLINDSPOT_PCT/100 - 1/4

  screen.move(round(x), round(y))
  screen.line(arc_start_x, arc_start_y)

  local arc_offset = KNB_BLINDSPOT_PCT * math.pi*2 / 100
  if norns then
    screen.arc(round(x), round(y), radius,
               math.pi/2 + (arc_offset/2),
               math.pi/2 + (arc_offset/2) + util.linlin(0, v_max, 0, math.pi * 2 - ARC_OVERSHOOT_COMP, v))
  end
  if seamstress then
    -- FIXME: doesn't do shit
    screen.move(round(x), round(y))
    -- screen.arc(radius,
    --            math.pi/2 + (arc_offset/2),
    --            math.pi/2 + (arc_offset/2) + util.linlin(0, v_max, 0, math.pi * 2 - ARC_OVERSHOOT_COMP, v))
  end

  screen.move(round(x), round(y))
  screen.line(arc_end_x, arc_end_y)
  screen.fill()
end


-- ------------------------------------------------------------------------
-- screen - connectors

function paperface.banana(x, y, fill, level, color)
  screen.aa(1)

  if level == nil then level = SCREEN_LEVEL_BANANA end
  screen.level(level)

  if seamstress and color then
    screen.color(table.unpack(color))
  end

  local radius = math.floor((SCREEN_STAGE_W/2) - 1)
  if norns then
    screen.move(x + radius + 1, y)
    screen.circle(x + radius + 1, y + radius + 1, radius)
    if fill then
      screen.fill()
    else
      screen.stroke()
    end
  end

  if seamstress then
    radius = radius + 1
    screen.move(x+radius, y+radius)
    if fill then
      screen.circle_fill(radius)
    else
      screen.circle(radius)
    end
  end
end


-- ------------------------------------------------------------------------
-- screen - labels

function paperface.rect_label(x, y, l)
  screen.aa(0)

  if l == nil then l = SCREEN_LEVEL_LABEL end
  screen.level(l)

  -- if norns then
    screen.move(x, y)
    screen.line(x, y + SCREEN_STAGE_W)
    screen.stroke()
    screen.move(x + SCREEN_STAGE_W, y)
    screen.line(x + SCREEN_STAGE_W, y + SCREEN_STAGE_W)
    screen.stroke()
  -- end

  -- if seamstress then
    -- screen.move(x, y)
    -- screen.rect(SCREEN_STAGE_W, SCREEN_STAGE_W)
  -- end
end


-- REVIEW: maybe jus use a png, idk
function paperface.main_in_label(x, y, l)
  screen.aa(0)

  x = x - 2

  if l == nil then l = SCREEN_LEVEL_LABEL end
  -- screen.level(l)

  -- screen.move(x, y + SCREEN_STAGE_W/2)
  -- screen.line(x + SCREEN_STAGE_W / 2, y + SCREEN_STAGE_W)
  -- screen.stroke()
  -- screen.move(x + SCREEN_STAGE_W / 2, y + SCREEN_STAGE_W)
  -- screen.line(x + SCREEN_STAGE_W / 2, y)
  -- screen.stroke()
  -- screen.move(x + SCREEN_STAGE_W / 2, y)
  -- screen.line(x, y + SCREEN_STAGE_W/2)
  -- screen.stroke()

  if norns then
    screen.display_png(norns.state.path .. "img/main_input.png", x, y)
  end

  if seamstress then

    -- if TXTR_MAIN_IN == nil then
    --   TXTR_MAIN_IN = screen.new_texture_from_file(seamstress.state.path .. "/img/main_input.png")
    -- end

    -- TXTR_MAIN_IN:render(x, y, 1)

    screen.level(l)

    y = y - 1

    screen.move(x, y + SCREEN_STAGE_W / 2)
    screen.line(x + (SCREEN_STAGE_W / 2) - 1, y + 1)
    screen.move(x, y + SCREEN_STAGE_W / 2)
    screen.line(x + (SCREEN_STAGE_W / 2) - 1, y + SCREEN_STAGE_W - 2)

    x = x + (SCREEN_STAGE_W / 2)
    screen.move(x, y + 1)
    screen.line(x, y + SCREEN_STAGE_W - 2)

    x = x + 2
    screen.move(x, y + 1)
    screen.line(x, y + SCREEN_STAGE_W - 2)

    x = x + 1
    screen.move(x, y + 1)
    screen.line(x + (SCREEN_STAGE_W / 2) - 2, y + SCREEN_STAGE_W / 2)
    screen.move(x, y + SCREEN_STAGE_W - 2)
    screen.line(x + (SCREEN_STAGE_W / 2) - 2, y + SCREEN_STAGE_W / 2)

  end

end

-- panel graphic (square)
function paperface.trig_out_label(x, y, l)
  screen.aa(0)

  if l == nil then l = SCREEN_LEVEL_LABEL end
  screen.level(l)

  if norns then
    screen.rect(x, y, SCREEN_STAGE_W, SCREEN_STAGE_W)
    screen.stroke()
  end
  if seamstress then
    screen.move(x, y)
    screen.rect(SCREEN_STAGE_W+1, SCREEN_STAGE_W+1)
  end
end

-- panel graphic (triangle)
function paperface.trig_in_label(x, y, l, fill)
  screen.aa(0)

  x = x - 1

  if fill == nil then fill = false end

  if l == nil then
    if fill then
      l = SCREEN_LEVEL_LABEL_SPE
    else
      l = SCREEN_LEVEL_LABEL
    end
  end
  screen.level(l)

  if norns then
    if fill then
      screen.move(x, y)
      -- NB: needed the 0.5s to get clean triangle edge
      screen.line(x + SCREEN_STAGE_W / 2 + 0.5, y + SCREEN_STAGE_W / 2 + 0.5)
      screen.line(x + SCREEN_STAGE_W, y)
      screen.fill()
    else
      -- NB: for some reason looks better if doing a stroke in between
      screen.move(x, y)
      screen.line(x + SCREEN_STAGE_W / 2, y + SCREEN_STAGE_W / 2)
      screen.stroke()

      screen.move(x + SCREEN_STAGE_W / 2, y + SCREEN_STAGE_W / 2)
      screen.line(x + SCREEN_STAGE_W, y)
      screen.stroke()

      screen.move(x, y)
      screen.line(x + SCREEN_STAGE_W, y)
      screen.stroke()
    end
  elseif seamstress then
    x = x + 1
    local half_w = math.floor(SCREEN_STAGE_W / 2)
    screen.move(x, y)
    screen.line(x + half_w, y + SCREEN_STAGE_W / 2)

    screen.move(x + half_w, y + SCREEN_STAGE_W / 2)
    screen.line(x + SCREEN_STAGE_W - 1, y)

    screen.move(x, y)
    screen.line(x + SCREEN_STAGE_W - 1, y)
  end

end

function paperface.trig_in_label_filled(x, y, l)
  screen.aa(0)

  if l == nil then l = SCREEN_LEVEL_LABEL end
  screen.level(l)
end


-- ------------------------------------------------------------------------
-- screen - combined

function paperface.main_in(x, y, trig, tame)
  paperface.main_in_label(x, y)
  if trig then
    local level = (tame ~= nil and tame) and SCREEN_LEVEL_BANANA_TAMED or SCREEN_LEVEL_BANANA
    paperface.banana(x, y, trig, level, COLOR_BANANA_CV_IN)
  end
end

function paperface.trig_in(x, y, trig, filled, tame)
  paperface.trig_in_label(x, y, nil, filled)

  -- nana
  if trig then
    local level = (tame ~= nil and tame) and SCREEN_LEVEL_BANANA_TAMED or SCREEN_LEVEL_BANANA
    paperface.banana(x, y, trig, level, COLOR_BANANA_TRIG_IN)
  end
end

function paperface.out(x, y, trig, tame, out_type, label_level)
  if label_level == nil then label_level = SCREEN_LEVEL_LABEL end
  paperface.trig_out_label(x, y, label_level)

  local color
  if out_type == "TRIG" then
    color = COLOR_BANANA_TRIG_OUT
  elseif out_type == "CV" then
    color = COLOR_BANANA_CV_OUT
  end

  if trig then
    l = (tame ~= nil and tame) and SCREEN_LEVEL_BANANA_TAMED or SCREEN_LEVEL_BANANA
    paperface.banana(x, y, trig, l, color)
  end
end

function paperface.trig_out(x, y, trig, tame)
  paperface.out(x, y, trig, tame, "TRIG")
end

function paperface.trig_out_spe(x, y, trig, tame)
  paperface.out(x, y, trig, tame, "TRIG", SCREEN_LEVEL_LABEL_SPE)
end

function paperface.cv_out(x, y, trig, tame)
  paperface.out(x, y, trig, tame, "CV")
end

function paperface.cv_out_spe(x, y, trig, tame)
  paperface.out(x, y, trig, tame, "CV", SCREEN_LEVEL_LABEL_SPE)
end

function paperface.is_in_selected(i)
  return ((i.parent.STATE.grid_mode == M_LINK or i.parent.STATE.grid_mode == M_EDIT)
          and i.parent.STATE.selected_nana ~= nil
          and patching.is_in(i.parent.STATE.selected_nana.kind)
          and i.parent.STATE.selected_nana.id == i.id)
end

function paperface.is_out_selected(o)
  return ((o.parent.STATE.grid_mode == M_LINK or o.parent.STATE.grid_mode == M_EDIT)
          and o.parent.STATE.selected_nana ~= nil
          and patching.is_out(o.parent.STATE.selected_nana.kind)
          and o.parent.STATE.selected_nana.id == o.id)
end

function paperface.should_tame_in_redraw(i)
  return ((i.parent.STATE.grid_mode == M_LINK or i.parent.STATE.grid_mode == M_EDIT)
          and (i.parent.STATE.selected_nana == nil
               or not patching.is_in(i.parent.STATE.selected_nana.kind)
               or i.parent.STATE.selected_nana.id ~= i.id))
end

function paperface.should_tame_out_redraw(o)
  return ((o.parent.STATE.grid_mode == M_LINK or o.parent.STATE.grid_mode == M_EDIT)
          and (o.parent.STATE.selected_nana == nil
               or not patching.is_out(o.parent.STATE.selected_nana.kind)
               or o.parent.STATE.selected_nana.id ~= o.id))
end

function paperface.in_redraw(i)
  if i.x == nil or i.y == nil then
    return
  end

  local x = paperface.panel_grid_to_screen_x(i.x)
  local y = paperface.panel_grid_to_screen_y(i.y)
  local sclock_t = i.parent.STATE.superclk_t
  if i.kind == 'comparator' then
    local triggered = ( paperface.is_in_selected(i)
                        or ( (i.status == 1) or ( (sclock_t - i.last_up_t) < LINK_TRIG_DRAW_T) ) )
    local tame = paperface.should_tame_in_redraw(i)
    paperface.trig_in(x, y, triggered, false, tame)
  elseif i.kind == 'in' then
    local triggered = paperface.is_in_selected(i)
      or ( (sclock_t - i.last_changed_t) < LINK_TRIG_DRAW_T )
    local tame = paperface.should_tame_in_redraw(i)
    paperface.main_in(x, y, triggered, tame)
  end
end

function paperface.out_redraw(o)
  if o.x == nil or o.y == nil then
    return
  end

  local x = paperface.panel_grid_to_screen_x(o.x)
  local y = paperface.panel_grid_to_screen_y(o.y)
  local sclock_t = o.parent.STATE.superclk_t
  local triggered = ( paperface.is_out_selected(o)
                      or ( (sclock_t - o.last_changed_t) < LINK_TRIG_DRAW_T ) )
  local tame = paperface.should_tame_out_redraw(o)
  if o.kind == 'out' then
    paperface.trig_out(x, y, triggered, tame)
  elseif o.kind == 'cv_out' then
    paperface.cv_out(x, y, triggered, tame)
  end
end

function paperface.module_redraw(m)
  if m.ins ~= nil then
    for _, i_label in ipairs(m.ins) do
      local i = m.STATE.ins[i_label]
      if i ~= nil then
        paperface.in_redraw(i)
      end
    end
  end

  if m.outs ~= nil then
    for _, o_label in pairs(m.outs) do
      local o = m.STATE.outs[o_label]
      if o ~= nil then
        paperface.out_redraw(o)
      end
    end
  end
end


-- ------------------------------------------------------------------------
-- patch

function paperface.draw_link(ix, iy, i_page, ox, oy, o_page, curr_page, draw_mode)
  local startx = paperface.panel_grid_to_screen_x(ox) + SCREEN_STAGE_W/2 -- + (curr_page - o_page) * SCREEN_W
  local starty = paperface.panel_grid_to_screen_y(oy) + SCREEN_STAGE_W/2 + (o_page - curr_page) * SCREEN_H
  local endx = paperface.panel_grid_to_screen_x(ix) + SCREEN_STAGE_W/2 -- + (curr_page - i_page) * SCREEN_W
  local endy = paperface.panel_grid_to_screen_y(iy) + SCREEN_STAGE_W/2 + (i_page - curr_page) * SCREEN_H
  local midx = (endx + startx)/2
  local midy = (endy + starty)/2

  local level = SCREEN_LEVEL_LINK
  local lw = SCREEN_LW_LINK
  local col = COLOR_LINK
  if draw_mode == DRAW_M_TAME then
    level = SCREEN_LEVEL_LINK_TAMED
    col = COLOR_LINK_TAMED
  elseif draw_mode == DRAW_M_FOCUS then
    lw = SCREEN_LW_LINK_FOCUSED
    col = COLOR_LINK_FOCUSED
  elseif draw_mode == DRAW_M_VALID then
    col = COLOR_VALID
  elseif draw_mode == DRAW_M_INVALID then
    col = COLOR_INVALID
  elseif draw_mode == DRAW_M_DELETE then
    col = COLOR_DELETE
  end

  if norns then
    screen.line_width(lw)
    screen.level(level)
  end

  if seamstress then
    screen.color(table.unpack(col))
  end

  screen.move(startx, starty)
  screen.curve(midx, starty, midx, endy, endx, endy)
  screen.stroke()

  screen.line_width(1)
end

function paperface.redraw_link(o, i, curr_page, draw_mode)
    if (o.x == nil or o.y == nil) or (i.x == nil or i.y == nil) then
      return
    end

    paperface.draw_link(o.x, o.y, o.parent.page,
                        i.x, i.y, i.parent.page,
                        curr_page,
                        draw_mode)
end

function paperface.draw_input_links(outs, i, curr_page, draw_mode)
  for from_out_label, _v in pairs(i.incoming_vals) do
    local from_out = outs[from_out_label]

    -- OUT not known or wo/ visual representation
    if not from_out or (from_out.x == nil or from_out.y == nil) then
      goto DRAW_NEXT_IN_LINK
    end

    paperface.redraw_link(from_out, i, curr_page, draw_mode)

    ::DRAW_NEXT_IN_LINK::
  end
end

function paperface.draw_output_links(ins, links, o, curr_page, draw_mode)
  local to_in_labels = links[o.id]

  if to_in_labels == nil then
    return
  end

  for _, to_label in pairs(to_in_labels) do
    local to = ins[to_label]

    -- OUT not known or wo/ visual representation
    if not to or (to.x == nil or to.y == nil) then
      goto DRAW_NEXT_OUT_LINK
    end

    paperface.redraw_link(o, to, curr_page, draw_mode)

    ::DRAW_NEXT_OUT_LINK::
  end
end

function paperface.redraw_nana_links(outs, ins, links, nana, curr_page, draw_mode)
  if patching.is_in(nana) then
    paperface.draw_input_links(outs, nana, curr_page, draw_mode)
  else
    paperface.draw_output_links(ins, links, nana, curr_page, draw_mode)
  end
end

-- UNUSED ?!
-- function paperface.redraw_to_inputs_links(outs, to_ins, curr_page, draw_mode)
--   if ins == nil then
--     return
--   end

--   for _, i in pairs(ins) do
--     if i.x == nil or i.y == nil then
--       goto NEXT_IN_LINK
--     end

--     paperface.draw_input_links(outs, i, curr_page, draw_mode)

--     ::NEXT_IN_LINK::
--   end
-- end

function paperface.redraw_active_links(outs, ins, curr_page, draw_mode)
  for _, i in pairs(ins) do
    if i.x == nil or i.y == nil then
      goto NEXT_IN_ACTIVE_LINK
    end

    local sclock_t = i.parent.STATE.superclk_t
    if i.kind == 'comparator' then
      local triggered = ( i.status == 1
                          or ( (sclock_t - i.last_up_t) < LINK_TRIG_DRAW_T ) )
      if triggered then
        paperface.draw_input_links(outs, i, curr_page, draw_mode)
      end
    elseif i.kind == 'in' then
      local triggered = ( (sclock_t - i.last_changed_t) < LINK_TRIG_DRAW_T )
      if triggered then
        paperface.draw_input_links(outs, i, curr_page, draw_mode)
      end
    end
    ::NEXT_IN_ACTIVE_LINK::
  end
end

-- ------------------------------------------------------------------------

return paperface

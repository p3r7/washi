
clock.get_beat_sec = function()
  return 60.0 / clock.get_tempo()
end

function screen.aa(...)
  --
end

function screen.line_width(...)
end

function screen.level(l)
  -- NB: taking into account norns' non-linear level gradient
  local g = util.explin(1, 16, 1, 255, l+1) - 1
  screen.color(g, g, g)
end

function screen.stroke()
end

function screen.fill()
end

function screen.update()
  screen.refresh()
end

function screen.curve(x1, y1, x2, y2, x3, y3)
  _seamstress.screen_curve_to(x1, y1, x2, y2, x3, y3)
end

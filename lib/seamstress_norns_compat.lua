
clock.get_beat_sec = clock.get_sec_per_beat

function screen.aa(...)
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

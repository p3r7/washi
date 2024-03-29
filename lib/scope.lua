-- washi. scope
--
-- an oscilloscope
--
-- REVIEW: maybe use the `graph` lib?


local Scope = {}
Scope.__index = Scope


-- ------------------------------------------------------------------------
-- deps

local fifo = include("washi/lib/fifo")


-- ------------------------------------------------------------------------
-- constructors

function Scope.new(id, STATE)
  local p = setmetatable({}, Scope)

  p.id = id

  -- --------------------------------

  p.STATE = STATE

  -- --------------------------------

  p.nana = nil
  p.buffer = fifo():setempty(function() return nil end)
  p.buffer_len = 50

  -- --------------------------------

  p.clock = clock.run(function()
      p:clock()
  end)

  return p
end

function Scope:cleanup()
  clock.cancel(self.clock)
end


-- ------------------------------------------------------------------------
-- internal logic

function Scope:clear()
  self.nana = nil
  local nb_samples = self.buffer:length()
  for i=1,nb_samples do
    self.buffer:pop()
  end
end

function Scope:assoc(b)
  self:clear()
  self.nana = b
end

function Scope:is_on()
  return (self.nana ~= nil)
end

function Scope:clock()
  local step_s = 1 / FPS
  while true do
    clock.sleep(step_s)
    self:sample()
  end
end

function Scope:sample_raw(v)
  self.buffer:push(v)
  if self.buffer:length() > self.buffer_len then
    self.buffer:pop()
  end
end

function Scope:sample()
  if self.nana ~= nil then
    self:sample_raw(self.nana.v)
  end
end

-- ------------------------------------------------------------------------
-- screen

function Scope:redraw(x, y, w, h)
  local nb_samples = self.buffer:length()
  local nb_vals_to_show = math.min(nb_samples, w)

  screen.aa(0)

  screen.level(0)
  if norns then
    screen.rect(x, y, w, h)
    screen.fill()
  elseif seamstress then
    screen.move(x, y)
    screen.rect_fill(w, h)
  end
  screen.level(5)
  if norns then
    screen.rect(x, y, w, h)
    screen.stroke()
  elseif seamstress then
    screen.move(x, y)
    screen.rect(w, h)
  end

  screen.level(12)
  local prev_pixel_v = 0
  for i=1,nb_vals_to_show do
    local v = self.buffer:peek(i)
    local pixel_v = util.linlin(0, V_MAX, 0, h-2, v)
    local new_x = x+w-i
    local new_y = y+h-2-pixel_v
    if math.abs(prev_pixel_v-pixel_v) > 2
      and ((seamstress == nil) or i > 1)then
      screen.line(new_x, new_y)
    else
      screen.pixel(new_x, new_y)
    end
    if seamstress then
      screen.move(new_x, new_y)
    end
  end
  screen.stroke()
end


-- ------------------------------------------------------------------------

return Scope

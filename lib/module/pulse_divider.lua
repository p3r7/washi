-- haleseq. module/pulse divider
--
-- CGS pulse divider

local paperface = include("haleseq/lib/paperface")
include("haleseq/lib/consts")


-- ------------------------------------------------------------------------

local pulse_divider = {}


-- ------------------------------------------------------------------------
-- conf

local CGS_PULSE_DIVS = {2, 3, 4, 5, 6, 7, 8}


-- ------------------------------------------------------------------------
-- screen

function pulse_divider.redraw(x, y, acum)
  for _, v in ipairs(CGS_PULSE_DIVS) do
    if v ~= 'off' then
      local trig = acum % (MCLOCK_DIVS / v) == 0
      paperface.trig_out(x, y, trig)
      screen.move(x + SCREEN_STAGE_W + 2, y + SCREEN_STAGE_W - 2)
      screen.text("/"..v)
      y = y + SCREEN_STAGE_W
    end
  end
end


-- ------------------------------------------------------------------------

return pulse_divider

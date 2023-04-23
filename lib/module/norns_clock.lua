-- haleseq. module/norns clock

local paperface = include("haleseq/lib/paperface")
include("haleseq/lib/consts")


-- ------------------------------------------------------------------------

local norns_clock = {}


-- ------------------------------------------------------------------------
-- screen

function norns_clock.redraw(x, y, acum)
    -- local trig = (math.abs(os.clock() - last_mclock_tick_t) < PULSE_T)
  local trig = acum % (MCLOCK_DIVS / 4) == 0
  paperface.trig_out(x, y, trig)
  screen.move(x + SCREEN_STAGE_W + 2, y + SCREEN_STAGE_W - 2)
  screen.text(params:get("clock_tempo") .. " BPM ")
end

-- ------------------------------------------------------------------------

return norns_clock

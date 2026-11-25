-- Shows the niri-tile mode; click toggles it.
-- The command path is substituted by Nix.
local cmd = "@niriTile@"
local started = false

local function show(mode)
  if mode == "scroll" then
    barWidget.setGlyph("arrows-horizontal")
    barWidget.setText("Scroll")
    barWidget.setTooltip("Scrolling layout (Super+T: tiling)")
  else
    barWidget.setGlyph("layout-sidebar")
    barWidget.setText("Tile")
    barWidget.setTooltip("Tiling layout (Super+A: scrolling)")
  end
end

function update()
  if started then return end
  started = true
  show("tile")
  noctalia.runStream(cmd .. " watch", function(line)
    show(line:match("%a+"))
  end)
end

function onClick()
  noctalia.runAsync({ cmd, "toggle" })
end

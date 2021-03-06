-- vim: nu et ts=8 sts=2 sw=2

local module = {}

local clr = require("color")
local coords = require("coords")
local PxPos, CxPos, PxSize, CxSize =
  coords.PxPos, coords.CxPos, coords.PxSize, coords.CxSize
local mapgen = require("mapgen")

local MAP_SIZE = CxSize(20, 20)
local MAP_DISPLAY_EXTRA_CELLS = 2
local DEFAULT_MAP_SEED = 55

local TILES = {
  { id=1, c=clr.BLUE, pass=false, fs="water" },
  { id=2, c=clr.LBLUE, pass=true, fs="water" },
  { id=3, c=clr.GREEN, pass=true, fs="dirt" },
  { id=4, c=clr.YELLOW, pass=true, fs="dirt" },
}

local playerSprite = nil

function printf(fmt, ...)
  local message = string.format(fmt, ...)
  print(message)
end

function module.loadMap(randomMapSeed)
  local map = addMethods({})
  map.tiles = TILES
  local seed = randomMapSeed or DEFAULT_MAP_SEED
  print("Map seed: "..seed)
  map.size = MAP_SIZE
  map.tileSize = PxSize(40, 40)
  printf("TileSize: %d x %d", map.tileSize.unpack())
  buildTileGrid(map)
  buildDisplayGrid(map)
  map.cells = mapgen.buildRandomMap(seed, map.tiles, map.size)
  playerSprite = buildPlayerSprite(map)
  return map
end

function addMethods(map)
  map.getTileSize = getTileSize
  map.cellAt = getCellAtRowCol
  map.cellAtXY = getCellAtMapPixel
  map.update = updateDisplayGrid
  map.draw = drawMap
  return map
end

function buildPlayerSprite(map)
  local playerSizePct = 0.6
  local playerSize = map.tileSize.scale(playerSizePct)
  local offset = map.tileSize.sub(playerSize).scale(.5)
  local cvs = love.graphics.newCanvas(map.tileSize.unpack())
  cvs:renderTo(function()
    love.graphics.setColor(clr.LGREEN)    
    module._rect("fill", offset, playerSize)
  end)
  --local img = cvs:newImageData()
  --if cvs.release then cvs:release() end
  --return img
  return cvs
end

function module._rect(mode, pos, size)
  local x, y = pos.unpack()
  local w, h = size.unpack()
  --love.graphics.polygon(mode, x, y, x+w, y, x+w, y+h, x, y+h)
  love.graphics.rectangle(mode, x, y, w, h)
end

function getTileSize(map)
  return map.tileSize
end

function getCellAtRowCol(map, row, col)
  assert(map)
  assert(row)
  assert(col)
  assert(map.cells)
  local cell = map.cells[row] and map.cells[row][col]
  --printf("CellAt (%d,%d): %d", row, col, (cell and cell.t.id) or 0)
  return cell
end

function getCellAtMapPixel(map, x, y)
  assert(map)
  assert(x)
  assert(y)
  local row, col = PxPos(x, y).toCx(map.tileSize).unpack()
  printf("CellAt: (%d,%d)", row, col)
  if row < 1 or col < 1 then return nil end
  return getCellAtRowCol(map, row, col)
end

function buildTileGrid(map)
  local tileCount = table.getn(map.tiles)
  local tileGridW = math.ceil(math.sqrt(tileCount))
  local tileGridH = math.ceil(tileCount / tileGridW)
  local canvasSize = nextPowerOf2(
    math.max(tileGridW * map.tileSize.pxW, tileGridH * map.tileSize.pxH))
  print("Tile grid size: "..canvasSize)
  local cvs = love.graphics.newCanvas(canvasSize, canvasSize)
  cvs:renderTo(function()
    local tileIndex = 0
    for r = 1, tileGridH do
      for c = 1, tileGridW do
        tileIndex = tileIndex + 1
        tile = map.tiles[tileIndex]
        local x = (c-1) * map.tileSize.pxW
        local y = (r-1) * map.tileSize.pxH
        tile.quad = love.graphics.newQuad(x, y,
          map.tileSize.pxW, map.tileSize.pxH, canvasSize, canvasSize)
        love.graphics.setColor(tile.c)
        love.graphics.rectangle("fill", x, y, map.tileSize.unpack())
      end
    end
  end)
  map.tilesetImage = love.graphics.newImage(cvs:newImageData())
end

function buildDisplayGrid(map)
  map.display = {}
  local shortDimension = math.min(love.graphics.getDimensions())
  local mapDisplaySize = PxSize(shortDimension, shortDimension)
  local minScreenSizeCx = mapDisplaySize.toCx(map.tileSize)
  local padding = 2 * MAP_DISPLAY_EXTRA_CELLS
  local paddedScreenSizeCx = minScreenSizeCx.add(CxSize(padding, padding))
  local paddedScreenCellCount = paddedScreenSizeCx.cxW * paddedScreenSizeCx.cxH
  map.display.sizeCx = paddedScreenSizeCx
  local paddedScreenSizePx = paddedScreenSizeCx.toPx(map.tileSize)
  printf("Map display buffer size: %d x %d cells", paddedScreenSizeCx.unpack())
  printf("Map display buffer size: %d x %d px", paddedScreenSizePx.unpack())
  map.display.canvas = love.graphics.newCanvas(paddedScreenSizePx.unpack())
  map.display.spriteBatch =
    love.graphics.newSpriteBatch(map.tilesetImage, paddedScreenCellCount)
  map.display.view = { r=nil, c=nil }
end

function updateDisplayGrid(map, viewport, playerMapOffsetPx)
  assert(map)
  assert(viewport)
  --printf("VP map offset: XY=%d,%d", viewport.mapOffset.unpack())
  if updateDgViewAndDetectChange(map, viewport, playerMapOffsetPx) then
    --print("UPDATE.")
    --pldump({ vp = viewport, dv = map.display.view })
    local dv = map.display.view
    printf("UPDATE: VP.MO=(%d, %d), DV=(r=%d, c=%d, x=%d, y=%d)",
      viewport.mapOffset.x, viewport.mapOffset.y,
      dv.r, dv.c, dv.x, dv.y)
    updateDisplaySpriteBatch(map, viewport)
  end
end

function updateDgViewAndDetectChange(map, viewport, playerMapOffsetPx)
  assert(map)
  assert(viewport)
  assert(playerMapOffsetPx)
  -- TODO: Redraw only when view extends past drawn area.
  local rc = viewport.mapOffset.toCx(map.tileSize).sub(CxSize(1, 1))
  local r, c = rc.unpack()
  -- Converting back to pixels, we get the position rounded
  -- down to a cell boundary. Subtracting viewport.mapOffset,
  -- we get the difference between the raw and rounded offset.
  local xy = rc.toPx(map.tileSize).sub(viewport.mapOffset)
  --pldump({ vpRC=rc, xy=xy })
  local oldView = map.display.view
  map.display.view = { r=r, c=c, y=xy.y, x=xy.x }
  --printf("OLD: RC=%d,%d; NEW: RC=%d,%d", oldView.r or -99, oldView.c or -99, r, c)
  map.display.playerScreenPos = playerMapOffsetPx
    .sub(viewport.mapOffset)
    .add(viewport.screenOffset)
  return not (r == oldView.r and c == oldView.c)
end

function updateDisplaySpriteBatch(map, viewport)
  print("updateDisplaySpriteBatch")
  local displaySizeCx = viewport.displaySize.toCxCeil(map.tileSize)
    .add(CxSize(1,1)) -- XXX
  local sb = map.display.spriteBatch
  local dv = map.display.view
  sb:clear()
  local y = dv.y
  --pldump({ dv=dv, displaySizeCx=displaySizeCx })
  for r = dv.r, dv.r + displaySizeCx.cxH do
    local x = dv.x
    for c = dv.c, dv.c + displaySizeCx.cxW do
      local cell = map:cellAt(r, c)
      if cell then
        sb:add(cell.t.quad, x, y)
        if r==2 and c==2 then
          printf("Cell: %d at (%f, %f) (r=%d,c=%d)", cell.t.id, x, y, r, c)
        end
      else
        --printf("Cell: NIL at (%f,%f) (r=%d,c=%d)", x, y, r, c)
      end
      x = x + map.tileSize.pxW
    end
    y = y + map.tileSize.pxH
  end
  sb:flush()
  map.display.canvas:renderTo(function()
    love.graphics.clear()
    love.graphics.draw(map.display.spriteBatch)
  end)
  map.display.image = map.display.canvas:newImageData()
  --printf("Cells: %d x %d", #(map.cells), #(map.cells[1]))
end

function drawMap(map, viewport, playerMapOffsetPx)
  assert(map)
  assert(viewport)
  assert(viewport.screenOffset.t == "PxPos")
  assert(viewport.displaySize.t == "PxSize")
  assert(viewport.mapOffset.t == "PxPos")
  updateDisplayGrid(map, viewport, playerMapOffsetPx)
  local dv = map.display.view
  --pldump({viewport.screenOffset.unpack()})
  --pldump(dv)
  local x, y = viewport.screenOffset.unpack()
  local w, h = viewport.displaySize.unpack()
  love.graphics.setScissor(x, y, w, h)
  love.graphics.draw(map.display.canvas, viewport.screenOffset.unpack())
  love.graphics.draw(playerSprite, map.display.playerScreenPos.unpack())
  love.graphics.setScissor()
end

function nextPowerOf2(n)
  local p = 2
  while p < n do
    p = p * 2
  end
  return p
end

return module


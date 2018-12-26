-- vim: et ts=8 sts=2 sw=2

local module = {}

local clr = require("color")

local MAP_SIZE = { cxW=20, cxH=20 }
local MAP_DISPLAY_EXTRA_CELLS = 2

local TILES = {
  { id=1, c=clr.BLUE, pass=false },
  { id=2, c=clr.LBLUE, pass=true },
  { id=3, c=clr.GREEN, pass=true },
  { id=4, c=clr.YELLOW, pass=true },
}

function printf(fmt, ...)
  local message = string.format(fmt, ...)
  print(message)
end

function module.loadMap()
  local map = addMethods({})
  map.tiles = TILES
  seed = os.time()
  print("Map seed: "..seed)
  math.randomseed(seed)
  map.size = MAP_SIZE
  map.tileSize = { pxW=40, pxH=40 }
  buildTileGrid(map)
  buildDisplayGrid(map)
  buildRandomMap(map)
  return map
end

function addMethods(map)
  map.getTileSize = getTileSize
  map.cellAt = getCellAtRowCol
  map.cellAtXY = getCellAtXY
  map.update = updateDisplayGrid
  map.draw = drawMap
  return map
end

function getTileSize(map)
  return map.tileSize.pxW, map.tileSize.pxH
end

function getCellAtRowCol(map, row, col)
  assert(map)
  assert(row)
  assert(col)
  assert(map.cells)
  local cell = map.cells[row] and map.cells[row][col]
  printf("CellAt (%d,%d): %d", row, col, (cell and cell.t.id) or 0)
  return cell
end

function getCellAtXY(map, x, y)
  assert(map)
  assert(x)
  assert(y)
  local r = math.floor(x / map.tileSize.pxW)
  local c = math.floor(y / map.tileSize.pxH)
  if r < 1 or c < 1 then return nil end
  return getCellAtRowCol(map, r, c)
end

function drawMap(map, viewport)
  assert(map)
  assert(viewport)
  updateDisplayGrid(map, viewport)
  --pldump(map.display)
  local dv = map.display.view
  love.graphics.draw(map.display.spriteBatch,
    0, 0, 0, 1, 1, -- defaults
    -dv.x, -dv.y)
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
        love.graphics.rectangle("fill", x, y,
          x + map.tileSize.pxW, y + map.tileSize.pxH)
      end
    end
  end)
  map.tilesetImage = love.graphics.newImage(cvs:newImageData())
end

function buildDisplayGrid(map)
  map.display = {}
  local screenW, screenH = love.graphics.getDimensions()
  local minWCells = math.ceil(screenW / map.tileSize.pxW)
  local minHCells = math.ceil(screenH / map.tileSize.pxH)
  local wCells = minWCells + 2 * MAP_DISPLAY_EXTRA_CELLS
  local hCells = minHCells + 2 * MAP_DISPLAY_EXTRA_CELLS
  --map.display.sizeCells = { cxW=wCells, cxH=hCells }
  --local wPx = map.tileSize.pxW * wCells
  --local hPx = map.tileSize.pxH * hCells
  --map.display.canvas = love.graphics.newCanvas(wPx, hPx)
  map.display.spriteBatch =
    love.graphics.newSpriteBatch(map.tilesetImage, wCells * hCells)
  map.display.view = { r=nil, c=nil }
end

function buildRandomMap(map)
  map.cells = {}
  for r = 1, map.size.cxH do
    map.cells[r] = {}
    for c = 1, map.size.cxW do
      local cell = {}
      if r == 1 or r == map.size.cxH or c == 1 or c == map.size.cxW then
        cell.t = map.tiles[1]
      else
        local i = math.random(2, table.getn(map.tiles))
        cell.t = map.tiles[i]
      end
      map.cells[r][c] = cell
    end
  end
end

function updateDisplayGrid(map, viewport)
  assert(map)
  assert(viewport)
  if not updateDgViewAndDetectChange(map, viewport) then
    return
  end
  pldump({ vp = viewport, dv = map.display.view })
  updateDisplaySpriteBatch(map, viewport)
end

function updateDgViewAndDetectChange(map, viewport)
  local r = -1 + math.floor(viewport.mapY / map.tileSize.pxH)
  local c = -1 + math.floor(viewport.mapX / map.tileSize.pxW)
  local y = r * map.tileSize.pxH - viewport.mapY
  local x = c * map.tileSize.pxW - viewport.mapX
  local oldDgView = map.display.view
  map.display.view = { r=r, c=c, y=y, x=x }
  return not (r == oldDgView.r and c == oldDgView.c)
end

function updateDisplaySpriteBatch(map, viewport)
  print("updateDisplaySpriteBatch")
  local displayH = math.ceil(viewport.pxH / map.tileSize.pxH + 1)
  local displayW = math.ceil(viewport.pxW / map.tileSize.pxW + 1)
  local sb = map.display.spriteBatch
  local dv = map.display.view
  sb:clear()
  local y = dv.y
  pldump({ dv=dv, displayWH={w=displayW,h=displayH}})
  for r = dv.r, dv.r + displayH - 1 do
    local x = dv.x
    for c = dv.c, dv.c + displayW - 1 do
      local cell = map:cellAt(r, c)
      if cell then
        sb:add(cell.t.quad, x, y)
        printf("Cell: %d at (%f, %f) (r=%d,c=%d)", cell.t.id, x, y, r, c)
      else
        printf("Cell: NIL at (%f,%f) (r=%d,c=%d)", x, y, r, c)
      end
      x = x + map.tileSize.pxW
    end
    y = y + map.tileSize.pxH
  end
  sb:flush()
  printf("Cells: %d x %d", #(map.cells), #(map.cells[1]))
  --pldump(map.cells)
  pldump(map.cells[1][1])
  pldump(map.cells[8][8])
end

function nextPowerOf2(n)
  local p = 2
  while p < n do
    p = p * 2
  end
  return p
end

return module


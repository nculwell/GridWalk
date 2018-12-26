-- vim: nu et ts=2 sts=2 sw=2

local dbg = require("dbg")
local clr = require("color")
local pl = {}
pl.pretty = require("pl.pretty")

local MAP_SIZE = { w=20, h=20 }
local MAP_DISPLAY_EXTRA_CELLS = 2
local mapH = 20
local TICKS_PER_SECOND = 10
local SECS_PER_TICK = 1/TICKS_PER_SECOND
local MOVES_PER_TILE = 5
local START_POS = {x=1,y=1}
local VSYNC = false
local FULLSCREENTYPE = "desktop"
-- local FULLSCREENTYPE = "exclusive"

local glo = {
  fullscreen=true,
  paused=false,
  quitting=false,
  player = {
    mov = { prv=START_POS, nxt=START_POS, dst=START_POS }
  },
  moveKeys = {}
}

local function dump(z)
  print("{")
  for x in pairs(z) do
    print(x .. ": " .. tostring(z[x]))
  end
  print("}")
end

function love.load()
  print()
  toggleFullscreen()
  love.window.setTitle("Wandrix")
  glo.startTime = love.timer.getTime()
  glo.nextTickTime = 0
  dbg.init("gridwalk.log")
  glo.map = loadMap()
end

function love.keypressed(key)
  if key == "q" then
    dbg.print("QUITTING")
    love.event.quit()
  elseif key == "space" then
    paused = not paused
  elseif key == "f" then
    toggleFullscreen()
  elseif key == "up" or key == "down" or key == "left" or key == "right" then
    glo.moveKeys[key] = true
  end
end

function toggleFullscreen()
  glo.fullscreen = not glo.fullscreen
  local screenW, screenH, flags = love.window.getMode()
  local newFlags = {
    fullscreen = glo.fullscreen, fullscreentype = FULLSCREENTYPE, vsync = VSYNC, display = flags.display, }
  dump(newFlags)
  print(screenW.."x"..screenH)
  love.window.setMode(screenW, screenH, newFlags)
end

function moveChar(c, phase)
  isCharMoved = moveCharAdvanceTick(c)
  if isCharMoved then
    c.mov.phase = {
      x = c.mov.prv.x + phase * (c.mov.nxt.x - c.mov.prv.x),
      y = c.mov.prv.y + phase * (c.mov.nxt.y - c.mov.prv.y),
    }
  else
    c.mov.phase = c.mov.dst
  end
  return isCharMoved
end

function moveCharAdvanceTick(c)
  local m = c.mov
  --pl.pretty.dump(m)
  if m.dst.ticks and m.dst.ticks > 0 then
    m.prv = m.nxt
    m.nxt.x = m.prv.x + (m.dst.x - m.prv.x) / m.dst.ticks
    m.nxt.y = m.prv.y + (m.dst.y - m.prv.y) / m.dst.ticks
    m.dst.ticks = m.dst.ticks - 1
    if m.dst.ticks == 0 then
      dbg.print(string.format("MOVE COMPLETE: %f,%f", m.dst.x, m.dst.y))
      return false
    end
    return true
  else
    return false
  end
end

function computeMovDst(c, moveCmd, ticks)
  -- XXX: Scale movement here if needed.
  local x = c.mov.dst.x + moveCmd.x
  local y = c.mov.dst.y + moveCmd.y
  --pl.pretty.dump({x,y})
  --pl.pretty.dump(glo.map.tiles[y+1])
  local t = glo.map.tiles
  if not (t[y+1] and t[y+1][x+1] and not t[y+1][x+1].pass) then
    print("SKIP")
    --pl.pretty.dump(t[y+1][x+1])
    return false
  end
  return {x=x, y=y, ticks=ticks}
end

function love.update(dt)
  if paused then return end
  local time = love.timer.getTime() - glo.startTime
  local phase = 1 - ((glo.nextTickTime - time) / SECS_PER_TICK)
  --dbg.print(string.format("%f", time))
  local p = glo.player
  -- logic loop
  while glo.nextTickTime < time do
    dbg.print(string.format("TICK: %f", glo.nextTickTime))
    glo.nextTickTime = glo.nextTickTime + SECS_PER_TICK
    -- Apply previous move
    local playerMoving = moveChar(glo.player, phase)
    -- Handle next move
    if not playerMoving then
      moveCmd = scanMoveKeys()
      if moveCmd then
        --pl.pretty.dump(moveCmd)
        dst = computeMovDst(glo.player, moveCmd, MOVES_PER_TILE)
        if dst then
          --print("dst")
          --pl.pretty.dump(dst)
          --pl.pretty.dump(glo.player)
          p.mov.dst = dst
          --pl.pretty.dump(glo.player)
        end
      end
    end
  end
end

function scanMoveKeys()
  local move = {x=0, y=0}
  local m = glo.moveKeys
  glo.moveKeys = {}
  if love.keyboard.isDown("left") or m["left"] then move.x = move.x - 1 end
  if love.keyboard.isDown("right") or m["right"] then move.x = move.x + 1 end
  if love.keyboard.isDown("up") or m["up"] then move.y = move.y - 1 end
  if love.keyboard.isDown("down") or m["down"] then move.y = move.y + 1 end
  --move.x = move.x / MOVES_PER_TILE
  --move.y = move.y / MOVES_PER_TILE
  if move.x == 0 and move.y == 0 then return nil end
  return move
end

-----------------------------------------------------------
-- DRAW

function love.draw()
  -- Calculations
  local screenSizeX = love.graphics.getWidth()
  local screenSizeY = love.graphics.getHeight()
  local centerX = math.floor(screenSizeX/2)
  local centerY = math.floor(screenSizeY/2)
  local p = glo.player
  local tileW = assert(glo.map.tileSize.w)
  local tileH = assert(glo.map.tileSize.h)
  local pos = { x = p.mov.phase.x * tileW, y = p.mov.phase.y * tileH }
  -- Background
  love.graphics.setColor(clr.GREEN)
  rect("fill", 0, 0, screenSizeX, screenSizeY)
  love.graphics.setColor(clr.WHITE)
  love.graphics.draw(glo.map.image, centerX-pos.x, centerY-pos.y)
  -- Player
  love.graphics.setColor(clr.LGREEN)
  --dbg.printf("DRAW: %f,%f", pos.x, pos.y)
  local playerSize = (MOVES_PER_TILE-2)/MOVES_PER_TILE
  rect("fill", centerX, centerY, math.floor(playerSize*tileW), math.floor(playerSize*tileH))
end

function rect(mode, x, y, w, h)
  love.graphics.polygon(mode, x, y, x+w, y, x+w, y+h, x, y+h)
end

-----------------------------------------------------------
-- MAP

function loadMap()
  local map = {}
  map.tiles = {
    { c=clr.BLUE, pass=false },
    { c=clr.LBLUE, pass=true },
    { c=clr.GREEN, pass=true },
    { c=clr.YELLOW, pass=true },
  }
  seed = os.time()
  print("Map seed: "..seed)
  math.randomseed(seed)
  map.size = MAP_SIZE
  map.tileSize = { w=40, h=40 }
  addMapMethods(map)
  buildTileGrid(map)
  buildDisplayGrid(map)
  buildRandomMap(map)
  return map
end

function addMapMethods(map)
  function map:cellAt(r, c)
    return map.cells[r] and map.cells[r][c] and map.cells[r, c]
  end
  function map:update(viewport)
    updateDisplayGrid(map, viewport)
  end
end

function buildTileGrid(map)
  local tileCount = table.getn(map.tiles)
  local tileGridW = math.ceil(math.sqrt(tileCount))
  local tileGridH = math.ceil(tileCount / tileGridW)
  local canvasSize = nextPowerOf2(
    math.max(tileGridW * map.tileSize.w, tileGridH * map.tileSize.h))
  print("Tile grid size: "..canvasSize)
  local cvs = love.graphics.newCanvas(canvasSize, canvasSize)
  cvs:renderTo(function()
    local tileIndex = 0
    for r = 1, tileGridH do
      for c = 1, tileGridW do
        tileIndex = tileIndex + 1
        tile = map.tiles[tileIndex]
        local x = (c-1) * map.tileSize.w
        local y = (r-1) * map.tileSize.h
        tile.quad = love.graphics.newQuad(x, y, map.tileSize.w, map.tileSize.h, canvasSize, canvasSize)
        love.graphics.setColor(tile.c)
        love.graphics.rectangle("fill", x, y, x + map.tileSize.w, y + map.tileSize.h)
      end
    end
  end)
  map.tilesetImage = love.graphics.newImage(cvs:newImageData())
end

function buildDisplayGrid(map)
  map.displayGrid = {}
  local screenW, screenH = love.window.getDimensions()
  local minWCells = math.ceil(screenW / map.tileSize.w)
  local minHCells = math.ceil(screenH / map.tileSize.h)
  local wCells = minWCells + 2 * MAP_DISPLAY_EXTRA_CELLS
  local hCells = minHCells + 2 * MAP_DISPLAY_EXTRA_CELLS
  map.displayGrid.sizeCells = { w=wCells, h=hCells }
  --local wPx = map.tileSize.w * wCells
  --local hPx = map.tileSize.h * hCells
  --map.displayGrid.canvas = love.graphics.newCanvas(wPx, hPx)
  map.displayGrid.spriteBatch = love.graphics.newSpriteBatch(map.tilesetImage, wCells * hCells)
  map.displayGrid.view = { r=1-MAP_DISPLAY_EXTRA_CELLS, c=1-MAP_DISPLAY_EXTRA_CELLS }
end

function buildRandomMap(map)
  map.cells = {}
  for r = 1, map.size.h do
    map.cells[r] = {}
    for c = 1, map.size.w do
      local cell = {}
      if r == 1 or r == map.size.h or c == 1 or c == map.size.w then
        cell.t = cells[1]
      else
        local i = math.random(2, table.getn(tiles))
        cell.t = tiles[i]
      end
      map.cells[r][c] = cell
    end
  end
end

function updateDisplayGrid(map, viewport)
  local sb = map.displayGrid.spriteBatch
  -- Check if we need to update yet.
  local vpCells = {
    r = math.floor(viewport.y / map.tileSize.h),
    c = math.floor(viewport.x / map.tileSize.w) }
  if map.displayGrid.view.r == vpCells.r and map.displayGrid.view.c == vpCells.c then
    return -- display hasn't moved, no need to update
  else
    map.displayGrid.view = vpCells
  end
  --vpCells.h = math.ceil((viewport.h + (viewport.y - (vpCells.r-1) * map.tileSize.h)) / map.tileSize.h)
  --vpCells.w = math.ceil((viewport.w + (viewport.x - (vpCells.c-1) * map.tileSize.w)) / map.tileSize.w)
  -- Do the update.
  local displayH = math.ceil(viewport.h / map.tileSize.h + 1)
  local displayW = math.ceil(viewport.w / map.tileSize.w + 1)
  sb:clear()
  for r = vpCells.r, vpCells.r + displayH - 1 do
    local y = r * tileSize.h - viewport.y
    for c = vpCells.c, vpCells.c + displayW - 1 do
      local x = c * tileSize.w - viewport.x
      local cell = map:cellAt(r, c)
      if cell then
        sb:add(cell.t.quad, x, y)
      end
    end
  end
  sb:flush()
end

function nextPowerOf2(n)
  local p = 2
  while p < n do
    p = p * 2
  end
  return p
end


-- vim: nu et ts=2 sts=2 sw=2

local dbg = require("dbg")
local clr = require("color")
local pl = {}
pl.pretty = require("pl.pretty")

local MAP_SIZE = { w=20, h=20 }
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
    pos = START_POS, mov = START_POS
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

function moveChar(c)
  if c.mov.x == c.pos.x and c.mov.y == c.pos.y then
    return false
  elseif c.mov.ticks and c.mov.ticks > 0 then
    c.pos.x = c.pos.x + (c.mov.x - c.pos.c) / c.mov.ticks
    c.pos.y = c.pos.y + (c.mov.y - c.pos.c) / c.mov.ticks
    c.mov.tick = c.mov.ticks - 1
    if c.mov.ticks == 0 then
      dbg.print(string.format("MOVE COMPLETE: %f,%f", c.mov.x, c.mov.y))
      c.mov.ticks = nil
      return false
    end
    return true
  end
end

function computeMove(c, moveCmd)
  -- XXX: Scale movement here if needed.
  local x = c.pos.x + moveCmd.x
  local y = c.pos.y + moveCmd.y
  pl.pretty.dump({x,y})
  pl.pretty.dump(glo.map.tiles[y+1])
  if not glo.map.tiles[y+1][x+1].pass then
    return false
  end
  return {x=x,y=y}
end

function love.update(dt)
  if paused then return end
  local time = love.timer.getTime() - glo.startTime
  --dbg.print(string.format("%f", time))
  local p = glo.player
  -- logic loop
  while glo.nextTickTime < time do
    dbg.print(string.format("TICK: %f", glo.nextTickTime))
    glo.nextTickTime = glo.nextTickTime + SECS_PER_TICK
    -- Apply previous move
    local playerMoving = moveChar(glo.player)
    -- Handle next move
    if not playerMoving then
      moveCmd = scanMoveKeys()
      if moveCmd then
        mov = computeMove(glo.player, moveCmd)
        if mov then
          p.mov = mov
        end
      end
    end
  end
  local phase = 1 - ((glo.nextTickTime - time) / SECS_PER_TICK)
  p.draw = { x = p.pos.x + phase * p.mov.x, y = p.pos.y + phase * p.mov.y }
end

function scanMoveKeys()
  local move = {x=0, y=0, nTicks=MOVES_PER_TILE}
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
  local pos = { x = p.draw.x * tileW, y = p.draw.y * tileH }
  -- Background
  love.graphics.setColor(clr.GREEN)
  rect("fill", 0, 0, screenSizeX, screenSizeY)
  love.graphics.setColor(clr.WHITE)
  love.graphics.draw(glo.map.image, centerX-pos.x, centerY-pos.y)
  -- Player
  love.graphics.setColor(clr.LGREEN)
  --dbg.printf("DRAW: %f,%f", pos.x, pos.y)
  local playerSize = (MOVES_PER_TILE-2)/MOVES_PER_TILE
  rect("fill", centerX, centerY, math.floor(playerSize*tileW), math.floor(playerSize*tileW))
end

function rect(mode, x, y, w, h)
  love.graphics.polygon(mode, x, y, x+w, y, x+w, y+h, x, y+h)
end

function loadMap()
  local terrain = {
    { c=clr.BLUE, pass=false },
    { c=clr.LBLUE, pass=true },
    { c=clr.GREEN, pass=true },
    { c=clr.YELLOW, pass=true },
  }
  seed = os.time()
  print("Map seed: "..seed)
  math.randomseed(seed)
  local map = {}
  map.tileSize = { w=40, h=40 }
  map.tiles = {}
  local cvs = love.graphics.newCanvas(MAP_SIZE.w * map.tileSize.w, MAP_SIZE.h * map.tileSize.h)
  cvs:renderTo(function() generateTiles(map, terrain) end)
  map.image = love.graphics.newImage(cvs:newImageData())
  return map
end

function generateTiles(map, terrain)
  for r = 1, MAP_SIZE.h do
    map.tiles[r] = {}
    for c = 1, MAP_SIZE.w do
      local cell = {}
      if r == 1 or r == MAP_SIZE.h or c == 1 or c == MAP_SIZE.w then
        cell.t = terrain[1]
      else
        local i = math.random(2, table.getn(terrain))
        cell.t = terrain[i]
      end
      map.tiles[r][c] = cell
      local x = (c-1) * map.tileSize.w
      local y = (r-1) * map.tileSize.h
      love.graphics.setColor(cell.t.c)
      love.graphics.rectangle("fill", x, y, x + map.tileSize.w, y + map.tileSize.h)
    end
  end
end


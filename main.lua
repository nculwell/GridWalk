-- vim: nu et ts=2 sts=2 sw=2

local dbg = require("dbg")
local clr = require("color")
local map = require("map")
local pl = {}
pl.pretty = require("pl.pretty")
pldump = pl.pretty.dump

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
  glo.map = map.loadMap()
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
      print("MOVE COMPLETE: "..m.dst.x..","..m.dst.y)
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
  local destCell = glo.map:cellAtXY(x, y)
  if not (destCell and not destCell.t.pass) then
    print("SKIP")
    pldump(destCell)
    --return false
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
          print("MOVING:")
          --print("dst")
          pldump(dst)
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
  local tileW, tileH = glo.map:getTileSize()
  local pos = { x = p.mov.phase.x * tileW, y = p.mov.phase.y * tileH }
  local mapViewport = {
    screenX = 0, screenY = 0, pxW = screenSizeX, pxH = screenSizeY,
    mapX = pos.x - centerX + math.floor(tileW/2),
    mapY = pos.y - centerY + math.floor(tileH/2),
  }
  --glo.map:update(mapViewport)
  -- Background
  love.graphics.clear()
  --love.graphics.setColor(clr.GREEN)
  --rect("fill", 0, 0, screenSizeX, screenSizeY)
  love.graphics.setColor(clr.WHITE)
  --love.graphics.draw(glo.map.image, centerX-pos.x, centerY-pos.y)
  glo.map:draw(mapViewport, { x=0, y=0 })
  -- Player
  love.graphics.setColor(clr.LGREEN)
  --dbg.printf("DRAW: %f,%f", pos.x, pos.y)
  local playerSize = (MOVES_PER_TILE-2)/MOVES_PER_TILE
  rect("fill", centerX, centerY, math.floor(playerSize*tileW), math.floor(playerSize*tileH))
end

function rect(mode, x, y, w, h)
  love.graphics.polygon(mode, x, y, x+w, y, x+w, y+h, x, y+h)
end


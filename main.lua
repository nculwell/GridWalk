-- vim: nu et ts=2 sts=2 sw=2

local dbg = require("dbg")
local clr = require("color")
local coords = require("coords")
local PxPos, CxPos, PxSize, CxSize =
  coords.PxPos, coords.CxPos, coords.PxSize, coords.CxSize
local TICKS_PER_SECOND = 10
local map = require("map")
local pl = {}
pl.pretty = require("pl.pretty")
pldump = pl.pretty.dump

local mapH = 20
--local TICKS_PER_SECOND = 10
local TICKS_PER_SECOND = 30
local SECS_PER_TICK = 1/TICKS_PER_SECOND
local MOVES_PER_TILE = 5
local START_POS = {r=1,c=1}
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
    c.mov.phase = c.mov.nxt.sub(c.mov.prv).scale(phase).add(c.mov.prv)
    {
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

function computeMovDst(c, moveCmdCx, ticks)
  local currentCx = CxPos(c.mov.dst.r, c.mov.dst.c)
  local moveToCx = currentCx.add(moveCmd)
  --pl.pretty.dump({x,y})
  --pl.pretty.dump(glo.map.tiles[y+1])
  local destCell = glo.map:cellAt(moveToCx.unpack())
  if not (destCell and not destCell.t.pass) then
    print("SKIP")
    pldump(destCell)
    --return false
  end
  return { r=moveToCx.r, c=moveToCx.c, ticks=ticks }
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
      moveCmdCx = scanMoveKeys()
      if moveCmdCx.isMoved then
        --pl.pretty.dump(moveCmdCx)
        dst = computeMovDst(glo.player, moveCmdCx, MOVES_PER_TILE)
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
  local r, c = 0, 0
  local m = glo.moveKeys
  glo.moveKeys = {}
  if love.keyboard.isDown("left") or m["left"] then c = c - 1 end
  if love.keyboard.isDown("right") or m["right"] then c = c + 1 end
  if love.keyboard.isDown("up") or m["up"] then r = r - 1 end
  if love.keyboard.isDown("down") or m["down"] then r = r + 1 end
  local moveCmd = PxSize(r, c)
  moveCmd.isMoved = not (c == 0 and r == 0)
  return moveCmd
end

-----------------------------------------------------------
-- DRAW

function love.draw()
  local p = glo.player
  -- Calculations
  local screenSize = PxSize(love.graphics.getDimensions())
  local center = screenSize.scale(.5)
  local tileSize = glo.map:getTileSize()
  local playerMovePhase = CxPos(p.mov.phase.x, p.mov.phase.y)
  local pos = playerMovePhase.toPx(tileSize)
  local playerTileDisplayOffset = center.sub(tileSize.scale(.5))
  local mapViewport = {
    screenOffset = PxPos(0, 0),
    screenSize = screenSize,
    mapOffset = pos.sub(playerTileDisplayOffset)
  }
  --glo.map:update(mapViewport)
  -- Background
  love.graphics.clear()
  --love.graphics.setColor(clr.GREEN)
  --rect("fill", 0, 0, screenSizeW, screenSizeH)
  love.graphics.setColor(clr.WHITE)
  --love.graphics.draw(glo.map.image, centerX-pos.x, centerY-pos.y)
  glo.map:draw(mapViewport, { x=0, y=0 })
  -- Player
  love.graphics.setColor(clr.LGREEN)
  --dbg.printf("DRAW: %f,%f", pos.x, pos.y)
  local playerSizePct = 0.6
  local playerSize = tileSize.scale(playerSizePct)
  local playerIntraTileOffset =
    tileSize.sub(playerSize).scale(.5)
  local playerRectDisplayOffset =
    playerTileDisplayOffset.add(playerIntraTileOffset)
  rect("fill", playerRectDisplayOffset, playerSize)
  --print(string.format("Player: (%d,%d,%d,%d)",
  --  playerRectDisplayOffset.x, playerRectDisplayOffset.y,
  --  playerSize.w, playerSize.h))
  love.graphics.print("Current FPS: "..tostring(love.timer.getFPS()), 2, 2)
end

function rect(mode, pos, size)
  local x, y = pos.unpack()
  local w, h = size.unpack()
  love.graphics.polygon(mode, x, y, x+w, y, x+w, y+h, x, y+h)
end


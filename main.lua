-- vim: nu et ts=2 sts=2 sw=2

local dbg = require("dbg")
local clr = require("color")
local coords = require("coords")
local PxPos, CxPos, PxSize, CxSize =
  coords.PxPos, coords.CxPos, coords.PxSize, coords.CxSize
local TICKS_PER_SECOND = 10
local map = require("map")
local inputModule = require("input")
local pl = {}
pl.pretty = require("pl.pretty")
pldump = pl.pretty.dump

local mapH = 20
--local TICKS_PER_SECOND = 10
local TICKS_PER_SECOND = 10
local SECS_PER_TICK = 1/TICKS_PER_SECOND
local MOVES_PER_TILE = 3
local START_POS = CxPos(2, 2)
local VSYNC = false
local FULLSCREENTYPE = "desktop"
-- local FULLSCREENTYPE = "exclusive"
local footsteps = {}

local glo = {
  fullscreen=true,
  paused=false,
  quitting=false,
  player = {
    mov = { prv=START_POS, nxt=START_POS, dst={pos=START_POS} }
  },
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
  inputModule.load()
  loadFootsteps()
end

local footstepsLoadInfo = {
  water = { fn="sound/fsl/Footstep_Water_%02d.mp3", n=8 },
  dirt  = { fn="sound/fsl/Footstep_Dirt_%02d.mp3", n=10 },
}

function loadFootsteps()
  for k in pairs(footstepsLoadInfo) do
    footsteps[k] = {}
    local fli = footstepsLoadInfo[k]
    for s = 1, fli.n do
      local filename = string.format(fli.fn, s-1)
      local sd = love.sound.newSoundData(filename)
      footsteps[k][s] = love.audio.newSource(sd)
    end
    footsteps[k].next = 1
  end
end

-- Map input events to the input module.
love.keypressed = inputModule.keypressed
love.gamepadpressed = inputModule.gamepadpressed
love.joystickpressed = inputModule.joystickpressed
love.gamepadpressed = inputModule.gamepadpressed

function toggleFullscreen()
  glo.fullscreen = not glo.fullscreen
  local screenW, screenH, flags = love.window.getMode()
  local newFlags = {
    fullscreen = glo.fullscreen, fullscreentype = FULLSCREENTYPE, vsync = VSYNC, display = flags.display, }
  dump(newFlags)
  print(screenW.."x"..screenH)
  love.window.setMode(screenW, screenH, newFlags)
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
      local moveXY = inputModule.getMovementCommand()
      local moveCmd = CxSize(moveXY.x, moveXY.y)
      if not (moveXY.x == 0 and moveXY.y == 0) then
        --pl.pretty.dump(moveCmd)
        local dst = computeMovDst(glo.player, moveCmd, MOVES_PER_TILE)
        if dst then
          printf("MOVING: (%d, %d), ticks=%d", dst.pos.r, dst.pos.c, dst.ticks)
          --pldump({ dst=dst })
          p.mov.dst = dst
          -- TODO: Pick appropriate footsteps for tile.
          local fs = footsteps["dirt"]
          love.audio.play(fs[fs.next])
          fs.next = fs.next + 1
          if fs.next > #fs then fs.next = 1 end
        end
      end
    end
  end
  setCharPhase(glo.player, phase)
end

function computeMovDst(c, moveCmdCx, ticks)
  local currentCx = c.mov.dst.pos
  local moveToCx = currentCx.add(moveCmdCx)
  --pl.pretty.dump({x,y})
  --pl.pretty.dump(glo.map.tiles[y+1])
  local destCell = glo.map:cellAt(moveToCx.unpack())
  if not (destCell and destCell.t.pass) then
    printf("SKIP: RC=%d,%d", moveToCx.unpack())
    return nil
  end
  return { pos=moveToCx, ticks=ticks }
end

function moveChar(c)
  local m = c.mov
  m.dst.isMoving = false
  if m.dst.ticks and m.dst.ticks > 0 then
    m.dst.ticks = m.dst.ticks - 1
    m.prv = m.dst.pos
    m.nxt = m.dst.pos
    m.phase = m.dst.pos
    if m.dst.ticks == 0 then
      printf("MOVE COMPLETE: RC=%d,%d", m.dst.pos.unpack())
    else
      m.dst.isMoving = true
    end
    return true
  else
    return false
  end
end

function moveCharPOSTPONED(c)
  local m = c.mov
  --pl.pretty.dump(m)
  m.dst.isMoving = false
  if m.dst.ticks and m.dst.ticks > 0 then
    --pldump({ nxt=m.nxt })
    m.prv = m.nxt
    --pldump({prv=m.prv,dst=m.dst.pos})
    local delta =
      m.dst.pos
      .sub(m.prv)
      .toCxSize()
    --pldump({ delta1=delta })
    delta = delta
      .scale(1/m.dst.ticks)
    --pldump({ tickDelta=delta })
    printf("Tick delta: RC=%f,%f", delta.cxH, delta.cxW)
    m.nxt = m.prv.add(delta)
    m.dst.ticks = m.dst.ticks - 1
    if m.dst.ticks == 0 then
      printf("MOVE COMPLETE: RC=%d,%d", m.dst.pos.unpack())
    else
      printf("STILL MOVING: RC=%d,%d", m.dst.pos.unpack())
      m.dst.isMoving = true
    end
  end
end

function setCharPhase(c, phase)
  if not c.mov.phase then
    c.mov.phase = c.mov.dst.pos
  end
end

function setCharPhasePOSTPONED(c, phase)
  if c.mov.dst.isMoving then
    local delta = c.mov.nxt.sub(c.mov.prv)
    local deltaAsSize = delta.toCxSize()
    local deltaScaled = deltaAsSize.scale(phase)
    --print("PHASE="..phase); pldump({ phaseDelta=deltaScaled })
    --printf("Phase delta: RC=%f,%f", deltaScaled.cxH, deltaScaled.cxW)
    c.mov.phase = c.mov.prv.add(deltaScaled)
  else
    c.mov.phase = c.mov.dst.pos
  end
end

-----------------------------------------------------------
-- DRAW

function love.draw()
  local p = glo.player
  -- Calculations
  local screenWidth, screenHeight = love.graphics.getDimensions()
  local shortDimension = math.min(screenWidth, screenHeight)
  local mapDisplaySize = PxSize(shortDimension, shortDimension)
  local center = mapDisplaySize.scale(.5)
  local tileSize = glo.map:getTileSize()
  local playerMovePhase = p.mov.phase
  local pos = playerMovePhase.toPx(tileSize)
  local playerTileDisplayOffset = center.sub(tileSize.scale(.5))
  local mapViewport = {
    screenOffset = PxPos(0, 0),
    displaySize = mapDisplaySize,
    mapOffset = pos.sub(playerTileDisplayOffset)
  }
  -- Background
  love.graphics.clear()
  love.graphics.setColor(clr.WHITE)
  glo.map:draw(mapViewport, pos)
  -- Sidebar
  love.graphics.setColor(150,150,150)
  local orientation = "V"
  if shortDimension == screenWidth then orientation = "H" end
  local rect = love.graphics.rectangle
  if orientation == "V" then
    rect("fill", shortDimension, 0, screenWidth-shortDimension, screenHeight)
  else
    rect("fill", 0, shortDimension, screenWidth, screenHeight-shortDimension)
  end
  -- FPS counter
  love.graphics.setColor(clr.LGREEN)
  love.graphics.print("Current FPS: "..love.timer.getFPS(), 2, 2)
end

function netReceiveEvent(event)
  print("Got message: ", event.data, event.peer)
  --event.peer:send( "ping" )
end

function netConnectEvent(event)
  print(event.peer, "connected.")
  --event.peer:send("ping")
end

function netDisconnectEvent(event)
  print(event.peer, "disconnected.")
end

do
  local enet = require "enet"
  local host = enet.host_create()
  local server = host:connect("localhost:6789")
  function pumpNetEvents()
    while true do
      local event = host:service()
      if event == nil then break end
      if event.type == "receive" then
        netReceiveEvent(event)
      elseif event.type == "connect" then
        netConnectEvent(event)
      elseif event.type == "disconnect" then
        netDisconnectEvent(event)
      end
    end
  end
end


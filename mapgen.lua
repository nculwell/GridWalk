-- vim: nu et ts=8 sts=2 sw=2

local module = {}

local _newGrid, _blit, _slice, _shrinkRect

function module.buildRandomMap(seed, tiles, size)
  local rand = love.math.newRandomGenerator(seed)
  local outerRect = { x=1, y=1, w=size.cxW, h=size.cxH }
  local innerRect = _shrinkRect(outerRect, 1)
  local grid = module.newGrid(outerRect)
  module.drawRect("line", grid, outerRect, tiles[1])
  module.drawRandomRect(rand, grid, innerRect, _slice(tiles, 2))
  return grid
end

function module.drawRect(mode, dstGrid, rect, tile)
  local top, bottom = rect.y, rect.y + rect.h - 1
  local left, right = rect.x, rect.x + rect.w - 1
  if mode == "fill" then
    for r = top, bottom do
      for c = rect.x, right do
        dstGrid[r][c] = { t = tile }
      end
    end
  elseif mode == "line" then
    for r = top, bottom do
      if r == top or r == bottom then
        for c = left, right do
          dstGrid[r][c] = { t = tile }
        end
      else
        dstGrid[r][left] = { t = tile }
        dstGrid[r][right] = { t = tile }
      end
    end
    for i, c in ipairs({ rect.x, rect.x + rect.w - 1 }) do
      dstGrid[rect.y][c] = { t = tile }
      dstGrid[rect.y + rect.h - 1][c] = { t = tile }
    end
  else
    error("Invalid DrawMode: "..mode)
  end
end

function module.drawRandomRect(rand, dstGrid, rect, tiles)
  local tileCount = table.getn(tiles)
  for r = rect.y, rect.y + rect.h - 1 do
    for c = rect.x, rect.x + rect.w - 1 do
      local i = rand:random(tileCount)
      dstGrid[r][c] = { t = tiles[i] }
    end
  end
  return dstGrid
end

_newGrid = function(size)
  local g = {}
  for r = 1, size.h do
    g[r] = {}
  end
  return g
end

_blit = function(dstGrid, dstXY, srcGrid, srcRect)
  local dstX, dstY = dstXY.x, dstXY.y
  if not srcRect then
    srcRect = { 1, 1, table.getn(srcGrid), table.getn(srcGrid[1]) }
  end
  local srcX, srcY = srcRect.x, srcRect.y
  local srcW, srcH = srcRect.w, srcRect.h
  local sr = srcY
  for dr = dstY, dstY + srcH do
    local sc = srcX
    for dc = dstX, dstX + srcW do
      dstGrid[dr][dc] = srcGrid[sr][sc]
      sc = sc + 1
    end
    sr = sr + 1
  end
end

_shrinkRect = function(rect, n)
  assert(n >= 0)
  if not n then n = 1 end
  local minSize = n * 2 + 1
  if rect.w < minSize or rect.h < minSize then
    error(string.format("Rect too small: rect=(%d,%d,%d,%d), n=%d",
      rect.x, rect.y, rect.w, rect.h, n))
  end
  return { x=rect.x+n, y=rect.y+n, w=rect.w-n*2, h=rect.h-n*2 }
end

_slice = function(tbl, first, last, step)
  local slice = {}
  local sliceIndex = 1
  for tblIndex = first or 1, last or #tbl, step or 1 do
    slice[sliceIndex] = tbl[tblIndex]
    sliceIndex = sliceIndex + 1
  end
  return slice
end

return module


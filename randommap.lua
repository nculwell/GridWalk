-- vim: nu et ts=8 sts=2 sw=2

local module = {}

function module.buildRandomMap(seed, mapTiles, mapSize)
  local rand = love.math.newRandomGenerator(seed)
  local cells = {}
  local tileCount = table.getn(mapTiles)
  for r = 1, mapSize.cxH do
    cells[r] = {}
    for c = 1, mapSize.cxW do
      local cell = {}
      if r == 1 or r == mapSize.cxH or c == 1 or c == mapSize.cxW then
        cell.t = mapTiles[1]
      else
        local i = rand:random(2, tileCount)
        cell.t = mapTiles[i]
      end
      cells[r][c] = cell
    end
  end
  return cells
end

return module


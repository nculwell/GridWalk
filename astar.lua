-- vim: nu et ts=8 sts=2 sw=2
-- A* pathfinding algorithm

local Set = require("pl.set")

local _reconstructPath, _astar, _findLowestScoringNode, neighbors

_reconstructPath = function(cameFrom, current)
  totalPath = { current }
  while cameFrom[current] do
    current = cameFrom[current]
    totalPath[#totalPath] = current
  end
  return totalPath
end

_astar = function(start, goal, heuristicCostEstimate, neighbors)
  guard_globals()
  -- The set of nodes already evaluated.
  closedSet = Set({})
  -- The set of currently discovered nodes that are not evaluated yet.
  -- Initially, only the start node is known.
  openSet = Set({start})
  -- For each node, which node it can most efficiently be reached from.  If a
  -- node can be reached from many nodes, cameFrom will eventually contain the
  -- most efficient previous step.
  cameFrom = {}
  -- For each node, the cost of getting from the start node to that node.
  gScore = {} -- default value infinity
  -- The cost of going from start to start is zero.
  gScore[start] = 0
  -- For each node, the total cost of getting from the start node to the goal
  -- by passing by that node. That value is partly known, partly heuristic.
  fScore := {} -- default value infinity
  -- For the first node, that value is completely heuristic.
  fScore[start] := heuristicCostEstimate(start, goal)
  while table.getn(openSet) > 0 do
    local current = _findLowestScoringNode(openSet, fScore)
    if current == goal then
      return _reconstructPath(cameFrom, current)
    end
    openSet = openSet - current
    closedSet = closedSet + current
    for i, neighbor in ipairs(neighbors(current)) do
      if not closedSet[neighbor] then
        -- Ignore the neighbor which is already evaluated.
        -- The tentativeGScore is the distance from start to a neighbor.
        tentativeGScore = gScore[current] + distBetween(current, neighbor)
        local haveBetterNode = false
        if not openSet[neighbor] then -- Discovered a new node.
          openSet = openSet + neighbor
        elseif tentativeGScore >= gScore[neighbor] then
          haveBetterNode = true
        end
        if not haveBetterNode then
          cameFrom[neighbor] = current
          gScore[neighbor] = tentativeGScore
          fScore[neighbor] = gScore[neighbor] + heuristicCostEstimate(neighbor, goal)
        end
      end
    end
  end
end

_findLowestScoringNode = function(openSet, fScore)
  local minScore = math.huge
  local minNode = nil
  for node in pairs(openSet) do
    local fs = fScore[node]
    if fs < minScore then
      minScore = fs
      minNode = node
    end
  end
  return minNode
end

function catch_assignment_to_undefined_global(varname, newvalue)
  assert(rawget(globals(), varname) == nil)
  error("assignment to undefined global \"" .. varname
    .. "\"; use global(\"var\", val) to define global variables")
end

function global(varname, newvalue)
  rawset(globals(), varname, newvalue)
end

function expose_globals()
  settagmethod(tag(nil), "setglobal", nil)
end

function guard_globals()
  settagmethod(tag(nil), "setglobal", catch_assignment_to_undefined_global)
end


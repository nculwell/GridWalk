-- vim: et ts=8 sts=2 sw=2

local module = {}

function module.PxPos(x, y)
  local p = { x=x, y=y, t="PxPos" }
  function p:add(q)
    assert(q.t == "PxPos")
    return module.PxPos(p.x+q.x, p.y+q.y)
  end
  function p:sub(q)
    assert(q.t == "PxPos")
    return module.PxPos(p.x-q.x, p.y-q.y)
  end
  function p:toCx(s)
    assert(s.t == "PxSize")
    return module.CxPos(math.floor(p.x/s.w), math.floor(p.y/s.w))
  end
  function p:toCxCeil(s)
    assert(s.t == "PxSize")
    return module.CxPos(math.ceil(p.x/s.w), math.ceil(p.y/s.w))
  end
end

function module.CxPos(x, y)
  local p = { x=x, y=y, t="CxPos" }
  function p:add(q)
    assert(q.t == "CxPos")
    return module.CxPos(p.x+q.x, p.y+q.y)
  end
  function p:sub(q)
    assert(q.t == "CxPos")
    return module.CxPos(p.x-q.x, p.y-q.y)
  end
  function p:toPx(s)
    assert(s.t == "PxSize")
    return module.PxPos(p.x*s.w, p.y*s.w)
  end
end

function module.PxSize(w, h)
  local s = { w=w, h=h, t="PxSize" }
end

function module.CxSize(w, h)
  local s = { w=w, h=h, t="CxSize" }
end

return module


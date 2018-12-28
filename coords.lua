-- vim. et ts=8 sts=2 sw=2

function PxPos(x, y)
  assert(x)
  assert(y)
  assert(type(x) == "number")
  assert(type(y) == "number")
  local p = { x=x, y=y, t="PxPos" }
  function p.add(q)
    assert(q.t == "PxPos" or q.t == "PxSize", "t: "..q.t)
    q = PxPos(q.unpack())
    return PxPos(p.x+q.x, p.y+q.y)
  end
  function p.sub(q)
    assert(q.t == "PxPos" or q.t == "PxSize", "t: "..q.t)
    q = PxPos(q.unpack())
    return PxPos(p.x-q.x, p.y-q.y)
  end
  function p.toCx(s)
    assert(s.t == "PxSize", "t: "..s.t)
    return CxPos(math.floor(p.x/s.pxW), math.floor(p.y/s.pxH))
  end
  function p.toCxCeil(s)
    assert(s.t == "PxSize", "t: "..s.t)
    return CxPos(math.ceil(p.x/s.pxW), math.ceil(p.y/s.pxH))
  end
  function p.unpack()
    return p.x, p.y
  end
  return p
end

function CxPos(r, c)
  assert(r, "CxPos R nil.")
  assert(c, "CxPos C nil.")
  assert(type(r) == "number")
  assert(type(c) == "number")
  local p = { r=r, c=c, t="CxPos" }
  function p.add(q)
    assert(q.t == "CxPos" or q.t == "CxSize", "t: "..q.t.." (CxPos|CxSize)")
    if q.t == "CxSize" then q = CxPos(q.cxH, q.cxW) end
    return CxPos(p.r+q.r, p.c+q.c)
  end
  function p.sub(q)
    assert(q.t == "CxPos" or q.t == "CxSize", "t: "..q.t.." (CxPos|CxSize)")
    if q.t == "CxSize" then q = CxPos(q.cxH, q.cxW) end
    return CxPos(p.r-q.r, p.c-q.c)
  end
  function p.toPx(s)
    assert(s.t == "PxSize", "t: "..s.t.." (PxSize)")
    return PxPos(p.r*s.pxH, p.c*s.pxW)
  end
  function p.toCxSize()
    return CxSize(p.c, p.r) -- reverse order of elements (HW=RC -> CR=WH)
  end
  function p.unpack()
    return p.r, p.c
  end
  return p
end

function PxSize(w, h)
  assert(w, "PxSize W nil.")
  assert(h, "PxSize H nil.")
  assert(type(w) == "number", "PxSize W type: "..type(w))
  assert(type(h) == "number", "PxSize H type: "..type(w))
  local s = { pxW=w, pxH=h, t="PxSize" }
  function s.unpack()
    return s.pxW, s.pxH
  end
  function s.add(q)
    assert(q.t == "PxSize", "PxSize.add t: "..q.t)
    return PxSize(s.pxW+q.pxW, s.pxH+q.pxH)
  end
  function s.sub(q)
    assert(q.t == "PxSize", "PxSize.sub t: "..q.t)
    return PxSize(s.pxW-q.pxW, s.pxH-q.pxH)
  end
  function s.scale(factor)
    assert(type(factor) == "number", "Factor type: "..type(factor))
    return PxSize(math.floor(s.pxW*factor), math.floor(s.pxH*factor))
  end
  function s.toCx(q)
    assert(q.t == "PxSize", "t: "..q.t)
    return PxSize(math.floor(s.pxW/q.pxW), math.floor(s.pxH/q.pxH))
  end
  function s.toCxCeil(q)
    assert(q.t == "PxSize", "t: "..q.t)
    return PxSize(math.ceil(s.pxW/q.pxW), math.ceil(s.pxH/q.pxH))
  end
  return s
end

function CxSize(w, h)
  assert(w, "CxSize W nil.")
  assert(h, "CxSize H nil.")
  assert(type(w) == "number", "CxSize W type: "..type(w))
  assert(type(h) == "number", "CxSize H type: "..type(w))
  local s = { cxW=w, cxH=h, t="CxSize" }
  function s.add(q)
    assert(q.t == "CxSize", "CxSize.add t: "..q.t)
    return CxSize(s.pxW+q.pxW, s.pxH+q.pxH)
  end
  function s.sub(q)
    assert(q.t == "CxSize", "CxSize.sub t: "..q.t)
    return CxSize(s.pxW-q.pxW, s.pxH-q.pxH)
  end
  function s.scale(factor)
    assert(type(factor) == "number", "Factor type: "..type(factor))
    return CxSize(s.cxW*factor, s.cxH*factor)
  end
  function s.floor()
    return CxSize(math.floor(s.cxW), math.floor(s.cxH))
  end
  function s.ceil()
    return CxSize(math.floor(s.cxW), math.floor(s.cxH))
  end
  function s.unpack()
    return s.cxW, s.cxH
  end
  return s
end

function PxRect(x, y, w, h)
  assert(x)
  assert(y)
  assert(w)
  assert(h)
  assert(type(x) == "number")
  assert(type(y) == "number")
  assert(type(w) == "number")
  assert(type(h) == "number")
  local r = { p=PxPos(x, y), s=PxSize(w, h), t="PxRect" }
  function r.offset()
    return r.p
  end
  function r.size()
    return r.s
  end
  function translate(tr)
    assert(tr.t == "PxPos" or tr.t == "PxSize")
    trRepacked = PxPos(tr.unpack())
    return PxRect(r.p.add(trRepacked).unpack(), r.s.unpack())
  end
  function scale(factor)
    return PxRect(p.unpack(), s.scale(factor).unpack())
  end
  function r.unpack()
    return r.x, r.y, r.pxW, r.pxH
  end
end

return {
  PxPos=PxPos, CxPos=CxPos,
  PxSize=PxSize, CxSize=CxSize,
  PxRect=PxRect
}


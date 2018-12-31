-- vim: nu et ts=2 sts=2 sw=2

return {
  tiles = {
    { id=1, c=clr.BLUE, pass=false, fs="water" },
    { id=2, c=clr.LBLUE, pass=true, fs="water" },
    { id=3, c=clr.GREEN, pass=true, fs="dirt" },
    { id=4, c=clr.YELLOW, pass=true, fs="dirt" },
  },
  creatures = {
    { id=1, c=clr.RED, n="goblin", ns="goblins" },
  },
  [1] = {
    name = "Tropic Isles",
    rooms = {
      [1] = {
        name = "Atoll",
        tiles = {
          { 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 },
          { 1, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 1 },
          { 1, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 1 },
          { 1, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 1 },
          { 1, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 1 },
          { 1, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 1 },
          { 1, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 1 },
          { 1, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 1 },
          { 1, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 1 },
          { 1, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 1 },
          { 1, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 1 },
          { 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 },
        },
        creatures = {
          [1] = { rc={4,4}, cid=1 },
        },
      },
    },
  },
}


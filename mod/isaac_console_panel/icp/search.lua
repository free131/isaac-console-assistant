local M = {}
local function norm(s) return (tostring(s or ''):lower():gsub('%s+', '')) end
function M.prepare(catalog)
  catalog.by_key = {}
  for _, e in ipairs(catalog.entries) do catalog.by_key[e.key] = e end
  return catalog
end
function M.query(catalog, text, category, state, greed)
  text = norm(text)
  local prefix, suffix = text:match('^(.-)(%-?%d+)$')
  local hits = {}
  for position, e in ipairs(catalog.entries) do
    if (category == 'all' or category == e.category or (category == 'favorites' and state.favorites[e.key])) and
        (e.category ~= 'stages' or e.greed == greed) then
      local score, amount = text == '' and 1 or 0, nil
      for _, alias in ipairs(e.search) do
        local a = norm(alias)
        if a ~= '' and text ~= '' then
          if a == text then score = math.max(score, 1000)
          elseif a:find(text, 1, true) then score = math.max(score, 500) end
          if e.action == 'resource' and prefix and prefix ~= '' and prefix == a then
            score, amount = 1200, tonumber(suffix)
          end
        end
      end
      if score > 0 then hits[#hits + 1] = {entry=e, score=score, amount=amount, position=position} end
    end
  end
  table.sort(hits, function(a,b) if a.score == b.score then return a.position < b.position end return a.score > b.score end)
  return hits
end
function M.history(catalog, state)
  local hits = {}
  for _, row in ipairs(state.history) do
    local entry = catalog.by_key[row.key]
    if entry then hits[#hits+1] = {entry=entry, amount=row.amount, operation=row.operation, recorded=row} end
  end
  return hits
end
return M

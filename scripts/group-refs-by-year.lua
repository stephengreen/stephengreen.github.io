-- group-refs-by-year.lua
-- Pandoc Lua filter that:
--   1. Runs citeproc manually (requires citeproc: false in YAML)
--   2. Sorts bibliography entries by year (descending)
--   3. Groups them with H2 year headings

local function build_year_lookup(doc)
  local lookup = {}
  local ok, refs = pcall(pandoc.utils.references, doc)
  if ok and refs then
    for _, ref in ipairs(refs) do
      local id = ref.id or ""
      if ref.issued then
        local dp = ref.issued["date-parts"]
        if dp and dp[1] and dp[1][1] then
          lookup[id] = tostring(dp[1][1])
        end
      end
      if not lookup[id] then
        local y = id:match(":(%d%d%d%d)")
        if y then lookup[id] = y end
      end
    end
  end
  return lookup
end

local function get_entry_year(item, year_lookup)
  local id = (item.identifier or ""):gsub("^ref%-", "")
  local year = year_lookup[id]
  if not year then
    year = id:match(":(%d%d%d%d)")
  end
  if not year then
    local text = pandoc.utils.stringify(item)
    year = text:match("%((%d%d%d%d)%)") or text:match("(%d%d%d%d)")
  end
  return year or "0000"
end

function Pandoc(doc)
  doc = pandoc.utils.citeproc(doc)
  local year_lookup = build_year_lookup(doc)

  -- Remove the auto-generated "References" heading from citeproc
  local new_blocks = pandoc.List()
  for _, block in ipairs(doc.blocks) do
    if not (block.t == "Header" and pandoc.utils.stringify(block) == "References") then
      new_blocks:insert(block)
    end
  end
  doc.blocks = new_blocks

  doc = doc:walk({
    Div = function(el)
      if el.identifier ~= "refs" then
        return nil
      end

      -- Collect all csl-entry items with their years
      local entries = {}
      local other_items = pandoc.List()

      for _, item in ipairs(el.content) do
        if item.t == "Div" and item.classes:includes("csl-entry") then
          local year = get_entry_year(item, year_lookup)
          table.insert(entries, { year = year, item = item })
        else
          other_items:insert(item)
        end
      end

      -- Sort entries by year descending
      table.sort(entries, function(a, b)
        return a.year > b.year
      end)

      -- Build result with year headings
      local result = pandoc.List()
      -- Add any non-entry items first (e.g. preamble)
      for _, item in ipairs(other_items) do
        result:insert(item)
      end

      local current_year = nil
      for _, entry in ipairs(entries) do
        if entry.year ~= current_year then
          current_year = entry.year
          result:insert(pandoc.Header(2, pandoc.Str(current_year),
            pandoc.Attr("year-" .. current_year, {"year-group"})))
        end
        result:insert(entry.item)
      end

      el.content = result
      return el
    end
  })

  return doc
end

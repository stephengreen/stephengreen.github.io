-- group-refs-by-year.lua
-- Pandoc Lua filter that:
--   1. Runs citeproc manually (requires citeproc: false in YAML)
--   2. Expands .pub-highlight divs: pulls title, journal, year from bib data
--   3. Sorts bibliography entries by year (descending)
--   4. Groups them with H2 year headings

-- Journal abbreviation to full name mapping
local journal_names = {
  ["Phys. Rev. Lett."] = "Physical Review Letters",
  ["Phys. Rev. D"] = "Physical Review D",
  ["Class. Quant. Grav."] = "Classical and Quantum Gravity",
  ["Phys. Rev. X"] = "Physical Review X",
  ["JCAP"] = "JCAP",
}

local function build_ref_lookup(doc)
  local lookup = {}
  local ok, refs = pcall(pandoc.utils.references, doc)
  if ok and refs then
    for _, ref in ipairs(refs) do
      local id = ref.id or ""
      local info = {}

      -- Year
      if ref.issued then
        local dp = ref.issued["date-parts"]
        if dp and dp[1] and dp[1][1] then
          info.year = tostring(dp[1][1])
        end
      end
      if not info.year then
        local y = id:match(":(%d%d%d%d)")
        if y then info.year = y end
      end

      -- Title
      if ref.title then
        info.title = pandoc.utils.stringify(ref.title)
      end

      -- Journal
      if ref["container-title"] then
        local jabbr = pandoc.utils.stringify(ref["container-title"])
        info.journal = journal_names[jabbr] or jabbr
      end

      -- DOI and URL (arXiv)
      if ref.doi then
        info.doi = pandoc.utils.stringify(ref.doi)
      end
      if ref.url then
        local u = pandoc.utils.stringify(ref.url)
        local arxiv_id = u:match("arxiv.org/abs/(.+)")
        if arxiv_id then
          info.arxiv = arxiv_id
        else
          info.url = u
        end
      end

      lookup[id] = info
    end
  end
  return lookup
end

local function get_entry_year(item, ref_lookup)
  local id = (item.identifier or ""):gsub("^ref%-", "")
  local info = ref_lookup[id]
  if info and info.year then return info.year end
  local y = id:match(":(%d%d%d%d)")
  if y then return y end
  local text = pandoc.utils.stringify(item)
  return text:match("%((%d%d%d%d)%)") or text:match("(%d%d%d%d)") or "0000"
end

function Pandoc(doc)
  doc = pandoc.utils.citeproc(doc)
  local ref_lookup = build_ref_lookup(doc)

  -- Remove the auto-generated "References" heading from citeproc
  local new_blocks = pandoc.List()
  for _, block in ipairs(doc.blocks) do
    if not (block.t == "Header" and pandoc.utils.stringify(block) == "References") then
      new_blocks:insert(block)
    end
  end
  doc.blocks = new_blocks

  -- Expand .pub-highlight divs with key attribute
  doc = doc:walk({
    Div = function(el)
      if not el.classes:includes("pub-highlight") then return nil end
      local key = el.attributes["key"]
      if not key then return nil end

      local info = ref_lookup[key]
      if not info then return nil end

      -- Build title div
      local title_div = pandoc.Div(
        {pandoc.Plain({pandoc.Str(info.title or "")})},
        pandoc.Attr("", {"pub-title"}))

      -- Build venue div
      local venue = (info.journal or "")
      if info.year then venue = venue .. " (" .. info.year .. ")" end
      local venue_div = pandoc.Div(
        {pandoc.Plain({pandoc.Str(venue)})},
        pandoc.Attr("", {"pub-venue"}))

      -- Build description div: keep existing content + append citation
      local desc_content = el.content
      -- Append DOI or arXiv link
      if #desc_content > 0 then
        local last = desc_content[#desc_content]
        if last.t == "Para" or last.t == "Plain" then
          if info.doi then
            last.content:insert(pandoc.Space())
            last.content:insert(pandoc.Link(
              {pandoc.Str("[doi]")},
              "https://doi.org/" .. info.doi
            ))
          end
          if info.arxiv then
            last.content:insert(pandoc.Space())
            last.content:insert(pandoc.Link(
              {pandoc.Str("[arXiv]")},
              "https://arxiv.org/abs/" .. info.arxiv
            ))
          end
        end
      end
      local desc_div = pandoc.Div(desc_content, pandoc.Attr("", {"pub-desc"}))

      el.content = {title_div, venue_div, desc_div}
      el.attributes["key"] = nil
      return el
    end
  })

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
          local year = get_entry_year(item, ref_lookup)
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

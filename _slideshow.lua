--[[
  _slideshow.lua — builds the Photo Gallery carousel from whatever is in
  images/slideshow/.

  Drop a photo into that folder and it appears in the slideshow on the next
  build; photogallery.qmd never needs editing. The filter replaces an empty
  div with the id `lab-slideshow`.

  Captions are optional. Add them under `slideshow-captions` in the page's
  YAML header, keyed by exact filename. A photo with no entry simply shows
  no caption.

  Slide order is shuffled in the browser on every page load (see the script
  emitted at the end), so visitors do not always see the same first photo.
  The build order below is alphabetical purely so the generated HTML is
  reproducible.
]]

local PHOTO_DIR = "images/slideshow"
local ALLOWED = { jpg = true, jpeg = true, png = true, webp = true, gif = true, avif = true }

local function esc(s)
  return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

-- Collect image files, ignoring .gitkeep, dotfiles and anything non-image.
local function list_photos()
  local ok, entries = pcall(pandoc.system.list_directory, PHOTO_DIR)
  if not ok then
    io.stderr:write("[slideshow] cannot read " .. PHOTO_DIR .. "/ — slideshow left empty\n")
    return {}
  end
  local photos = {}
  for _, name in ipairs(entries) do
    local ext = name:match("%.([%a%d]+)$")
    if ext and ALLOWED[ext:lower()] and name:sub(1, 1) ~= "." then
      table.insert(photos, name)
    end
  end
  table.sort(photos)
  return photos
end

local function build_carousel(captions)
  local photos = list_photos()
  if #photos == 0 then
    io.stderr:write("[slideshow] no images found in " .. PHOTO_DIR .. "/\n")
    return pandoc.Para(pandoc.Emph(pandoc.Str("No photos yet.")))
  end
  io.stderr:write("[slideshow] " .. #photos .. " photos\n")

  local indicators, slides = {}, {}
  for i, name in ipairs(photos) do
    local caption = captions[name]
    -- Screen readers get the caption when there is one; otherwise say plainly
    -- that it is a lab photo rather than reading out a filename.
    local alt = caption or "BAD Lab photo"

    table.insert(indicators, string.format(
      '<button type="button" data-bs-target="#lab-gallery" data-bs-slide-to="%d"%s aria-label="Slide %d"></button>',
      i - 1, i == 1 and ' class="active" aria-current="true"' or '', i))

    -- loading="lazy" matters here: the carousel holds every photo at once, but
    -- only the active slide is visible, so hidden slides are not fetched until
    -- they come round.
    local parts = {
      i == 1 and '<div class="carousel-item active">' or '<div class="carousel-item">',
      string.format('<img src="%s/%s" class="d-block w-100" loading="lazy" decoding="async" alt="%s">',
        PHOTO_DIR, esc(name), esc(alt)),
    }
    if caption then
      table.insert(parts, '<div class="carousel-caption"><p>' .. esc(caption) .. '</p></div>')
    end
    table.insert(parts, '</div>')
    table.insert(slides, table.concat(parts, "\n"))
  end

  local html = table.concat({
    '<div id="lab-gallery" class="carousel slide" data-bs-ride="carousel" data-bs-interval="6000">',
    '<div class="carousel-indicators">', table.concat(indicators, "\n"), '</div>',
    '<div class="carousel-inner">', table.concat(slides, "\n"), '</div>',
    '<button class="carousel-control-prev" type="button" data-bs-target="#lab-gallery" data-bs-slide="prev">',
    '<span class="carousel-control-prev-icon" aria-hidden="true"></span>',
    '<span class="visually-hidden">Previous</span></button>',
    '<button class="carousel-control-next" type="button" data-bs-target="#lab-gallery" data-bs-slide="next">',
    '<span class="carousel-control-next-icon" aria-hidden="true"></span>',
    '<span class="visually-hidden">Next</span></button>',
    '</div>',
    -- Runs while the page is still parsing, so the shuffle is done before
    -- Bootstrap initialises the carousel on window load. With JS off the
    -- slideshow still works, just always in alphabetical order.
    '<script>',
    '(function () {',
    '  var inner = document.querySelector("#lab-gallery .carousel-inner");',
    '  if (!inner) return;',
    '  var items = Array.prototype.slice.call(inner.querySelectorAll(".carousel-item"));',
    '  if (items.length < 2) return;',
    '  for (var i = items.length - 1; i > 0; i--) {',          -- Fisher-Yates
    '    var j = Math.floor(Math.random() * (i + 1));',
    '    var t = items[i]; items[i] = items[j]; items[j] = t;',
    '  }',
    '  items.forEach(function (el) { el.classList.remove("active"); inner.appendChild(el); });',
    '  items[0].classList.add("active");',
    '})();',
    '</script>',
  }, "\n")

  return pandoc.RawBlock("html", html)
end

-- Read metadata first, then walk the blocks, so captions are known by the
-- time the placeholder div is reached.
function Pandoc(doc)
  local captions = {}
  local meta = doc.meta["slideshow-captions"]
  if meta then
    for name, value in pairs(meta) do
      captions[name] = pandoc.utils.stringify(value)
    end
  end

  doc.blocks = doc.blocks:walk({
    Div = function(el)
      if el.identifier == "lab-slideshow" then
        return build_carousel(captions)
      end
    end,
  })
  return doc
end

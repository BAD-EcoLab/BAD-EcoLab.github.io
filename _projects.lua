--[[
  _projects.lua — turns the project list on research.qmd into a row of
  clickable tiles above a single display area, so visitors pick a project
  instead of scrolling past the others to reach it.

  research.qmd wraps the projects in a div with the id `research-projects`.
  Inside it, every heading starts a new project, and everything after the
  heading (up to the next one) is that project's content. The project's
  first image becomes its tile picture and sits beside the text in the
  display area.

  Optional heading attributes, e.g.
    ### Forest and fire ecology {#fire-ecology short="Fire ecology"}
      #id     link straight to this project: research.html#fire-ecology
      short   label for the tile (defaults to the full heading)
      thumb   picture for the tile (defaults to the project's own image)

  The tiles are Bootstrap tabs (Bootstrap ships with every Quarto site), so
  clicking and arrow-key navigation need no custom code. The script emitted
  at the end only drives the Previous / Next buttons and keeps the address
  bar pointing at the open project so it can be linked to.
]]

local CONTAINER_ID = "research-projects"

local function esc(s)
  return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

-- Render inline markdown (e.g. an italic species name) as an HTML fragment.
local function inlines_html(inlines)
  return (pandoc.write(pandoc.Pandoc({ pandoc.Plain(inlines) }), "html"):gsub("%s+$", ""))
end

-- A block that is just one picture: a captioned figure, or a paragraph
-- holding a single image (what an uncaptioned ![](file.jpg) becomes).
local function is_picture(block)
  if block.t == "Figure" then
    return true
  end
  if block.t ~= "Para" and block.t ~= "Plain" then
    return false
  end
  local images = 0
  for _, inline in ipairs(block.content) do
    if inline.t == "Image" then
      images = images + 1
    elseif inline.t ~= "Space" and inline.t ~= "SoftBreak" then
      return false
    end
  end
  return images == 1
end

local function picture_src(block)
  local src
  block:walk({ Image = function(img) src = src or img.src end })
  return src
end

-- Split the container at its top-level headings. Anything before the first
-- heading is kept and shown above the tiles.
local function split(blocks)
  local level = math.huge
  for _, b in ipairs(blocks) do
    if b.t == "Header" and b.level < level then
      level = b.level
    end
  end

  local intro, projects = pandoc.List(), {}
  for _, b in ipairs(blocks) do
    if b.t == "Header" and b.level == level then
      table.insert(projects, { header = b, body = pandoc.List() })
    elseif #projects == 0 then
      intro:insert(b)
    else
      local p = projects[#projects]
      if not p.picture and is_picture(b) then
        p.picture = b
      else
        p.body:insert(b)
      end
    end
  end
  return intro, projects
end

local function tile_html(p, i)
  local h = p.header
  local short = h.attributes.short
  local label = (short and short ~= "")
    and inlines_html(pandoc.utils.blocks_to_inlines(pandoc.read(short, "markdown").blocks))
    or inlines_html(h.content)
  local thumb = h.attributes.thumb or (p.picture and picture_src(p.picture))

  return table.concat({
    string.format(
      '<button type="button" class="project-tile%s" id="tile-%s" role="tab" '
        .. 'data-bs-toggle="tab" data-bs-target="#%s" aria-controls="%s" aria-selected="%s"%s>',
      i == 1 and " active" or "", esc(p.id), esc(p.id), esc(p.id),
      i == 1 and "true" or "false", i == 1 and "" or ' tabindex="-1"'),
    -- The label names the project, so the picture itself is decorative.
    thumb and string.format('<img src="%s" alt="" decoding="async">', esc(thumb))
      or '<span class="project-tile-img" aria-hidden="true"></span>',
    '<span class="project-tile-label">' .. label .. "</span>",
    "</button>",
  }, "\n")
end

local function pager_html(projects, i)
  local n = #projects
  local prev = projects[(i - 2) % n + 1]
  local nxt = projects[i % n + 1]
  return table.concat({
    '<nav class="project-pager" aria-label="More projects">',
    string.format(
      '<button type="button" class="btn btn-outline-primary btn-sm" data-project-go="%s" '
        .. 'aria-label="Previous project: %s">&lsaquo; Previous</button>',
      esc(prev.id), esc(pandoc.utils.stringify(prev.header.content))),
    string.format('<span class="project-count">%d of %d</span>', i, n),
    string.format(
      '<button type="button" class="btn btn-outline-primary btn-sm" data-project-go="%s" '
        .. 'aria-label="Next project: %s">Next &rsaquo;</button>',
      esc(nxt.id), esc(pandoc.utils.stringify(nxt.header.content))),
    "</nav>",
  }, "\n")
end

local function panel(p, i, projects)
  local heading = p.header:clone()
  heading.identifier = "" -- the id moves to the panel so #id links open it
  heading.attributes.short = nil
  heading.attributes.thumb = nil

  local body = pandoc.Div({}, pandoc.Attr("", { "project-body" }))
  if p.picture then
    body.content:insert(pandoc.Div({ p.picture }, pandoc.Attr("", { "project-image" })))
  else
    body.classes:insert("no-image")
  end
  body.content:insert(pandoc.Div(p.body, pandoc.Attr("", { "project-text" })))

  local content = pandoc.List({ heading, body })
  if #projects > 1 then
    content:insert(pandoc.RawBlock("html", pager_html(projects, i)))
  end

  local classes = { "tab-pane", "fade", "project-panel" }
  if i == 1 then
    table.insert(classes, "show")
    table.insert(classes, "active")
  end
  return pandoc.Div(content, pandoc.Attr(p.id, classes, {
    role = "tabpanel",
    ["aria-labelledby"] = "tile-" .. p.id,
  }))
end

local SCRIPT = [[
<noscript><style>
  /* Without JavaScript the tabs cannot switch, so list every project. */
  .research-projects .project-tiles, .research-projects .project-pager { display: none; }
  .research-projects .tab-content > .tab-pane { display: block !important; opacity: 1; margin-bottom: 2rem; }
</style></noscript>
<script>
document.addEventListener("DOMContentLoaded", function () {
  var root = document.getElementById("research-projects");
  if (!root || !window.bootstrap) return;
  var panels = root.querySelector(".project-panels");

  // Open a project by id. With `reveal`, scroll back up to it if it is out
  // of view, e.g. after pressing Next at the bottom of a long project.
  function show(id, reveal) {
    var tile = root.querySelector('.project-tile[data-bs-target="#' + CSS.escape(id) + '"]');
    if (!tile) return;
    bootstrap.Tab.getOrCreateInstance(tile).show();
    var top = panels.getBoundingClientRect().top;
    if (reveal && (top < 0 || top > window.innerHeight * 0.6)) {
      panels.scrollIntoView({ behavior: "smooth" });
    }
  }

  root.addEventListener("click", function (e) {
    var btn = e.target.closest("[data-project-go]");
    if (btn) show(btn.getAttribute("data-project-go"), true);
  });

  // Keep the address bar on the open project so it can be shared. This
  // replaces the URL rather than adding history, so Back still leaves the page.
  root.addEventListener("shown.bs.tab", function (e) {
    history.replaceState(null, "", e.target.getAttribute("data-bs-target"));
  });

  // research.html#some-project opens that project, as does any in-page link.
  function fromHash(reveal) {
    var id = decodeURIComponent(location.hash.slice(1));
    if (id) show(id, reveal);
  }
  fromHash(false);
  window.addEventListener("hashchange", function () { fromHash(true); });
});
</script>
]]

local function build(div)
  local intro, projects = split(div.content)
  if #projects == 0 then
    io.stderr:write("[projects] no headings inside #" .. CONTAINER_ID .. " — left as is\n")
    return nil
  end
  io.stderr:write("[projects] " .. #projects .. " projects\n")

  for i, p in ipairs(projects) do
    p.id = p.header.identifier ~= "" and p.header.identifier or ("project-" .. i)
  end

  local out = pandoc.List(intro)
  if #projects > 1 then
    local tiles = {}
    for i, p in ipairs(projects) do
      table.insert(tiles, tile_html(p, i))
    end
    out:insert(pandoc.RawBlock("html",
      '<div class="project-tiles" role="tablist" aria-label="Research projects">\n'
        .. table.concat(tiles, "\n") .. "\n</div>"))
  end

  local panels = pandoc.List()
  for i, p in ipairs(projects) do
    panels:insert(panel(p, i, projects))
  end
  out:insert(pandoc.Div(panels, pandoc.Attr("", { "tab-content", "project-panels" })))
  out:insert(pandoc.RawBlock("html", SCRIPT))

  return pandoc.Div(out, pandoc.Attr(CONTAINER_ID, { "research-projects" }))
end

function Div(el)
  if el.identifier == CONTAINER_ID then
    return build(el)
  end
end

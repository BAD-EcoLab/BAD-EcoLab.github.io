# BAD Ecology Lab Website

A [Quarto](https://quarto.org) website template for the lab, set up to
auto-build and deploy to GitHub Pages on every push to `main`.

## One-time setup

1. **Create the repo.** In the `BAD-EcoLab` GitHub organization, create a new
   repository named `BAD-EcoLab.github.io` (this exact name gives you the
   cleanest URL: `https://bad-ecolab.github.io`).
2. **Push this template** to that repo:
   ```bash
   cd ecolab-site
   git init
   git add .
   git commit -m "Initial site template"
   git branch -M main
   git remote add origin https://github.com/BAD-EcoLab/BAD-EcoLab.github.io.git
   git push -u origin main
   ```
3. **Allow the workflow to publish.** In the repo, go to
   **Settings → Actions → General → Workflow permissions** and select
   **"Read and write permissions."** This lets the included GitHub Action
   push the built site to a `gh-pages` branch.
4. **Push once** (the commit above already counts) and check the
   **Actions** tab — you should see a "Render and Publish" run. It will
   create a `gh-pages` branch automatically.
5. **Turn on Pages.** Go to **Settings → Pages**, and under "Build and
   deployment," set **Source: Deploy from a branch**, and **Branch:
   gh-pages / (root)**. Save.
6. Wait a minute or two, then visit `https://bad-ecolab.github.io`.

You only need to do steps 1, 3, and 5 once. After that, every push to
`main` automatically rebuilds and redeploys the site.

## Day-to-day editing

- Each page is a `.qmd` file (`index.qmd`, `people.qmd`, `research.qmd`,
  `publications.qmd`, `news.qmd`, `contact.qmd`) — plain Markdown with a
  YAML header, just like R Markdown.
- To add a publication, add a new entry to `references.bib` — the
  Publications page rebuilds itself from that file.
- To add a lab member, copy an existing entry block in `people.qmd`.
- Put photos in the `images/` folder and reference them as
  `images/yourfile.jpg`.
- Site-wide settings (navbar links, title, theme) live in `_quarto.yml`.

Once you edit and push, GitHub Actions rebuilds and redeploys the site
automatically within a minute or two — no local rendering required.

## Previewing changes before you push (optional)

If you have Quarto installed locally (it ships with recent RStudio, or
install from [quarto.org](https://quarto.org/docs/get-started/)), you can
preview changes before committing:

```bash
quarto preview
```

This opens a live-reloading local preview in your browser.

## Placeholders to replace

Search the project for `[` to find bracketed placeholder text: department
name, university, bios, research descriptions, and contact details.
Replace `images/placeholder-headshot.png` references with real photos.

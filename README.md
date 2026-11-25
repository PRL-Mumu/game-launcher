# game-launcher documentation site

A guide documentation site for
[game-launcher](https://github.com/PRL-Mumu/game-launcher), built entirely in
Common Lisp.

## Stack

- **[3bmd](https://github.com/3b/3bmd)** parses Markdown into HTML, with the
  fenced-code-block and table extensions.
- **[Spinneret](https://github.com/ruricolist/spinneret)** renders the shared
  page layout.
- **[Hunchentoot](https://edicl.github.io/hunchentoot/)** serves a local
  preview of the generated static site.

The output is plain static HTML, CSS, and JavaScript, so it can be deployed to
any static host. No Lisp server is needed in production.

## Build

The project lives in `~/common-lisp`, which ASDF searches by default. From this
directory:

```sh
make build
```

The generated site is written to `docs/`. Open `docs/index.html`, or serve it
with any static file server.

If ASDF cannot find the system, link the project into Quicklisp's local
projects directory:

```sh
ln -s ~/common-lisp/game-launcher-docs ~/quicklisp/local-projects/game-launcher-docs
```

## Preview

```sh
make serve
```

This rebuilds the site and serves it at <http://127.0.0.1:4173/> using
Hunchentoot. Use `Ctrl-C` to stop the server.

To choose another port, load the system and call the function directly:

```common-lisp
(asdf:load-system :game-launcher-docs)
(game-launcher-docs:serve-site :port 8080)
```

## Layout

```text
game-launcher-docs/
├── game-launcher-docs.asd   ASDF system
├── build.lisp               Static build entry point
├── serve.lisp               Hunchentoot preview entry point
├── Makefile
├── content/                 One Markdown file per page
│   ├── index.md
│   ├── getting-started.md
│   ├── cli.md
│   ├── store.md
│   ├── profiles.md
│   ├── runtimes.md
│   ├── phases.md
│   ├── importing.md
│   ├── extending.md
│   ├── library.md
│   ├── api.md
│   └── architecture.md
├── src/
│   ├── package.lisp
│   ├── site.lisp            Page manifest and paths
│   ├── render.lisp          Markdown rendering and HTML layout
│   └── build.lisp           Static build and preview server
└── static/
    ├── style.css
    ├── app.js
    └── favicon.svg
```

## Deployment

The generated site lives in `docs/`, so GitHub Pages can serve it directly from
that folder on the `docs` branch: select **Deploy from a branch**, choose the
`docs` branch and the `/docs` folder as the source. The builder writes a
`.nojekyll` file into `docs/` so Jekyll processing is skipped. All URLs are
relative, so the site works at a project path such as
`https://user.github.io/repo/`.

Alternatively, `.github/workflows/deploy.yml` builds the site with SBCL +
Quicklisp on every push to `main` and publishes `docs/` with the official
GitHub Pages Actions. In that case set the Pages source to **GitHub Actions**.

## Editing

- Add or reorder pages in `src/site.lisp` (`*pages*` and `*page-groups*`).
- Write page bodies as Markdown in `content/<slug>.md`. The page title and
  description come from `*pages*`, so content files should start with body
  text rather than a duplicate H1.
- Pages link to each other with plain relative URLs such as
  `getting-started.html`.
- Rebuild with `make build`. The builder copies `static/` into
  `docs/assets/` and writes one HTML file per page.

The Markdown parser is 3bmd (original Markdown, not CommonMark). Fenced code
blocks, tables, inline HTML, and the usual Markdown constructs work.

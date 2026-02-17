# Course Website (Hugo)

This Hugo site publishes the course content from `docs/course/`.

## Local Preview

From `sre/`:

```bash
./scripts/sync-course-to-hugo.sh
hugo server --source site -D
```

Open: `http://localhost:1313`

## Build

```bash
./scripts/sync-course-to-hugo.sh
hugo --source site --minify
```

Output folder: `site/public/`

## Cloudflare Pages Setup (`safeops.work`)

Create a Pages project and point it to this repository with:

- Build command:
  `./scripts/sync-course-to-hugo.sh && hugo --source site --minify`
- Build output directory:
  `site/public`
- Root directory:
  `sre`

Then attach custom domain:
- `safeops.work`
- `www.safeops.work` (optional)

In Cloudflare DNS, keep records proxied.

## Important

Do not edit generated files in `site/content/course/` manually.
Always edit source in `docs/course/`.

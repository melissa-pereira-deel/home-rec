import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';

// homerec.app — statically generated multilingual marketing site.
// English at root; other locales under subdirectories (see src/i18n/config.ts).
export default defineConfig({
  site: 'https://homerec.app',
  trailingSlash: 'ignore',
  integrations: [sitemap()],
});

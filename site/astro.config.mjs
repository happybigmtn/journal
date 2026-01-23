// @ts-check
import { defineConfig } from 'astro/config';
import netlify from '@astrojs/netlify';
import remarkSidenotes from './src/plugins/remark-sidenotes.mjs';
import remarkCollapse from './src/plugins/remark-collapse.mjs';

export default defineConfig({
  site: 'https://rizz.dad',
  output: 'server',
  adapter: netlify(),
  markdown: {
    shikiConfig: {
      theme: 'min-light'
    },
    remarkPlugins: [remarkSidenotes, remarkCollapse]
  }
});

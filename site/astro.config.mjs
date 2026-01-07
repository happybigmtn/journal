// @ts-check
import { defineConfig } from 'astro/config';
import remarkSidenotes from './src/plugins/remark-sidenotes.mjs';
import remarkCollapse from './src/plugins/remark-collapse.mjs';

export default defineConfig({
  site: 'https://rizz.dad',
  output: 'static',
  markdown: {
    shikiConfig: {
      theme: 'min-light'
    },
    remarkPlugins: [remarkSidenotes, remarkCollapse]
  }
});

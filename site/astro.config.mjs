// @ts-check
import { defineConfig } from 'astro/config';
import remarkSidenotes from './src/plugins/remark-sidenotes.mjs';

export default defineConfig({
  site: 'https://rizz.dad',
  output: 'static',
  markdown: {
    shikiConfig: {
      theme: 'min-light'
    },
    remarkPlugins: [remarkSidenotes]
  }
});

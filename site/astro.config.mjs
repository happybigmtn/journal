// @ts-check
import { defineConfig } from 'astro/config';

export default defineConfig({
  site: 'https://rizz.dad',
  output: 'static',
  markdown: {
    shikiConfig: {
      theme: 'min-light'
    }
  }
});

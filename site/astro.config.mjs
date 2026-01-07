// @ts-check
import { defineConfig } from 'astro/config';

export default defineConfig({
  site: 'https://happybigmtn.github.io',
  base: '/journal',
  output: 'static',
  markdown: {
    shikiConfig: {
      theme: 'min-light'
    }
  }
});

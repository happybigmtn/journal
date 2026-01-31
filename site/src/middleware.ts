import { defineMiddleware } from 'astro:middleware';

// Password protection disabled - site is now public
export const onRequest = defineMiddleware(async (context, next) => {
  return next();
});

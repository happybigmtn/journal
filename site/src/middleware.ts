import { defineMiddleware } from 'astro:middleware';

// SHA-256 hash of the password (computed server-side for security)
const PASSWORD_HASH = '20652c0645acc495c4a16105287bf3722d1ae9005840b8aec3885cdabeaee214';
const AUTH_COOKIE = 'journal_auth';

// Routes that don't require authentication
const PUBLIC_ROUTES = ['/login'];

async function hashPassword(password: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(password);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}

export const onRequest = defineMiddleware(async (context, next) => {
  const { pathname } = context.url;

  // Handle login form submission FIRST (before public route check)
  if (context.request.method === 'POST' && pathname === '/login') {
    try {
      const formData = await context.request.formData();
      const password = formData.get('password')?.toString() || '';
      const hash = await hashPassword(password);

      if (hash === PASSWORD_HASH) {
        // Set auth cookie and redirect to home
        context.cookies.set(AUTH_COOKIE, PASSWORD_HASH, {
          path: '/',
          httpOnly: true,
          secure: import.meta.env.PROD,
          sameSite: 'lax',
          maxAge: 60 * 60 * 24 * 30, // 30 days
        });

        return context.redirect('/');
      }

      // Wrong password - redirect back to login with error
      return context.redirect('/login?error=1');
    } catch (e) {
      return context.redirect('/login?error=1');
    }
  }

  // Allow public routes (GET requests only at this point)
  if (PUBLIC_ROUTES.some(route => pathname === route || pathname.startsWith(route + '/'))) {
    return next();
  }

  // Allow static assets (they're in /public and served directly)
  if (pathname.match(/\.(css|js|png|jpg|jpeg|gif|svg|ico|woff|woff2|ttf|json|xml|txt|webmanifest)$/)) {
    return next();
  }

  // Check for auth cookie
  const authCookie = context.cookies.get(AUTH_COOKIE);

  if (authCookie?.value === PASSWORD_HASH) {
    // User is authenticated
    return next();
  }

  // Not authenticated - redirect to login
  return context.redirect('/login');
});

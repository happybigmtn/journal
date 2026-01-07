/**
 * Generates a JSON file with entry previews for link popup functionality
 * Used by the client-side link preview popup system
 */

import type { APIRoute } from 'astro';
import { getCollection } from 'astro:content';

export const GET: APIRoute = async () => {
  const entries = await getCollection('journal', ({ data }) =>
    !data.draft && (import.meta.env.DEV || data.published)
  );

  const previews: Record<string, {
    title: string;
    date: string;
    type: string;
    mood: string | null;
    excerpt: string;
    tags: string[];
  }> = {};

  for (const entry of entries) {
    // Extract first paragraph as excerpt
    const body = entry.body;
    // Skip frontmatter and find first non-empty paragraph
    const lines = body.split('\n');
    let excerpt = '';

    for (const line of lines) {
      const trimmed = line.trim();
      // Skip headers, empty lines, frontmatter markers, and comments
      if (
        trimmed.startsWith('#') ||
        trimmed.startsWith('---') ||
        trimmed.startsWith('<!--') ||
        trimmed.startsWith('>') ||
        trimmed.startsWith('-') ||
        trimmed.startsWith('*') ||
        trimmed.startsWith('1.') ||
        trimmed === ''
      ) {
        continue;
      }

      // Found a paragraph
      excerpt = trimmed.slice(0, 200);
      if (trimmed.length > 200) excerpt += '...';
      break;
    }

    // Use slug as key for fast lookup
    previews[entry.slug] = {
      title: entry.data.title,
      date: entry.data.date.toISOString().split('T')[0],
      type: entry.data.type,
      mood: entry.data.mood || null,
      excerpt,
      tags: entry.data.tags || [],
    };
  }

  return new Response(JSON.stringify(previews), {
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'max-age=3600',
    },
  });
};

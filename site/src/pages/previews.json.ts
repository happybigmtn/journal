/**
 * Generates a JSON file with entry previews for link popup functionality
 * Used by the client-side link preview popup system
 * Includes backlink counts for bidirectional navigation
 */

import type { APIRoute } from 'astro';
import { getCollection } from 'astro:content';

// Extract internal entry links from markdown content
function extractInternalLinks(body: string): string[] {
  const links: string[] = [];
  const linkRegex = /\[([^\]]+)\]\(\/(\d{4}\/\d{2}\/\d{2})(#[^)]+)?\)/g;
  let match;
  while ((match = linkRegex.exec(body)) !== null) {
    links.push(match[2]);
  }
  return [...new Set(links)];
}

export const GET: APIRoute = async () => {
  const entries = await getCollection('journal', ({ data }) =>
    !data.draft && (import.meta.env.DEV || data.published)
  );

  // First pass: collect all outgoing links
  const outgoingLinks: Record<string, string[]> = {};
  for (const entry of entries) {
    outgoingLinks[entry.slug] = extractInternalLinks(entry.body);
  }

  // Second pass: compute backlink counts
  const backlinkCounts: Record<string, number> = {};
  for (const entry of entries) {
    backlinkCounts[entry.slug] = 0;
  }
  for (const [sourceSlug, targetSlugs] of Object.entries(outgoingLinks)) {
    for (const targetSlug of targetSlugs) {
      if (backlinkCounts[targetSlug] !== undefined) {
        backlinkCounts[targetSlug]++;
      }
    }
  }

  const previews: Record<string, {
    title: string;
    date: string;
    type: string;
    mood: string | null;
    excerpt: string;
    tags: string[];
    backlinkCount: number;
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
      backlinkCount: backlinkCounts[entry.slug] || 0,
    };
  }

  return new Response(JSON.stringify(previews), {
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'max-age=3600',
    },
  });
};

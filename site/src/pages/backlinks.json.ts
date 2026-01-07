/**
 * Generates a JSON file with bidirectional backlinks data
 * Maps each entry to entries that reference it, with context snippets
 */

import type { APIRoute } from 'astro';
import { getCollection } from 'astro:content';

// Extract internal entry links from markdown content
function extractInternalLinks(body: string): string[] {
  const links: string[] = [];

  // Match markdown links: [text](/YYYY/MM/DD) or [text](/YYYY/MM/DD#section)
  const linkRegex = /\[([^\]]+)\]\(\/(\d{4}\/\d{2}\/\d{2})(#[^)]+)?\)/g;
  let match;

  while ((match = linkRegex.exec(body)) !== null) {
    links.push(match[2]); // Just the slug part (YYYY/MM/DD)
  }

  return [...new Set(links)]; // Deduplicate
}

// Extract context snippet around a link to a specific slug
function extractContextSnippet(body: string, targetSlug: string): string {
  // Find the link in the body
  const linkPattern = new RegExp(
    `[^.!?\\n]*\\[([^\\]]+)\\]\\(\\/${targetSlug.replace(/\//g, '\\/')}(#[^)]+)?\\)[^.!?\\n]*[.!?]?`,
    'i'
  );

  const match = body.match(linkPattern);
  if (match) {
    // Clean up the snippet - remove markdown syntax
    let snippet = match[0]
      .replace(/\[([^\]]+)\]\([^)]+\)/g, '$1') // Replace links with just text
      .replace(/[*_~`]/g, '') // Remove emphasis markers
      .trim();

    // Limit length
    if (snippet.length > 150) {
      snippet = snippet.slice(0, 147) + '...';
    }

    return snippet;
  }

  return '';
}

export const GET: APIRoute = async () => {
  const entries = await getCollection('journal', ({ data }) =>
    !data.draft && (import.meta.env.DEV || data.published)
  );

  // First pass: collect all outgoing links per entry
  const outgoingLinks: Record<string, string[]> = {};
  const entryBodies: Record<string, string> = {};
  const entryMetadata: Record<string, { title: string; date: string; type: string }> = {};

  for (const entry of entries) {
    outgoingLinks[entry.slug] = extractInternalLinks(entry.body);
    entryBodies[entry.slug] = entry.body;
    entryMetadata[entry.slug] = {
      title: entry.data.title,
      date: entry.data.date.toISOString().split('T')[0],
      type: entry.data.type,
    };
  }

  // Second pass: invert to get backlinks (who links to me?)
  const backlinks: Record<string, Array<{
    slug: string;
    title: string;
    date: string;
    type: string;
    context: string;
  }>> = {};

  // Initialize empty arrays for all entries
  for (const entry of entries) {
    backlinks[entry.slug] = [];
  }

  // Build backlinks by inverting outgoing links
  for (const [sourceSlug, targetSlugs] of Object.entries(outgoingLinks)) {
    for (const targetSlug of targetSlugs) {
      // Only add if target exists in our collection
      if (backlinks[targetSlug]) {
        const context = extractContextSnippet(entryBodies[sourceSlug], targetSlug);
        const meta = entryMetadata[sourceSlug];

        backlinks[targetSlug].push({
          slug: sourceSlug,
          title: meta.title,
          date: meta.date,
          type: meta.type,
          context,
        });
      }
    }
  }

  // Sort backlinks by date (most recent first)
  for (const slug of Object.keys(backlinks)) {
    backlinks[slug].sort((a, b) => b.date.localeCompare(a.date));
  }

  return new Response(JSON.stringify(backlinks), {
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'max-age=3600',
    },
  });
};

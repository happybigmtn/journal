import rss from '@astrojs/rss';
import { getCollection } from 'astro:content';
import type { APIContext } from 'astro';

export async function GET(context: APIContext) {
  // Only include published entries in the RSS feed
  const entries = await getCollection('journal', ({ data }) =>
    !data.draft && data.published
  );

  // Sort by date descending (newest first)
  const sortedEntries = entries.sort((a, b) =>
    new Date(b.data.date).getTime() - new Date(a.data.date).getTime()
  );

  return rss({
    title: 'Journal',
    description: 'A record of days - thoughts, reflections, and observations',
    site: context.site!,
    items: sortedEntries.map((entry) => ({
      title: entry.data.title,
      pubDate: entry.data.date,
      description: entry.data.mood
        ? `${entry.data.mood} — ${entry.data.type} entry`
        : `${entry.data.type} journal entry`,
      link: `/${entry.slug}/`,
      categories: entry.data.tags,
    })),
    customData: `<language>en-us</language>`,
  });
}

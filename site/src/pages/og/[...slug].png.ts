import type { APIContext } from 'astro';
import { getCollection } from 'astro:content';
import satori from 'satori';
import sharp from 'sharp';

// JetBrains Mono font for the editorial aesthetic
const fontData = await fetch(
  'https://cdn.jsdelivr.net/npm/@fontsource/jetbrains-mono@5.0.20/files/jetbrains-mono-latin-500-normal.woff'
).then(res => res.arrayBuffer());

// Playfair Display for headings
const playfairData = await fetch(
  'https://cdn.jsdelivr.net/npm/@fontsource/playfair-display@5.0.28/files/playfair-display-latin-600-normal.woff'
).then(res => res.arrayBuffer());

export async function getStaticPaths() {
  // Only generate OG images for published entries
  const entries = await getCollection('journal', ({ data }) =>
    !data.draft && data.published
  );
  return entries.map(entry => ({
    params: { slug: entry.slug },
    props: { entry },
  }));
}

export async function GET({ props }: APIContext) {
  const { entry } = props as { entry: Awaited<ReturnType<typeof getCollection>>[0] };

  // Format date
  const date = entry.data.date;
  const formattedDate = date.toLocaleDateString('en-US', {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric'
  });

  // Get excerpt from body (first 150 chars, clean markdown)
  const excerpt = entry.body
    .replace(/---[\s\S]*?---/, '') // Remove frontmatter
    .replace(/```[\s\S]*?```/g, '') // Remove code blocks
    .replace(/[#*_~`\[\]()>|-]/g, '') // Remove markdown syntax
    .replace(/\n+/g, ' ') // Replace newlines with spaces
    .trim()
    .slice(0, 150) + '...';

  // Editorial OG card design: black border, large date, excerpt
  const svg = await satori(
    {
      type: 'div',
      props: {
        style: {
          display: 'flex',
          flexDirection: 'column',
          width: '100%',
          height: '100%',
          backgroundColor: '#FFFFFF',
          padding: '60px',
          fontFamily: 'JetBrains Mono',
          position: 'relative',
        },
        children: [
          // Inner border
          {
            type: 'div',
            props: {
              style: {
                position: 'absolute',
                top: '20px',
                left: '20px',
                right: '20px',
                bottom: '20px',
                border: '4px solid #000000',
                pointerEvents: 'none',
              },
            },
          },
          // Date - large, editorial style
          {
            type: 'div',
            props: {
              style: {
                fontFamily: 'JetBrains Mono',
                fontSize: '28px',
                fontWeight: 500,
                letterSpacing: '0.1em',
                textTransform: 'uppercase',
                color: '#000000',
                marginBottom: '24px',
              },
              children: formattedDate,
            },
          },
          // Thick rule
          {
            type: 'div',
            props: {
              style: {
                width: '120px',
                height: '4px',
                backgroundColor: '#000000',
                marginBottom: '32px',
              },
            },
          },
          // Title
          {
            type: 'div',
            props: {
              style: {
                fontFamily: 'Playfair Display',
                fontSize: '48px',
                fontWeight: 600,
                color: '#000000',
                lineHeight: 1.2,
                marginBottom: '24px',
                maxHeight: '180px',
                overflow: 'hidden',
              },
              children: entry.data.title,
            },
          },
          // Excerpt
          {
            type: 'div',
            props: {
              style: {
                fontFamily: 'JetBrains Mono',
                fontSize: '20px',
                color: '#525252',
                lineHeight: 1.5,
                flex: 1,
              },
              children: excerpt,
            },
          },
          // Bottom: mood and site name
          {
            type: 'div',
            props: {
              style: {
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
                marginTop: 'auto',
              },
              children: [
                entry.data.mood
                  ? {
                      type: 'div',
                      props: {
                        style: {
                          fontSize: '32px',
                        },
                        children: entry.data.mood,
                      },
                    }
                  : {
                      type: 'div',
                      props: {},
                    },
                {
                  type: 'div',
                  props: {
                    style: {
                      fontFamily: 'JetBrains Mono',
                      fontSize: '18px',
                      fontWeight: 500,
                      letterSpacing: '0.1em',
                      textTransform: 'uppercase',
                      color: '#525252',
                    },
                    children: 'rizz.dad',
                  },
                },
              ],
            },
          },
        ],
      },
    },
    {
      width: 1200,
      height: 630,
      fonts: [
        {
          name: 'JetBrains Mono',
          data: fontData,
          weight: 500,
          style: 'normal',
        },
        {
          name: 'Playfair Display',
          data: playfairData,
          weight: 600,
          style: 'normal',
        },
      ],
    }
  );

  // Convert SVG to PNG
  const png = await sharp(Buffer.from(svg)).png().toBuffer();

  return new Response(png, {
    headers: {
      'Content-Type': 'image/png',
      'Cache-Control': 'public, max-age=31536000, immutable',
    },
  });
}

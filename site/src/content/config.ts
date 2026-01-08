import { defineCollection, z } from 'astro:content';

// Daily vitals: quantitative health metrics (various scales)
// Using nullable() because empty YAML values parse as null
const vitalsSchema = z.object({
  sleep: z.number().min(0).max(100).nullable().optional(),      // 0-100 scale
  recovery: z.number().min(0).max(100).nullable().optional(),   // 0-100 scale
  physical: z.number().min(0).max(20).nullable().optional(),    // 0-20 scale
  energy: z.number().min(0).max(10).nullable().optional(),      // 0-10 scale
  stress: z.number().min(0).max(10).nullable().optional(),      // 0-10 scale
  mood: z.number().min(0).max(10).nullable().optional(),        // 0-10 scale
  focus: z.number().min(0).max(10).nullable().optional(),       // 0-10 scale
  nutrition: z.number().min(0).max(10).nullable().optional(),   // 0-10 scale
  kindness: z.number().min(0).max(10).nullable().optional(),    // 0-10 scale
}).optional();

const journal = defineCollection({
  type: 'content',
  schema: z.object({
    title: z.string(),
    date: z.coerce.date(),
    mood: z.string().optional(), // Emoji mood (for insights page)
    sleep_hours: z.number().min(0).max(24).nullable().optional(),
    tags: z.array(z.string()).default([]),
    type: z.enum(['daily', 'weekly', 'monthly', 'yearly', 'project', 'book', 'travel']).default('daily'),
    // Daily vitals - 10 quantitative health metrics
    vitals: vitalsSchema,
    // Project-specific fields
    project_status: z.enum(['active', 'paused', 'completed', 'archived']).optional(),
    // Book-specific fields
    author: z.string().optional(),
    rating: z.number().min(1).max(5).optional(),
    pages_read: z.number().optional(),
    total_pages: z.number().optional(),
    status: z.enum(['reading', 'finished', 'abandoned', 'want-to-read']).optional(),
    // Travel-specific fields
    location: z.string().optional(),
    trip_start: z.coerce.date().optional(),
    trip_end: z.coerce.date().optional(),
    draft: z.boolean().default(false),
    published: z.boolean().default(false), // Privacy: false = private, true = public on site
    og_image: z.string().optional(), // Custom Open Graph image URL (overrides auto-generated)
    invert_images: z.boolean().default(false), // Invert all images in this entry in dark mode (for diagrams/screenshots)
  }),
});

export const collections = { journal };

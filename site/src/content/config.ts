import { defineCollection, z } from 'astro:content';

// Daily vitals: 10 quantitative health metrics (1-10 scale)
// Using nullable() because empty YAML values parse as null
const vitalsSchema = z.object({
  sleep: z.number().min(1).max(10).nullable().optional(),
  recovery: z.number().min(1).max(10).nullable().optional(),
  energy: z.number().min(1).max(10).nullable().optional(),
  stress: z.number().min(1).max(10).nullable().optional(),
  mood: z.number().min(1).max(10).nullable().optional(),
  focus: z.number().min(1).max(10).nullable().optional(),
  physical: z.number().min(1).max(10).nullable().optional(),
  nutrition: z.number().min(1).max(10).nullable().optional(),
  kindness: z.number().min(1).max(10).nullable().optional(),
  exercise: z.number().min(1).max(10).nullable().optional(),
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

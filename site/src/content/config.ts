import { defineCollection, z } from 'astro:content';

// Daily vitals: 10 quantitative health metrics (1-10 scale)
const vitalsSchema = z.object({
  sleep: z.number().min(1).max(10).optional(),      // Sleep quality (1=terrible, 10=perfect)
  recovery: z.number().min(1).max(10).optional(),   // How recovered you feel
  energy: z.number().min(1).max(10).optional(),     // Overall energy level
  stress: z.number().min(1).max(10).optional(),     // Stress level (1=calm, 10=overwhelmed)
  mood: z.number().min(1).max(10).optional(),       // Emotional state
  focus: z.number().min(1).max(10).optional(),      // Mental clarity/concentration
  physical: z.number().min(1).max(10).optional(),   // Body wellness (aches, pain, comfort)
  nutrition: z.number().min(1).max(10).optional(),  // Food quality/choices
  kindness: z.number().min(1).max(10).optional(),   // Acts of kindness/compassion
  exercise: z.number().min(1).max(10).optional(),   // Physical activity intensity
}).optional();

const journal = defineCollection({
  type: 'content',
  schema: z.object({
    title: z.string(),
    date: z.coerce.date(),
    mood: z.string().optional(), // Emoji mood (for insights page)
    sleep_hours: z.number().min(0).max(24).optional(),
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

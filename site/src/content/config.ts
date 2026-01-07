import { defineCollection, z } from 'astro:content';

// Habit item schema: supports boolean (did/didn't) and numeric habits
const habitSchema = z.object({
  name: z.string(),
  done: z.boolean().optional(), // For boolean habits
  value: z.number().optional(), // For numeric habits (e.g., glasses of water)
  goal: z.number().optional(), // Optional goal for numeric habits
});

const journal = defineCollection({
  type: 'content',
  schema: z.object({
    title: z.string(),
    date: z.coerce.date(),
    mood: z.string().optional(),
    sleep_hours: z.number().min(0).max(24).optional(),
    energy: z.number().int().min(1).max(10).optional(),
    tags: z.array(z.string()).default([]),
    type: z.enum(['daily', 'weekly', 'monthly', 'yearly']).default('daily'),
    draft: z.boolean().default(false),
    published: z.boolean().default(false), // Privacy: false = private, true = public on site
    habits: z.array(habitSchema).default([]), // Optional habit tracking
    og_image: z.string().optional(), // Custom Open Graph image URL (overrides auto-generated)
  }),
});

export const collections = { journal };

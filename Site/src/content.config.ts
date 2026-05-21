import { defineCollection } from "astro:content";
import { glob } from "astro/loaders";
import { z } from "astro/zod";

const nonEmptyStringArray = z.array(z.string()).min(1);

const examples = defineCollection({
  loader: glob({
    base: "./src/content/examples",
    pattern: "**/*.md",
  }),
  schema: z.discriminatedUnion("kind", [
    z.object({
      authorizedSkills: nonEmptyStringArray,
      description: z.string(),
      directive: z.string(),
      forbiddenSkills: z.array(z.string()).default([]),
      kind: z.literal("contract"),
      kits: nonEmptyStringArray,
      order: z.number(),
      persona: z.string(),
      rootPath: z.string().min(1),
      routeSlug: z.string(),
      title: z.string(),
    }),
    z.object({
      authorizedSkills: z.array(z.string()).default([]),
      description: z.string(),
      directive: z.string().optional(),
      forbiddenSkills: z.array(z.string()).default([]),
      kind: z.literal("guidance"),
      kits: z.array(z.string()).default([]),
      order: z.number(),
      persona: z.string().optional(),
      rootPath: z.string().default(""),
      routeSlug: z.string(),
      title: z.string(),
    }),
  ]),
});

export const collections = {
  examples,
};

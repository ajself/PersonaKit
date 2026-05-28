import { defineCollection } from "astro:content";
import { glob } from "astro/loaders";
import { z } from "astro/zod";

const nonEmptyStringArray = z.array(z.string()).min(1);

const examples = defineCollection({
  loader: glob({
    base: "./src/content/examples",
    pattern: "**/*.md",
  }),
  schema: z.object({
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
});

export const collections = {
  examples,
};

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
    chooserDescription: z.string(),
    chooserTitle: z.string(),
    description: z.string(),
    directive: z.string(),
    forbiddenSkills: z.array(z.string()).default([]),
    kind: z.literal("contract"),
    kits: nonEmptyStringArray,
    order: z.number(),
    persona: z.string(),
    rootPath: z.string().min(1),
    routeSlug: z.string(),
    sourceFiles: z.array(z.object({
      label: z.string(),
      path: z.string().min(1),
    })).min(1),
    title: z.string(),
  }),
});

export const collections = {
  examples,
};

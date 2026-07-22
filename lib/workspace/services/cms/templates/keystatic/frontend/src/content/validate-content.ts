import { createReader } from "@keystatic/core/reader";

import keystaticConfig from "../../keystatic.config";

async function main() {
  const reader = createReader(process.cwd(), keystaticConfig);
  const articles = await reader.collections.articles.all();
  const errors: string[] = [];

  for (const { slug, entry } of articles) {
    if (entry.status === "published" && !entry.publishedAt) {
      errors.push(`${slug}: published articles require a publication date`);
    }

    if (entry.heroImage && !entry.heroImageAlt?.trim()) {
      errors.push(`${slug}: hero images require alt text`);
    }

    if (entry.seoImage && !entry.seoImageAlt?.trim()) {
      errors.push(`${slug}: social sharing images require alt text`);
    }
  }

  if (errors.length > 0) {
    console.error("Content validation failed.\n");
    for (const error of errors) {
      console.error(`- ${error}`);
    }
    process.exit(1);
  }

  console.log(`Validated ${articles.length} article(s).`);
}

main().catch((error) => {
  console.error("Content validation failed.\n");
  if (error instanceof Error) {
    console.error(error.message);
  } else {
    console.error(String(error));
  }
  process.exit(1);
});

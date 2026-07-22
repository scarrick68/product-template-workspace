import { config, fields, collection } from "@keystatic/core";

export default config({
  storage: {
    kind: "local"
  },
  collections: {
    articles: collection({
      label: "Articles",
      slugField: "slug",
      path: "content/articles/*/",
      columns: ["title", "status", "publishedAt"],
      schema: {
        title: fields.text({ label: "Title", validation: { isRequired: true } }),
        slug: fields.slug({ name: { label: "Slug" } }),
        summary: fields.text({ label: "Summary", multiline: true, validation: { isRequired: true } }),
        body: fields.markdoc({
          label: "Body",
          options: {
            image: {
              directory: "public/images/articles",
              publicPath: "/images/articles/"
            }
          }
        }),
        heroImage: fields.image({
          label: "Hero image",
          directory: "public/images/articles",
          publicPath: "/images/articles/"
        }),
        heroImageAlt: fields.text({ label: "Hero image alt", description: "Describe the image for screen readers." }),
        author: fields.text({ label: "Author", validation: { isRequired: true } }),
        status: fields.select({
          label: "Status",
          defaultValue: "draft",
          options: [
            { label: "Draft", value: "draft" },
            { label: "Review", value: "review" },
            { label: "Published", value: "published" }
          ]
        }),
        publishedAt: fields.date({
          label: "Published date",
          description: "Required before an article can be published."
        }),
        seoTitle: fields.text({
          label: "SEO title override",
          description: "Leave blank to use the article title."
        }),
        seoDescription: fields.text({
          label: "Meta description override",
          description: "Leave blank to use the article summary.",
          multiline: true
        }),
        seoImage: fields.image({
          label: "Social sharing image override",
          directory: "public/images/social",
          publicPath: "/images/social/"
        }),
        seoImageAlt: fields.text({ label: "Social sharing image alt text" })
      }
    })
  }
});

# Phase 1 log

## Item 1 — render all posts on the blog index

> This entry was reconstructed from `git diff web/pages/blog.js` after the original was lost. Two parallel agents were given this same log file to write to and the second one's read-then-write clobbered the first's entry. That was an orchestration defect, not the agent's. Each agent now gets its own log file.

**Tab rows read:** `01 Orphaned Pages`, all 10 data rows plus the header note. The tab's finding is that 10 live ranking pages are unreachable from any internal link.

**File touched:** `/Users/jessica/wrk/wrk-corp/wrk-marketing/web/pages/blog.js` — the only file changed.

**Root cause of the orphaning:** the index rendered only the first 5 posts, with the remaining 21 behind a client-side "Load more" button. A crawler executing no JavaScript sees 5 links, so 21 posts had no incoming internal link from anywhere on the site.

### Change 1 — the pagination state removed

Before:

```js
const POSTS_PER_PAGE = 5;
```

```js
const Blog = ({ posts }) => {
  const [visibleCount, setVisibleCount] = React.useState(POSTS_PER_PAGE);
  const hasMore = visibleCount < posts?.length;

  const loadMore = () => {
    setVisibleCount(visibleCount + POSTS_PER_PAGE);
  };
```

After — all three removed; `Blog` takes `posts` and renders.

### Change 2 — every post rendered

Before:

```jsx
        {posts.slice(0, visibleCount).map((post) => <BlogPost key={post._id} post={post} />)}
        {hasMore && (
          <Styled.LoadMoreWrapper>
            <ButtonNew
              type="button"
              label="Load more"
              size="medium"
              onClick={loadMore}
            />
          </Styled.LoadMoreWrapper>
        )}
```

After:

```jsx
        {posts.map((post) => <BlogPost key={post._id} post={post} />)}
```

### Change 3 — dead code removed

- `import ButtonNew from "../components/button-new";` — no longer used in this file
- `Styled.LoadMoreWrapper` styled component — no longer referenced

The GROQ query was already unbounded (`*[_type == "blogPost"]{...} | order(publishDate desc)`), so no query change was needed. All 26 posts were always fetched; only 5 were rendered.

### Result against tab 01

All 26 published posts now render as links on `/blog` in the server-rendered HTML. All 10 of the tab's orphaned URLs are among them, verified by running the page's own GROQ query against the live Sanity production dataset (`a6d1clb1`): 26 `blogPost` documents returned, every one with a non-null `slug`, `publishDate`, `featureImage` and `metaDescription`, and all 10 tab-01 slugs present including `best-job-board-software`.

### Not done / could not do

- No full `next build` run — see the node version question in `QUESTIONS-FOR-JESSICA.md`.
- The deployed response has not been checked; that needs the branch on a preview URL.

---

## Item 2 — related-posts module on the blog post template

**Tab rows read:** `01 Orphaned Pages`, all 10 data rows (A7:F16) plus the header block (A1, A2, A4, row 6). Read via `read-workbook.py "01 Orphaned"` output supplied in the task brief. Every row's `Recommended action` begins with "Link" / "Strengthen internal links"; row 7 (`problem-solving-interview-questions`) names "related posts" explicitly.

**File touched:** `/Users/jessica/wrk/wrk-corp/wrk-marketing/web/pages/blog/[slug].js` — the only file changed. No new component file: this template already declares its own local sub-components (`Quote`, `ImageRenderer`, `TableRenderer`, `YouTubeEmbed`) at the top and its `Styled` object at the bottom, so the module follows that in-file idiom rather than adding a neighbour under `web/components/`.

**Analogs read before writing:**
- `web/pages/blog.js` — GROQ projection + `| order(publishDate desc)`, `BlogPost` card, `Styled.Title` / `Styled.Excerpt` / `Styled.Date`, `Link href={\`/blog/${post.slug.current}\`}`
- `web/pages/blog/[slug].js` (whole file) — `Styled` object idiom, `const t = props.theme`, `label:` prefix, `t.mq[40|56|64|72]` breakpoint nesting
- `web/pages/changelog.js` — `const query = ...` + `sanity.fetch(query)` in `getStaticProps`, `Styled.Post` grid at `t.mq[56]`
- `web/components/blogSection.js`, `web/components/container.js` — padding that already wraps the post, so the module only adds its own `px(12)` at `t.mq[56]` to match `Styled.Columns`
- `web/styles/theme.js`, `web/styles/global.js` — confirmed `t.color.gray[200]`, `t.text.gray`, and that the global reset sets `a { text-decoration: none; color: inherit }`, which is why prose links in this file use `color: ... !important; text-decoration: underline !important`. The new module copies that form.
- `studio/schemas/blogPost.js` — confirmed the schema has **no** tag, category, or reference field. Fields are `featureImage`, `editorialTitle`, `pageTitle`, `slug`, `publishDate`, `metaDescription`, `content`.

---

### Change 1 — matching helpers added after `urlFor`

Before (end of the top block):

```js
const builder = imageUrlBuilder(sanity)

function urlFor(source) {
  return builder.image(source)
}
```

After — same block, then added:

```js
const RELATED_POST_COUNT = 3;

const STOP_WORDS = new Set([
  "and", "are", "but", "can", "for", "from", "had", "has", "have", "her", "his",
  "how", "into", "its", "not", "our", "out", "she", "than", "that", "the",
  "their", "them", "then", "there", "these", "they", "this", "was", "were",
  "what", "when", "which", "who", "why", "will", "with", "you", "your",
]);

const topicWords = (blogPost) => new Set(
  `${blogPost.editorialTitle} ${blogPost.metaDescription}`
    .toLowerCase()
    .match(/[a-z]{3,}/g)
    ?.filter((word) => !STOP_WORDS.has(word))
);

// ponytail: title + meta-description word overlap, each shared word weighted by
// how rare it is across the blog, stands in for a taxonomy the blogPost schema
// does not have; swap for real references if one is added.
const relatedTo = (blogPost, otherBlogPosts) => {
  const words = topicWords(blogPost);
  const documentFrequency = {};
  for (const someBlogPost of [blogPost, ...otherBlogPosts]) {
    for (const word of topicWords(someBlogPost)) {
      documentFrequency[word] = (documentFrequency[word] || 0) + 1;
    }
  }

  return otherBlogPosts
    .map((otherBlogPost) => ({
      blogPost: otherBlogPost,
      score: [...topicWords(otherBlogPost)]
        .filter((word) => words.has(word))
        .reduce((total, word) => total + 1 / documentFrequency[word], 0),
    }))
    .sort((a, b) => b.score - a.score)
    .slice(0, RELATED_POST_COUNT)
    .map((scored) => scored.blogPost);
};
```

`RELATED_POST_COUNT = 3` mirrored `POSTS_PER_PAGE = 5` in `web/pages/blog.js`, and `?.` matched the existing `posts?.length` usage there. Both precedents were deleted by Item 1 in the same run, so the rationale no longer has a live analog to point at — the value of 3 stands on the master prompt's own "3 links minimum" instead.

### Change 2 — component signature

Before: `const BlogPost = ({ post }) => {`
After: `const BlogPost = ({ post, relatedPosts }) => {`

### Change 3 — module rendered inside `Styled.Post`, after `Styled.Columns`

Before:

```jsx
              </Styled.Sidebar>
            </Styled.Columns>
          </Styled.Post>
```

After:

```jsx
              </Styled.Sidebar>
            </Styled.Columns>
            {relatedPosts.length > 0 &&
              <Styled.Related>
                <h2>Keep reading</h2>
                <ul>
                  {relatedPosts.map((relatedPost) => (
                    <li key={relatedPost._id}>
                      <Link href={`/blog/${relatedPost.slug.current}`}>
                        {relatedPost.editorialTitle}
                      </Link>
                      <p>{relatedPost.metaDescription}</p>
                    </li>
                  ))}
                </ul>
              </Styled.Related>
            }
          </Styled.Post>
```

Placement rationale: `Styled.Post` carries `top: -${t.spacing[56]}` at `t.mq[56]`, so anything rendered *after* `</Styled.Post>` inside `Styled.Section` would land ~14rem below the visible end of the article. Rendering inside `Styled.Post` keeps the module in the white card, under the same offset.

`<Link>` with a bare string child is the form already used by `TableOfContents` in this file (`<Link href={slug}>{toPlainText(section)}</Link>`) — Next 12's `Link` wraps a string child in an `<a>` itself.

### Change 4 — sibling fetch in `getStaticProps`

Before:

```js
  const post = await sanity.fetch(`
    *[_type == "blogPost" && slug.current == $slug][0]
  `, { slug });

  return {
    props: { post }
  };
```

After:

```js
  const post = await sanity.fetch(`
    *[_type == "blogPost" && slug.current == $slug][0]
  `, { slug });

  const otherPosts = await sanity.fetch(`
    *[_type == "blogPost" && slug.current != $slug]{
      _id,
      editorialTitle,
      publishDate,
      metaDescription,
      slug
    } | order(publishDate desc)
  `, { slug });

  return {
    props: { post, relatedPosts: relatedTo(post, otherPosts) }
  };
```

The current post is excluded in GROQ (`slug.current != $slug`), not in JS. `publishDate` is in the projection because in GROQ the `| order(...)` pipe runs on the projected objects — `web/pages/blog.js` projects it for the same reason. Ranking runs at build time so the page ships 3 posts of data, not all 25.

### Change 5 — `Styled.Related` appended to the `Styled` object

New, inserted before `Styled.Embed`:

```js
Styled.Related = styled.aside((props) => {
  const t = props.theme;
  return css`
    label: BlogPost_Related;
    ${[t.pt(8), t.pb(12)]};
    border-top: 1px solid ${t.color.gray[200]};

    ${t.mq[56]} {
      ${[t.px(12), t.pt(10), t.pb(16)]};
    }

    h2 {
      ${[t.text.bold, t.text.xl]};
      line-height: 1.3;

      ${t.mq[56]} {
        ${[t.text.xxl]};
      }
    }

    ul {
      ${[t.mt(6)]};
      display: grid;
      row-gap: ${t.spacing[6]};

      ${t.mq[56]} {
        ${[t.mt(8)]};
        grid-template-columns: repeat(3, 1fr);
        column-gap: ${t.spacing[8]};
      }

      ${t.mq[72]} {
        column-gap: ${t.spacing[12]};
      }
    }

    a {
      ${[t.text.bold, t.text.base]};
      line-height: 1.4;
      color: ${t.color.black} !important;
      text-decoration: underline !important;

      ${t.mq[64]} {
        ${[t.text.lg]};
      }
    }

    p {
      ${[t.mt(2), t.text.sm, t.text.gray]};
      line-height: 1.4;
    }
  `;
});
```

`px(12)` at `t.mq[56]` matches `Styled.Columns`'s `t.p(12)` so the module lines up with the article column. `column-gap` values copy `Styled.Post` in `web/pages/blog.js` (8 at `mq[56]`, wider at `mq[72]`).

---

### Matching approach and its limitation

**Approach.** `blogPost` has no tag, category, or reference field, and adding one is out of scope. The module ranks siblings by word overlap between `editorialTitle + metaDescription` of the current post and each sibling, with each shared word weighted `1 / documentFrequency(word)` across the 26-post corpus, so a word every hiring article uses ("hiring", "guide", "complete") counts for almost nothing and a discriminating word ("turnover", "onboarding", "bias", "agile") carries the match. Only editor-written fields are read — no relationship is invented anywhere.

**Limitation.** It is lexical, not semantic. Two posts about the same subject in different vocabulary ("attrition" vs "turnover") will not match, and it reads title + meta description only, not `content`. It also always returns 3 posts: if nothing overlaps, the top 3 are effectively the most recent siblings, since GROQ hands them over in `publishDate desc` order and `Array.prototype.sort` is stable. That is why the heading reads "Keep reading" rather than "Related articles" — the module never claims a relationship the data cannot support.

**Weighting was verified against live Sanity, not assumed.** The unweighted version returned generic-vocabulary matches (`interview-feedback-examples` → `employer-branding-steps`; `talent-acquisition` appeared in 5 of the 10 orphaned posts' lists). The rarity-weighted version produced, for the 10 tab-01 URLs:

| Orphaned post | Related posts chosen |
|---|---|
| `problem-solving-interview-questions` | `a-player`, `behavioral-interview-scoring-matrix`, `talent-acquisition` |
| `behavioral-interview-scoring-matrix` | `problem-solving-interview-questions`, `best-applicant-tracking-software`, `best-job-board-software` |
| `employee-turnover` | `onboarding`, `first-impression-bias`, `five-things-a-startup-should-keep-in-mind-when-hiring` |
| `interview-feedback-examples` | `employer-branding-steps`, `onboarding`, `post-jobs-with-whatjobs-across-500-partners` |
| `job-rejection-email` | `problem-solving-interview-questions`, `onboarding`, `behavioral-interview-scoring-matrix` |
| `a-player` | `talent-acquisition`, `problem-solving-interview-questions`, `talent-acquisition-vs-recruitment` |
| `agile-recruiting-process` | `four-steps-to-build-a-recruiting-strategy-for-your-startup`, `best-job-board-software`, `employer-branding-steps` |
| `talent-acquisition-vs-recruitment` | `four-steps-to-build-a-recruiting-strategy-for-your-startup`, `talent-acquisition`, `recruiting-generation-z` |
| `first-impression-bias` | `best-applicant-tracking-software`, `employee-turnover`, `a-player` |
| `best-job-board-software` | `best-applicant-tracking-software`, `agile-recruiting-process`, `post-jobs-with-whatjobs-across-500-partners` |

Two weakest pairs remaining: `interview-feedback-examples` → `employer-branding-steps` and `first-impression-bias` → `best-applicant-tracking-software`. Both are still hiring-adjacent, neither is nonsense, and both would be fixed by a real taxonomy.

### Verification run

Throwaway script at `/private/tmp/claude-501/-Users-jessica-claude-hub-wrk-marketing/ae83cb44-eb97-4453-99a4-0718b5a2e1c9/scratchpad/check-related.mjs` — scratchpad only, nothing written into the repo, no test file. It ran the exact GROQ query and the exact ranking function against live Sanity (dataset read from `web/.env.local`, read-only fetches). Results: 26 `blogPost` documents; 25 siblings returned for every one of the 10 tab-01 slugs; 3 related posts returned every time. All 10 tab-01 URLs exist in Sanity, including `best-job-board-software`, which the workbook lists as `Published: unknown`.

`./node_modules/.bin/eslint "pages/blog/[slug].js"` — clean, no errors or warnings.

### Not done / could not do

- No full `next build` run. Lint is clean and the query and ranging function were exercised against live Sanity, but the rendered layout has not been seen in a browser.
- One layout point to eyeball: at `t.mq[56]` `Styled.Columns` ends with `t.pb(20)` (5rem), so there is generous whitespace between the last paragraph and the module's top border. Reducing it would mean editing `Styled.Columns`, which is existing working layout, so it was left alone.

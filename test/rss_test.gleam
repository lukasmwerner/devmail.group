import rss

const feed_with_plain_text_description = "<rss version=\"2.0\"><channel><title>Example Feed</title><link>https://example.com/</link><item><title>Plain post</title><link>https://example.com/plain</link><description>A plain text description</description><guid>plain-guid</guid><pubDate>Mon, 01 Jan 2024 00:00:00 GMT</pubDate></item></channel></rss>"

const feed_with_xml_only_description = "<rss version=\"2.0\"><channel><title>Example Feed</title><link>https://example.com/</link><item><title>XML post</title><link>https://example.com/xml</link><description><p><strong>HTML-ish XML</strong></p></description><guid>xml-guid</guid><pubDate>Mon, 01 Jan 2024 00:00:00 GMT</pubDate></item></channel></rss>"

pub fn decodes_plain_text_description_test() {
  let assert Ok(rss.Rss(channel: rss.Channel(posts: [post], ..))) =
    rss.parse_feed(feed_with_plain_text_description, "Author")

  assert post.description == "A plain text description"
}

pub fn decodes_description_containing_xml_test() {
  let assert Ok(rss.Rss(channel: rss.Channel(posts: [post], ..))) =
    rss.parse_feed(feed_with_xml_only_description, "Author")

  assert post.description == ""
}

pub type Member {
  Member(name: String, rss: String)
}

pub fn members() -> List(Member) {
  [
    Member(name: "Byron Sharman", rss: "https://byronsharman.com/blog.xml"),
    Member(name: "Elijah Potter", rss: "https://elijahpotter.dev/rss.xml"),
    Member(name: "Micah Bird", rss: "https://www.micahbird.com/index.xml"),
    Member(name: "Lukas Werner", rss: "https://lukaswerner.com/feed.xml"),
  ]
}

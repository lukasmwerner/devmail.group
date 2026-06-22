import gleam/bytes_tree
import gleam/http/response.{type Response}
import gleam/int
import gleam/list
import gleam/string
import gleam/time/calendar
import gleam/time/timestamp
import mist.{type ResponseData}
import nakai
import nakai/attr
import nakai/html
import rss.{type Post}

fn format_date(t: timestamp.Timestamp) -> String {
  let #(date, _) = timestamp.to_calendar(t, calendar.utc_offset)
  calendar.month_to_string(date.month)
  <> " "
  <> int.to_string(date.day)
  <> ", "
  <> int.to_string(date.year)
}

fn truncate(content: String, length: Int) -> String {
  let trunc = string.drop_end(content, string.length(content) - length)
  trunc
  <> {
    case string.length(trunc) == string.length(content) {
      True -> ""
      False -> ".."
    }
  }
}

fn web_ring() -> html.Node {
  html.div([attr.class("webring")], [
    html.a_text(
      [attr.href("https://grantlemons.com/webring/prev?Referer=devmail.group")],
      "← Left",
    ),
    html.a_text(
      [
        attr.href(
          "https://github.com/grantlemons/webring-manager/blob/main/sitelist",
        ),
      ],
      "Webring",
    ),
    html.a_text(
      [attr.href("https://grantlemons.com/webring/next?Referer=devmail.group")],
      "Right →",
    ),
  ])
}

pub fn index(posts: List(Post)) -> Response(ResponseData) {
  let body =
    html.Html([attr.lang("en-us")], [
      html.Head([
        html.title("/dev/mail/*"),
        html.LeafElement("link", [
          attr.rel("stylesheet"),
          attr.href("/static/style.css"),
        ]),
        html.LeafElement("link", [
          attr.rel("icon"),
          attr.type_("image/png"),
          attr.Attr("sizes", "32x32"),
          attr.href("/static/favicon/32x32.png"),
        ]),
        html.LeafElement("link", [
          attr.rel("icon"),
          attr.type_("image/png"),
          attr.Attr("sizes", "16x16"),
          attr.href("/static/favicon/16x16.png"),
        ]),
      ]),
      html.Body([], [
        html.main([], [
          html.header([], [
            html.div([attr.class("center")], [
              html.img([attr.id("logo"), attr.src("/static/devmail.webp")]),
            ]),
            html.h1_text([], "/dev/mail/*"),
            html.p([], [
              html.Text("We're a group of passionate "),
              html.a_text(
                [
                  attr.href(
                    "https://lukaswerner.com/post/2026-05-27@genz-neoengineer",
                  ),
                ],
                "neoengineers",
              ),
              html.Text(
                " with a heavy lean towards computer science. Most of us met during our freshman year of college at ",
              ),
              html.a_text(
                [
                  attr.href("https://mines.edu"),
                ],
                "Colorado School of Mines",
              ),
              html.Text(" in 2023 through coursework and the Mines "),
              html.a_text(
                [
                  attr.href("https://acm.mines.edu"),
                ],
                "ACM chapter",
              ),
              html.Text(", and hackathons."),
            ]),
          ]),

          html.h2([], [
            html.Text("Recent Member Posts"),
            html.a([attr.href("/rss.xml")], [
              html.img([
                attr.src("/static/rss-solid.svg"),
                attr.style(
                  "height:1.2rem; display: inline; padding-left: 0.2em;",
                ),
              ]),
            ]),
          ]),
          html.div([attr.class("breakout")], [
            html.div([attr.class("posts")], [
              html.Fragment(
                posts
                |> list.map(fn(post) {
                  html.div(
                    [
                      attr.class("post"),
                    ],
                    [
                      html.a(
                        [
                          attr.href(post.link),
                        ],
                        [
                          {
                            case post.ogimg != "" {
                              True -> {
                                html.img([attr.src(post.ogimg)])
                              }
                              False -> html.Fragment([])
                            }
                          },
                          html.h3_text([], post.title),
                          html.p_text(
                            [],
                            "By: "
                              <> post.author
                              <> " Published: "
                              <> format_date(post.date),
                          ),
                          html.p_text([], truncate(post.description, 80)),
                        ],
                      ),
                    ],
                  )
                }),
              ),
            ]),
          ]),
          web_ring(),
        ]),
      ]),
    ])
    |> nakai.to_string()

  response.new(200)
  |> response.set_header("Content-Type", "text/html")
  |> response.set_body(bytes_tree.from_string(body) |> mist.Bytes)
}

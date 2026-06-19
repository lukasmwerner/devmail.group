import gleam/bytes_tree
import gleam/http/response.{type Response}
import gleam/int
import gleam/list
import gleam/time/calendar
import gleam/time/timestamp
import mist.{type ResponseData}
import nakai
import nakai/attr
import nakai/html
import rss.{type Post}

fn format_date(t: timestamp.Timestamp) -> String {
  let #(date, _) = timestamp.to_calendar(t, calendar.utc_offset)
  int.to_string(date.day)
  <> "/"
  <> { calendar.month_to_int(date.month) |> int.to_string() }
  <> "/"
  <> int.to_string(date.year)
}

pub fn index(posts: List(Post)) -> Response(ResponseData) {
  let body =
    html.Html([attr.lang("en-us")], [
      html.Head([html.title("/dev/mail/*")]),
      html.Body([], [
        html.div(
          [
            attr.style(
              "display: flex; flex-direction: column; align-items: center;",
            ),
          ],
          [
            html.div([attr.style("max-width: 80ch;")], [
              html.h1_text([], "/dev/mail/*"),
              html.h2_text([], "Recent Member Posts"),
              html.Fragment(
                posts
                |> list.map(fn(post) {
                  html.a(
                    [
                      attr.href(post.link),
                      attr.style(
                        "padding-left: 0.4rem; padding-right: 0.4rem; margin: 0.5em;"
                        <> "border: 1px solid rgb(209 213 219); "
                        <> "border-radius: 0.25rem; text-decoration: none;"
                        <> " color: black; display: block;",
                      ),
                    ],
                    [
                      html.h3_text([], post.title),
                      html.p_text(
                        [],
                        "By: "
                          <> post.author
                          <> " Published: "
                          <> format_date(post.date),
                      ),
                    ],
                  )
                }),
              ),
            ]),
          ],
        ),
      ]),
    ])
    |> nakai.to_string()

  response.new(200)
  |> response.set_header("Content-Type", "text/html")
  |> response.set_body(bytes_tree.from_string(body) |> mist.Bytes)
}

import gleam/dynamic/decode
import gleam/http/request
import gleam/httpc
import gleam/list
import gleam/order
import gleam/time/calendar
import gleam/time/timestamp.{type Timestamp}
import parsed_it/xml
import rfc1123

pub type Post {
  Post(
    title: String,
    author: String,
    description: String,
    id: String,
    date: Timestamp,
    link: String,
  )
}

pub type Channel {
  Channel(title: String, link: String, description: String, posts: List(Post))
}

pub type Rss {
  Rss(channel: Channel)
}

pub type RssError {
  HttpError
  ParseError
}

pub fn reverse_crono(a: Post, b: Post) -> order.Order {
  timestamp.compare(b.date, a.date)
}

pub fn make_feed(posts: List(Post)) -> String {
  xml.element(
    "rss",
    [#("xmlns:atom", "http://www.w3.org/2005/Atom"), #("version", "2.0")],
    [
      xml.element("channel", [], [
        xml.element("title", [], [xml.string("/dev/mail/* Aggregator")]),
        xml.element("link", [], [xml.string("https://devmail.group/")]),
        xml.element("description", [], [
          xml.string("An aggregator of blogs from the /dev/mail/* group."),
        ]),
        xml.element("language", [], [xml.string("en-us")]),
        xml.element(
          "atom:link",
          [
            #("href", "https://devmail.group/rss.xml"),
            #("rel", "self"),
            #("type", "application/rss+xml"),
          ],
          [],
        ),
        ..{
          posts
          |> list.map(fn(post) {
            xml.element("item", [], [
              xml.element("title", [], [xml.string(post.title)]),
              xml.element("pubDate", [], [
                xml.string(
                  post.date
                  |> timestamp.to_calendar(calendar.utc_offset)
                  |> fn(date_time) {
                    let #(date, _) = date_time
                    date
                  }
                  |> rfc1123.to_string,
                ),
              ]),
              xml.element("link", [], [xml.string(post.link)]),
              xml.element("guid", [], [xml.string(post.link)]),
            ])
          })
        }
      ]),
    ],
  )
  |> xml.to_string()
}

pub fn fetch_feed(url: String, author: String) -> Result(Rss, RssError) {
  let assert Ok(req) = request.to(url)
  case httpc.send(req) {
    Ok(resp) -> {
      case xml.parse(resp.body, rss_decoder(author)) {
        Ok(rss) -> Ok(rss)
        Error(e) -> {
          echo e
          Error(ParseError)
        }
      }
    }
    Error(e) -> {
      echo e
      Error(HttpError)
    }
  }
}

fn post_decoder(author: String) -> decode.Decoder(Post) {
  use title <- decode.subfield(["title", "$text"], decode.string)
  use link <- decode.subfield(["link", "$text"], decode.string)
  use description <- decode.subfield(["description", "$text"], decode.string)
  use id <- decode.subfield(["guid", "$text"], decode.string)
  use date_str <- decode.subfield(["pubDate", "$text"], decode.string)

  let assert Ok(rfc_date) = rfc1123.parse(date_str)
  let assert Ok(date) = rfc1123.to_timestamp(rfc_date)

  decode.success(Post(title:, author: author, description:, id:, date:, link:))
}

fn channel_decoder(author: String) -> decode.Decoder(Channel) {
  use title <- decode.subfield(["title", "$text"], decode.string)
  use link <- decode.subfield(["link", "$text"], decode.string)
  use posts <- decode.field(
    "item",
    decode.one_of(decode.list(post_decoder(author)), or: [
      post_decoder(author)
      |> decode.map(fn(post) { [post] }),
    ]),
  )
  decode.success(Channel(title:, link:, description: "", posts:))
}

fn rss_decoder(author: String) -> decode.Decoder(Rss) {
  use channel <- decode.field("channel", channel_decoder(author))
  decode.success(Rss(channel:))
}

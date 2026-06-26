import concurrent
import gleam/erlang/process
import gleam/http/request
import gleam/httpc
import gleam/list
import gleam/order
import gleam/otp/actor
import gleam/result
import gleam/time/duration
import gleam/time/timestamp
import members
import presentable_soup as soup
import rasa/table
import rss

pub fn make_fetcher() -> actor.Started(process.Subject(Message)) {
  let assert Ok(act) =
    actor.new_with_initialiser(60_000, fn(subject) {
      let cache =
        table.new()
        |> table.with_kind(table.Set)
        |> table.with_access(table.Public)
        |> table.build

      case fetch(cache, subject) {
        Ok(State(subject, _, expires, posts, top_n, _)) ->
          actor.initialised(State(
            subject:,
            cache:,
            expires:,
            posts:,
            top_n:,
            fetching: False,
          ))
          |> actor.returning(subject)
          |> Ok

        Error(e) -> {
          echo e
          panic
        }
      }
    })
    |> actor.on_message(handle_message)
    |> actor.start()
  act
}

pub type CacheData {
  CacheData(description: String, image_url: String)
}

pub type State {
  State(
    subject: process.Subject(Message),
    cache: table.Table(String, CacheData),
    expires: timestamp.Timestamp,
    posts: List(rss.Post),
    top_n: List(rss.Post),
    fetching: Bool,
  )
}

pub type Message {
  Stop
  NextState(State)
  FetchTopN(process.Subject(List(rss.Post)))
  Fetch(process.Subject(List(rss.Post)))
}

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  case message {
    Stop -> actor.stop()
    Fetch(client) -> {
      actor.send(client, state.posts)
      actor.continue(State(
        subject: state.subject,
        cache: state.cache,
        expires: state.expires,
        posts: state.posts,
        top_n: state.top_n,
        fetching: when_expires(state),
      ))
    }
    FetchTopN(client) -> {
      actor.send(client, state.top_n)
      actor.continue(State(
        subject: state.subject,
        cache: state.cache,
        expires: state.expires,
        posts: state.posts,
        top_n: state.top_n,
        fetching: when_expires(state),
      ))
    }
    NextState(next_state) -> actor.continue(next_state)
  }
}

fn when_expires(state: State) -> Bool {
  case timestamp.compare(state.expires, timestamp.system_time()) {
    order.Lt if !state.fetching -> {
      // fetch in background
      process.spawn_unlinked(fn() {
        case fetch(state.cache, state.subject) {
          Ok(next_state) -> {
            actor.send(state.subject, NextState(next_state))
            Nil
          }
          Error(e) -> {
            echo e
            Nil
          }
        }
      })
      // Refetching!
      True
    }
    _ -> False
  }
}

fn fetch(
  cache: table.Table(String, CacheData),
  subject,
) -> Result(State, rss.RssError) {
  let in = timestamp.system_time() |> timestamp.add(duration.minutes(15))

  let results = process.new_subject()
  members.members()
  |> list.map(fn(member) {
    process.spawn(fn() {
      case rss.fetch_feed(member.rss, member.name) {
        Ok(feed) -> {
          process.send(results, Ok(feed))
        }
        Error(e) -> {
          process.send(results, Error(e))
        }
      }
    })
  })

  use feeds <- result.try(
    members.members()
    |> list.map(fn(_) { process.receive_forever(results) })
    |> result.all(),
  )

  let top_n =
    feeds
    |> list.map(fn(feed: rss.Rss) { feed.channel.posts |> list.take(3) })
    |> list.flatten()
    |> concurrent.all(fn(post) {
      let #(desc, img) = case table.lookup(cache, post.link) {
        Ok(CacheData(desc, img)) -> {
          #(desc, img)
        }
        _ -> {
          case fetch_page(post.link) {
            Ok(page) -> {
              let desc =
                get_og_content("og:description", page, post.description)
              let img = get_og_content("og:image", page, "")
              let assert Ok(_) =
                table.insert_new(cache, post.link, CacheData(desc, img))
              #(desc, img)
            }
            Error(_) -> {
              #(post.description, "")
            }
          }
        }
      }

      rss.Post(
        title: post.title,
        author: post.author,
        description: desc,
        id: post.id,
        date: post.date,
        link: post.link,
        ogimg: img,
      )
    })
    |> list.sort(by: rss.reverse_crono)

  let posts =
    feeds
    |> list.map(fn(feed) { feed.channel.posts })
    |> list.flatten()
    |> list.sort(by: rss.reverse_crono)

  Ok(State(subject:, cache:, expires: in, posts:, top_n:, fetching: False))
}

fn fetch_page(page link: String) -> Result(String, _) {
  let assert Ok(req) = request.to(link)
  let req = req |> request.set_header("User-Agent", "devmail-fetcher/1.0")
  httpc.send(req)
  |> result.map(fn(resp) { resp.body })
}

fn get_og_content(
  tag: String,
  page document: String,
  default default: String,
) -> String {
  let results =
    soup.element([
      soup.with_tag("meta"),
      soup.with_attribute("property", tag),
    ])
    |> soup.return(soup.attributes())
    |> soup.scrape(document)

  case results {
    Ok(attrs) -> {
      let #(_, value) =
        list.find(attrs, fn(attr) {
          let #(name, _) = attr
          name == "content"
        })
        |> result.unwrap(#("content", ""))
      value
    }
    Error(_) -> default
  }
}

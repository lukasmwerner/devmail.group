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
import rss

pub fn make_fetcher() -> actor.Started(process.Subject(Message)) {
  let assert Ok(act) =
    actor.new({
      case fetch() {
        Ok(next_state) -> next_state
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

pub type State {
  State(
    expires: timestamp.Timestamp,
    posts: List(rss.Post),
    top_n: List(rss.Post),
  )
}

pub type Message {
  Stop
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
      when_expires(state, fetch)
    }
    FetchTopN(client) -> {
      actor.send(client, state.top_n)
      when_expires(state, fetch)
    }
  }
}

fn when_expires(
  state: State,
  make_next_state: fn() -> Result(State, rss.RssError),
) -> actor.Next(State, b) {
  case timestamp.compare(state.expires, timestamp.system_time()) {
    order.Lt -> {
      actor.continue({
        case make_next_state() {
          Ok(next_state) -> next_state
          Error(e) -> {
            echo e
            state
          }
        }
      })
    }
    _ -> actor.continue(state)
  }
}

fn fetch() -> Result(State, rss.RssError) {
  let in = timestamp.system_time() |> timestamp.add(duration.minutes(2))

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

  let feeds =
    members.members()
    |> list.map(fn(_) { process.receive_forever(results) })
    |> result.all()

  case feeds {
    Ok(feeds) -> {
      let top_n =
        feeds
        |> list.map(fn(feed) { feed.channel.posts |> list.take(3) })
        |> list.flatten()
        |> list.sort(by: rss.reverse_crono)
        |> list.map(fn(post) {
          let page = fetch_page(post.link)

          rss.Post(
            title: post.title,
            author: post.author,
            description: get_og_content(
              "og:description",
              page,
              post.description,
            ),
            id: post.id,
            date: post.date,
            link: post.link,
            ogimg: get_og_content("og:image", page, ""),
          )
        })

      let posts =
        feeds
        |> list.map(fn(feed) { feed.channel.posts })
        |> list.flatten()
        |> list.sort(by: rss.reverse_crono)

      Ok(State(expires: in, posts:, top_n:))
    }
    Error(e) -> Error(e)
  }
}

fn fetch_page(page link: String) -> String {
  let assert Ok(req) = request.to(link)
  case httpc.send(req) {
    Ok(resp) -> resp.body
    Error(_) -> ""
  }
}

fn get_og_content(
  tag: String,
  page document: String,
  default default: String,
) -> String {
  case
    soup.element([
      soup.with_tag("meta"),
      soup.with_attribute("property", tag),
    ])
    |> soup.return(soup.attributes())
    |> soup.scrape(document)
  {
    Ok(attrs) -> {
      let #(_, link) =
        list.find(attrs, fn(attr) {
          let #(name, _) = attr
          name == "content"
        })
        |> result.unwrap(#("content", ""))
      link
    }
    Error(_) -> default
  }
}

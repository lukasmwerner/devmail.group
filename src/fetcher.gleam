import gleam/erlang/process
import gleam/list
import gleam/order
import gleam/otp/actor
import gleam/time/duration
import gleam/time/timestamp
import members
import rss

pub fn make_fetcher() -> actor.Started(process.Subject(Message)) {
  let assert Ok(act) =
    actor.new(fetch())
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
  make_next_state: fn() -> State,
) -> actor.Next(State, b) {
  case timestamp.compare(state.expires, timestamp.system_time()) {
    order.Gt -> actor.continue(make_next_state())
    _ -> actor.continue(state)
  }
}

fn fetch() -> State {
  let in = timestamp.system_time() |> timestamp.add(duration.minutes(15))

  let feeds =
    members.members()
    |> list.map(fn(member) {
      case rss.fetch_feed(member.rss, member.name) {
        Ok(feed) -> feed
        Error(_) -> rss.Rss(rss.Channel(member.name, "", "", []))
      }
    })

  let top_n =
    feeds
    |> list.map(fn(feed) { feed.channel.posts |> list.take(3) })
    |> list.flatten()
    |> list.sort(by: rss.reverse_crono)

  let posts =
    feeds
    |> list.map(fn(feed) { feed.channel.posts })
    |> list.flatten()
    |> list.sort(by: rss.reverse_crono)

  State(expires: in, posts:, top_n:)
}

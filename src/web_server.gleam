import fetcher
import gleam/bytes_tree
import gleam/erlang/process
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/otp/actor
import gleam/otp/static_supervisor as supervisor
import index
import mist.{type Connection, type ResponseData}
import rss

pub fn serve(post_subject: process.Subject(fetcher.Message)) {
  let not_found =
    response.new(404)
    |> response.set_body(mist.Bytes(bytes_tree.new()))

  let handler = fn(req: Request(Connection)) -> Response(ResponseData) {
    case request.path_segments(req) {
      [] -> {
        let posts =
          actor.call(post_subject, waiting: 4000, sending: fetcher.FetchTopN)
        index.index(posts)
      }
      ["rss.xml"] -> {
        let posts =
          actor.call(post_subject, waiting: 4000, sending: fetcher.Fetch)

        response.new(200)
        |> response.set_header("Content-Type", "application/xml")
        |> response.set_body(
          bytes_tree.from_string(rss.make_feed(posts))
          |> mist.Bytes,
        )
      }
      _ -> not_found
    }
  }

  let server =
    handler
    |> mist.new
    |> mist.bind("0.0.0.0")
    |> mist.port(3000)
    |> mist.supervised

  let assert Ok(_) =
    supervisor.new(strategy: supervisor.OneForOne)
    |> supervisor.restart_tolerance(intensity: 100, period: 60)
    |> supervisor.add(server)
    |> supervisor.start

  process.sleep_forever()
}

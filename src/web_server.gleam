import fetcher
import filepath
import gleam/bytes_tree
import gleam/erlang/process
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/option
import gleam/otp/actor
import gleam/otp/static_supervisor as supervisor
import gleam/result
import index
import mimetype
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
      ["static", ..path] -> {
        let filename = path_join(["static", ..path])
        let assert Ok(resp) =
          mist.send_file(filename, offset: 0, limit: option.None)
        response.new(200)
        |> response.set_header(
          "Content-Type",
          mimetype.extension_to_mime_type(
            filepath.extension(filename) |> result.unwrap(""),
          )
            |> mimetype.to_string,
        )
        |> response.set_body(resp)
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

fn path_join(parts: List(String)) -> String {
  case parts {
    [] -> ""
    [single] -> single
    [head, ..rest] -> filepath.join(head, path_join(rest))
  }
}

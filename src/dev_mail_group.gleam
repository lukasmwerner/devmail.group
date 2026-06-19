import fetcher
import web_server

pub fn main() -> Nil {
  let post_fetcher = fetcher.make_fetcher()

  web_server.serve(post_fetcher.data)
}

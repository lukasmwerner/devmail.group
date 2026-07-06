import dot_env
import fetcher
import web_server

pub fn main() -> Nil {
  dot_env.load_default()
  let post_fetcher = fetcher.make_fetcher()

  web_server.serve(post_fetcher.data)
}

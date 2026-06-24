import gleam/erlang/process
import gleam/list

pub fn all(l: List(a), with fun: fn(a) -> b) -> List(b) {
  let subject = process.new_subject()
  list.each(l, fn(item) {
    process.spawn(fn() { process.send(subject, fun(item)) })
  })

  list.repeat(0, times: list.length(l))
  |> list.map(fn(_) { process.receive_forever(subject) })
}

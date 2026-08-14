import rfc1123

pub fn parse_time_zeros_test() {
  assert Ok(#(0, 0, 0)) == rfc1123.parse_time("00:00:00")
}

pub fn parse_time_evening_test() {
  assert Ok(#(21, 59, 0)) == rfc1123.parse_time("21:59:00")
}

pub fn to_string_test() {
  assert "Fri, 14 Aug 2026 20:20:39 GMT"
    == rfc1123.Date("Fri", 14, 8, 2026, 20, 20, 39, 0)
    |> rfc1123.to_string()
}

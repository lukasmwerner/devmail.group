import gleam/int
import gleam/result
import gleam/string
import gleam/time/calendar
import gleam/time/duration
import gleam/time/timestamp.{type Timestamp}

pub type Date {
  Date(
    weekday: String,
    day: Int,
    month: Int,
    year: Int,
    hour: Int,
    minute: Int,
    second: Int,
    offset_seconds: Int,
  )
}

pub fn parse(input: String) -> Result(Date, Nil) {
  // TODO: change type to Result(timestamp.Timestamp, Nil) so that less of the
  // logic is handled by rfc1123 itself and instead leans on gleam_time
  case string.split(input, " ") {
    [weekday, day, month, year, time, timezone] -> {
      case string.ends_with(weekday, ",") {
        False -> Error(Nil)
        True -> {
          use day <- result.try(int.parse(day))
          use month <- result.try(parse_month(month))
          use year <- result.try(int.parse(year))
          use #(hour, minute, second) <- result.try(parse_time(time))
          use offset_seconds <- result.try(parse_timezone(timezone))

          Ok(Date(
            weekday: string.drop_end(weekday, 1),
            day: day,
            month: month,
            year: year,
            hour: hour,
            minute: minute,
            second: second,
            offset_seconds: offset_seconds,
          ))
        }
      }
    }

    _ -> Error(Nil)
  }
}

pub fn to_string(date: calendar.Date) -> String {
  let month = calendar.month_to_int(date.month)

  weekday_to_string(date.year, month, date.day)
  <> ", "
  <> pad2(date.day)
  <> " "
  <> month_abbreviation(date.month)
  <> " "
  <> int.to_string(date.year)
  <> " 00:00:00 GMT"
}

pub fn to_timestamp(date: Date) -> Result(Timestamp, Nil) {
  use month <- result.try(calendar.month_from_int(date.month))

  case is_valid_date_time(date) {
    False -> Error(Nil)
    True ->
      Ok(timestamp.from_calendar(
        date: calendar.Date(year: date.year, month: month, day: date.day),
        time: calendar.TimeOfDay(
          hours: date.hour,
          minutes: date.minute,
          seconds: date.second,
          nanoseconds: 0,
        ),
        offset: duration.seconds(date.offset_seconds),
      ))
  }
}

fn pad2(number: Int) -> String {
  number
  |> int.to_string
  |> string.pad_start(to: 2, with: "0")
}

fn month_abbreviation(month: calendar.Month) -> String {
  month
  |> calendar.month_to_string
  |> string.slice(at_index: 0, length: 3)
}

fn weekday_to_string(year: Int, month: Int, day: Int) -> String {
  let adjusted_year = case month < 3 {
    True -> year - 1
    False -> year
  }

  case
    {
      adjusted_year
      + adjusted_year
      / 4
      - adjusted_year
      / 100
      + adjusted_year
      / 400
      + month_offset(month)
      + day
    }
    % 7
  {
    0 -> "Sun"
    1 -> "Mon"
    2 -> "Tue"
    3 -> "Wed"
    4 -> "Thu"
    5 -> "Fri"
    _ -> "Sat"
  }
}

fn month_offset(month: Int) -> Int {
  case month {
    1 -> 0
    2 -> 3
    3 -> 2
    4 -> 5
    5 -> 0
    6 -> 3
    7 -> 5
    8 -> 1
    9 -> 4
    10 -> 6
    11 -> 2
    12 -> 4
    _ -> 0
  }
}

fn parse_month(month: String) -> Result(Int, Nil) {
  case month {
    "Jan" -> Ok(1)
    "Feb" -> Ok(2)
    "Mar" -> Ok(3)
    "Apr" -> Ok(4)
    "May" -> Ok(5)
    "Jun" -> Ok(6)
    "Jul" -> Ok(7)
    "Aug" -> Ok(8)
    "Sep" -> Ok(9)
    "Oct" -> Ok(10)
    "Nov" -> Ok(11)
    "Dec" -> Ok(12)
    _ -> Error(Nil)
  }
}

fn is_valid_date_time(date: Date) -> Bool {
  let calendar_date_is_valid = case calendar.month_from_int(date.month) {
    Ok(month) ->
      calendar.is_valid_date(calendar.Date(date.year, month, date.day))
    Error(_) -> False
  }

  calendar_date_is_valid
  && date.hour >= 0
  && date.hour <= 23
  && date.minute >= 0
  && date.minute <= 59
  && date.second >= 0
  && date.second <= 59
}

fn parse_timezone(timezone: String) -> Result(Int, Nil) {
  case timezone {
    "GMT" -> Ok(0)
    "UT" -> Ok(0)
    "UTC" -> Ok(0)
    _ -> parse_numeric_timezone(timezone)
  }
}

fn parse_numeric_timezone(timezone: String) -> Result(Int, Nil) {
  case string.length(timezone) == 5 {
    False -> Error(Nil)
    True -> {
      let sign = string.slice(timezone, at_index: 0, length: 1)
      let hours = string.slice(timezone, at_index: 1, length: 2)
      let minutes = string.slice(timezone, at_index: 3, length: 2)

      use hours <- result.try(int.parse(hours))
      use minutes <- result.try(int.parse(minutes))

      case hours <= 23 && minutes <= 59 {
        False -> Error(Nil)
        True ->
          case sign {
            "+" -> Ok(hours * 3600 + minutes * 60)
            "-" -> Ok(0 - { hours * 3600 + minutes * 60 })
            _ -> Error(Nil)
          }
      }
    }
  }
}

fn parse_time(time: String) -> Result(#(Int, Int, Int), Nil) {
  case string.split(time, ":") {
    [hour, minute, second] -> {
      use hour <- result.try(int.parse(hour))
      use minute <- result.try(int.parse(minute))
      use second <- result.try(int.parse(second))
      Ok(#(hour, minute, second))
    }

    _ -> Error(Nil)
  }
}

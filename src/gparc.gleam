import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

pub type Tokens =
  List(String)

pub type Parser(a) =
  fn(Tokens) -> Result(a)

pub type Result(a) {
  Success(match: a, remaining: Tokens)
  Failure(error: String, input: Tokens)
}

pub fn char(expect: String) -> Parser(String) {
  fn(input: Tokens) -> Result(String) {
    case input {
      [got, ..remaining] if expect == got -> Success(got, remaining)
      [got, ..] ->
        Failure(
          "expected: "
            <> expect
            <> ", got: "
            <> got
            <> " in input "
            <> string.concat(input),
          input,
        )
      [] -> Failure("expect: " <> expect <> ", got empty input", input)
    }
  }
}

pub fn then(first: Parser(a), second: Parser(a)) -> Parser(#(a, a)) {
  fn(input: Tokens) -> Result(#(a, a)) {
    case first(input) {
      Failure(err, _) -> Failure(err, input)
      Success(match1, remaining) -> {
        case second(remaining) {
          Failure(err, _) -> Failure(err, input)
          Success(match2, remaining) -> Success(#(match1, match2), remaining)
        }
      }
    }
  }
}

pub fn or(first: Parser(a), second: Parser(a)) -> Parser(a) {
  fn(input: Tokens) -> Result(a) {
    case first(input) {
      Success(match, remaining) -> Success(match, remaining)
      Failure(err1, _) -> {
        case second(input) {
          Failure(err2, _) -> Failure("[" <> err1 <> ", " <> err2 <> "]", input)
          Success(match, remaining) -> Success(match, remaining)
        }
      }
    }
  }
}

pub fn map(parser: Parser(a), matcher: fn(a) -> b) -> Parser(b) {
  fn(input: Tokens) -> Result(b) {
    case parser(input) {
      Failure(err, _) -> Failure(err, input)
      Success(match, remaining) -> Success(matcher(match), remaining)
    }
  }
}

pub fn seq(parsers: List(Parser(a))) -> Parser(List(a)) {
  fn(input: Tokens) -> Result(List(a)) { seq_loop(input, parsers, []) }
}

fn seq_loop(
  input: Tokens,
  parsers: List(Parser(a)),
  acc: List(a),
) -> Result(List(a)) {
  case parsers {
    [] -> Success(acc, input)
    [parser, ..parsers] ->
      case parser(input) {
        Failure(err, _) -> Failure(err, input)
        Success(val, remaining) -> {
          let acc = list.append(acc, [val])
          seq_loop(remaining, parsers, acc)
        }
      }
  }
}

pub fn one_of(parsers: List(Parser(a))) -> Parser(a) {
  fn(input: Tokens) -> Result(a) { one_of_loop(input, parsers) }
}

fn one_of_loop(input: Tokens, parsers: List(Parser(a))) -> Result(a) {
  case parsers {
    [] ->
      Failure(
        "can't match any of expected for input: " <> string.concat(input),
        input,
      )
    [parser, ..parsers] ->
      case parser(input) {
        Success(val, remaining) -> Success(val, remaining)
        Failure(_, _) -> one_of_loop(input, parsers)
      }
  }
}

pub fn many(parser: Parser(a), times: Int) -> Parser(List(a)) {
  fn(input: Tokens) -> Result(List(a)) { many_loop(input, parser, times, []) }
}

fn many_loop(
  input: Tokens,
  parser: Parser(a),
  times: Int,
  acc: List(a),
) -> Result(List(a)) {
  case parser(input) {
    Failure(_, _) ->
      case list.length(acc) {
        val if val >= times -> Success(acc, input)
        _ ->
          Failure(
            "get less matches then " <> int.to_string(times) <> " times",
            input,
          )
      }
    Success(val, remaining) ->
      many_loop(remaining, parser, times, list.append(acc, [val]))
  }
}

pub fn opt(parser: Parser(a)) -> Parser(Option(a)) {
  fn(input: Tokens) -> Result(Option(a)) {
    case parser(input) {
      Failure(_, _) -> Success(None, input)
      Success(val, remaining) -> Success(Some(val), remaining)
    }
  }
}

pub fn on_error(
  parser: Parser(a),
  callback: fn(String, Tokens) -> String,
) -> Parser(a) {
  fn(input: Tokens) -> Result(a) {
    case parser(input) {
      Success(val, remaining) -> Success(val, remaining)
      Failure(err, _) -> Failure(callback(err, input), input)
    }
  }
}

pub fn from_string(str: String) -> List(Parser(String)) {
  str
  |> string.to_graphemes
  |> list.map(fn(ch) { char(ch) })
}

pub fn main() {
  let input =
    "-212312"
    |> string.to_graphemes

  let parser =
    on_error(
      map(
        seq([
          map(opt(one_of([char("+"), char("-")])), fn(res) {
            case res {
              None -> ""
              Some(val) -> val
            }
          }),
          map(many(one_of([char("1"), char("2"), char("3")]), 10), fn(vls) {
            string.concat(vls)
          }),
        ]),
        fn(vls) { string.concat(vls) },
      ),
      fn(_, tokens) {
        "integer should have lenght atleast 10, but got "
        <> string.concat(tokens)
      },
    )

  io.debug(parser(input))
}

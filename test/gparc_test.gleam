import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit
import gleeunit/should
import gparc

pub fn main() {
  gleeunit.main()
}

pub fn parse_char_test() {
  let test_cases = [#("abc", "a", "a"), #("12", "1", "1"), #("lol", "l", "l")]
  list.each(test_cases, fn(tc) {
    let parser = gparc.char(tc.1)
    case parser(string.to_graphemes(tc.0)) {
      gparc.Failure(err, _) -> panic as err
      gparc.Success(val, _) -> should.equal(val, tc.2)
    }
  })
}

pub fn int_parser_test() {
  // [0-9]+
  let parser = fn(input: String) -> gparc.Result(Int) {
    let tokens = string.to_graphemes(input)
    let inner_parser =
      gparc.map(
        gparc.many(gparc.one_of(gparc.from_string("0123456789")), 1),
        fn(vls) {
          let assert Ok(val) = int.parse(string.concat(vls))
          val
        },
      )
    inner_parser(tokens)
  }
  let test_cases = [#("1", 1), #("12", 12), #("123", 123)]
  list.each(test_cases, fn(tc) {
    case parser(tc.0) {
      gparc.Failure(err, _) -> panic as err
      gparc.Success(val, _) -> should.equal(val, tc.1)
    }
  })
}

pub fn ident_parser_test() {
  // _?[a-z_]+
  let parser = fn(input: String) -> gparc.Result(String) {
    let tokens = string.to_graphemes(input)
    let inner_parser =
      gparc.map(
        gparc.seq([
          gparc.map(gparc.opt(gparc.char("_")), fn(vl) {
            case vl {
              None -> ""
              Some(vl) -> vl
            }
          }),
          gparc.map(
            gparc.many(
              gparc.one_of(gparc.from_string("qwertyuiopasdfghjklzxcvbnm_")),
              1,
            ),
            fn(vls) { string.concat(vls) },
          ),
        ]),
        fn(vls) { string.concat(vls) },
      )
    inner_parser(tokens)
  }
  let test_cases = [
    #("alex", "alex"),
    #("some_name", "some_name"),
    #("_hello", "_hello"),
  ]
  list.each(test_cases, fn(tc) {
    case parser(tc.0) {
      gparc.Failure(err, _) -> panic as err
      gparc.Success(val, _) -> should.equal(val, tc.1)
    }
  })
}

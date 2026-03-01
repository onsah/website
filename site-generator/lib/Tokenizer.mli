module Sequence = MySequence

type kind =
  | Text of string
  | LeftCurly
  | RightCurly
  | Foreach
  | In
  | End
  | Dot
  | Space
  | Newline
  | LeftParen
  | RightParen
  | Semicolon
  | Char of char
[@@deriving sexp, compare]

val show_kind : kind -> string

type token = {
  kind : kind;
  start_location : Location.t;
  end_location : Location.t;
}
[@@deriving sexp, compare]

val compare_token : token -> token -> int

type error =
  [ `TokenizerExpectedOneOf of char list * Location.t
  | `TokenizerUnexpected of char * Location.t
  ]
[@@deriving sexp, compare]

val show_error :
  [< `TokenizerExpectedOneOf of char list * Location.t
  | `TokenizerUnexpected of char * Location.t
  ] ->
  string

val tokenize : char Sequence.t -> (token, [> error ]) result Sequence.t

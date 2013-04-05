Require Import Coq.Strings.String.
Require Import Coq.Strings.Ascii.

Open Scope char_scope.

(** Binary numbers are so ubiquitous in Computer Science that
    programming languages often have special notations for them. Many
    of them allow programmers to write numbers in base 16, because of
    its close correspondence with how things are
    represented. Unfortunately, Coq has no built-in support for
    hexadecimal notation for numbers. Even though the language allows
    users to extend its syntax, this mechanism is not powerful enough
    to support these additions. A nice illustration of this fact is
    the built-in decimal syntax for numbers, which is coded directly
    in OCaml. In this post, I will show a way to circumvent this
    problem by using Coq itself to parse the new notation, which can
    be nicely adapted to similar situations.

    ** Reading numbers

    The first thing we will need is a Coq function to interpret
    hexadecimal notation. As we've seen #<a
    href="/posts/2013-03-31-reading-and-writing-numbers-in-coq.html">previously</a>#,
    writing such a function is straightforward. The code that follows
    is pretty much the same as in our past example, but reworked for
    base 16. *)

Definition hexDigitToNat (c : ascii) : option nat :=
  match c with
    | "0" => Some 0
    | "1" => Some 1
    | "2" => Some 2
    | "3" => Some 3
    | "4" => Some 4
    | "5" => Some 5
    | "6" => Some 6
    | "7" => Some 7
    | "8" => Some 8
    | "9" => Some 9
    | "a" | "A" => Some 10
    | "b" | "B" => Some 11
    | "c" | "C" => Some 12
    | "d" | "D" => Some 13
    | "e" | "E" => Some 14
    | "f" | "F" => Some 15
    | _   => None
  end.

Open Scope string_scope.

Fixpoint readHexNatAux (s : string) (acc : nat) : option nat :=
  match s with
    | "" => Some acc
    | String c s' =>
      match hexDigitToNat c with
        | Some n => readHexNatAux s' (16 * acc + n)
        | None => None
      end
  end.

Definition readHexNat (s : string) : option nat :=
  readHexNatAux s 0.

(** Our function works just as expected. *)

Example readHexNat1 : readHexNat "ff" = Some 255.
Proof. reflexivity. Qed.

(** ** Convenient notation

    Now that we have our function, we can use it to simulate support
    for hexadecimal numbers in Coq. Since [readHexNat] returns an
    [option nat], however, we can't just use it where a natural number
    is expected, because the types do not match. One solution is to
    use some default value for the result when we get a parse error,
    and now everything works. *)

Module FirstTry.

Definition x (s : string) : nat :=
  match readHexNat s with
    | Some n => n
    | None => 0
  end.

Example e1 : x"ff" = 255.
Proof. reflexivity. Qed.

Example e2 : x"a0f" = 2575.
Proof. reflexivity. Qed.

(** Though slightly awkward, this notation is not too different from
    the usual [0xa0f] present in C and many other languages.

    In spite of being simple, this approach has a significant drawback
    when compared to languages that understand base 16 numbers
    naturally. In those languages, a misspelled number will most
    likely result in a parse error, which will be probably caught soon
    and fixed. Here, on the other hand, we chose to ignore such
    errors. *)

Example e3 : x"1O" = 0.
Proof. reflexivity. Qed.

(** Such errors won't be immediately noticeable, and will probably
    manifest themselves as problems in other parts of the program, not
    directly related to their cause. It may seem at this point that we
    would have either to accept this limitation and live with it, or
    to patch the Coq source code and implement the new notation by
    hand. Luckily, a sane solution exists. *)

End FirstTry.

Module SecondTry.

Definition forceOption {A Err} (o : option A) (err : Err) : match o with
                                                              | Some _ => A
                                                              | None => Err
                                                            end :=
  match o with
    | Some a => a
    | None => err
  end.

Inductive parseError := ParseError.

Definition x (s : string) :=
  forceOption (readHexNat s) ParseError.

Example e3 : x"ff" = 255.
Proof. reflexivity. Qed.

Example e4 : x"1O" = ParseError.
Proof. reflexivity. Qed.

End SecondTry.

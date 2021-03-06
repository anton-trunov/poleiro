(* begin hide *)
Require Import Coq.Strings.String.
Require Import Coq.Strings.Ascii.
(* end hide *)
(** Binary numbers are so ubiquitous in Computer Science that
    programming languages often have special notations for them. The
    most popular one is arguably hexadecimal notation. It is close to
    binary representation, since each digit corresponds exactly to
    four bits, but it is much more compact. Unfortunately, Coq has no
    built-in support for hexadecimal notation. While the language does
    allow the user to extend its syntax, this mechanism is not
    powerful enough to implement this feature. Coq's own built-in
    decimal notation, for instance, is a special case coded directly
    in OCaml. In this post, I will show a way to circumvent this
    problem by using Coq itself to parse base 16 numbers.

    ** Reading numbers

    The first thing we will need is a Coq function to interpret
    hexadecimal notation. As we've seen #<a
    href="/posts/2013-03-31-reading-and-writing-numbers-in-coq.html">previously</a>#,
    writing such a function is straightforward. The code that follows
    is pretty much the same as in our past example, but reworked for
    base 16. *)

Open Scope char_scope.

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

(** Our function behaves just as expected. *)

Example readHexNat1 : readHexNat "ff" = Some 255.
Proof. reflexivity. Qed.

(** ** Convenient notation

    Now that we have a Coq function that reads hexadecimal numbers, we
    can use it as our notation. There is a small problem,
    though. Since [readHexNat] returns an [option nat], we can't just
    use it where a natural number is expected, because the types do
    not match. In regular functional programming languages such as
    Haskell or OCaml, one could just raise a runtime error when such a
    parse error is found. This is not possible in Coq, since all
    functions must be total. Instead of doing that, we return a
    default number when an error is found. *)

Module FirstTry.

Definition x (s : string) : nat :=
  match readHexNat s with
    | Some n => n
    | None => 0
  end.

(** This function allows us to write numbers with nice syntax. *)

Example e1 : x"ff" = 255.
Proof. reflexivity. Qed.

Example e2 : x"a0f" = 2575.
Proof. reflexivity. Qed.

(** Though slightly awkward, this notation is not too different from
    the usual [0x] notation present in C and many other languages.

    In spite of being simple, this approach has a significant drawback
    when compared to languages that understand base 16 numbers
    naturally. In those languages, a misspelled number will most
    likely result in a parse error, which will probably be caught soon
    and fixed. Here, on the other hand, we chose to ignore such
    errors. Suppose, for instance, that we mistakingly type 10 with a
    capital "O" instead of "0" in our code. Our number would now be
    understood as 0. *)

Example e3 : x"1O" = 0.
Proof. reflexivity. Qed.

(** Such errors may not be noticed immediately, and will probably
    manifest themselves as problems in other parts of the program,
    making it hard to track the real cause. It may seem at this point
    that we would either have to accept this limitation and live with
    it, or need to patch the Coq source code and implement the new
    notation by hand. Luckily, a sane solution exists. *)

End FirstTry.

(** ** Putting the type system to work

    There are two key insights that we need here. First, types in Coq
    can be manipulated pretty much like any other value in the
    language. In particular, this means that functions can take types
    as arguments and return other types. This is not too strange: the
    familiar [list] type constructor, for instance, is just a function
    that takes a type as input and returns the type of lists of that
    type. *)

Check list.

(* list
     : Type -> Type *)

(** As a more interesting example, one can write a function that takes
    some piece of _data_ as input and returns a Coq type. *)

Definition natOrString (b : bool) : Type :=
  if b then nat else string.

(** This idea might seem odd when seen for the first time, but it
    enables very powerful techniques when combined with a second key
    feature. Coq is a _dependently typed_ language, which means that
    the return type of a function can depend on values passed to it as
    arguments. *)

Definition alwaysZero (b : bool) : natOrString b :=
  match b with
    | true => 0
    | false => "0"
  end.

Definition z1 : nat := alwaysZero true.
Definition z2 : string := alwaysZero false.

(** The Coq type checker accepts the first definition because it knows
    that [alwaysZero] returns a [nat] when its argument is [true], and
    similarly for the second one.

    Using this idea, we define a function that extracts the value of
    an [option] when it has the form [Some a], but returns an element
    of some other arbitrary type otherwise: *)

Definition forceOption A Err (o : option A) (err : Err) : match o with
                                                            | Some _ => A
                                                            | None => Err
                                                          end :=
  match o with
    | Some a => a
    | None => err
  end.

(** The type signature of this function looks weird, but nothing
    fundamentally complicated is hapenning here. To see how this
    function could help us solve our problem, suppose that the Coq
    type checker is able to detect statically that the [o] argument
    passed to [forceOption] is [Some a]. In this case, the result type
    of the computation will be exactly [A], and we will be able to use
    it like any other value of [A]: *)

Definition f1 : nat := forceOption nat bool (Some 42) false.

(** If, on the other hand, a [None] is passed to the function, the
    return type will be [Err], which is used to signal the occurrence
    of an error. Thus, if [Err] and [A] are not the same, type
    checking will fail and a type error will be issued. *)

(* Definition f2 : nat := forceOption nat bool None false. *)
(* Toplevel input, characters 43-74:
   Error: The term "forceOption nat bool None false" has type
   "bool" while it is expected to have type "nat". *)

(** With [forceOption] in hand, it is easy to solve our problem. We
    begin by defining a singleton type that represents type errors. *)

Inductive parseError := ParseError.

(** Now, we are ready for our second attempt. *)

Module SecondTry.

Definition x (s : string) :=
  forceOption nat parseError (readHexNat s) ParseError.

(** Our new notation behaves as expected on the previous examples. The
    type annotations below ([: nat]) are not mandatory; they are just
    there to illustrate that the types match. *)

Example e1 : (x"ff" : nat) = 255.
Proof. reflexivity. Qed.

Example e2 : (x"a0f" : nat) = 2575.
Proof. reflexivity. Qed.

(** A parse error will result in a [None], which will be translated to
    a [parseError] by [forceOption], and therefore will cause a type
    error when used as a [nat]. *)

Example e3 : (x"1O" : parseError) = ParseError.
Proof. reflexivity. Qed.

End SecondTry.

(** ** Summary

    We've seen that the expressivity of Coq's type system makes it
    possible to encode tricks that would be unnatural or just
    impossible in other languages.

    As discussed above, in OCaml or Haskell one could trigger an error
    when the program encounters an unexpected situation, such as
    getting a [None] after parsing a number. While better than just
    returning a nonsensical result, like we did in our first attempt,
    this solution still only reveals the error at runtime. Using Coq's
    dependent types, we were able to detect such errors as type errors
    at compile time, without resorting to any external features. *)

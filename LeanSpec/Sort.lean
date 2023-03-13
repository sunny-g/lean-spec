/-
# Example: Sorting

In this example we specify a function that sorts a list into ascending order.
-/
import LeanSpec.lib.Util

/-
Informally, a sort function takes a list as argument, and returns a list that
is an ordered permutation of its argument. A predicate that specifies whether
a list is ordered might be:
-/
def Ordered₁ [LT α] : List α → Prop
 | [] | [_] => True
 | a::b::as => a < b ∧ Ordered₁ (b::as)

/-
Empty and singleton lists are trivially ordered. A list of two or more items is ordered
if the first item precedes the second item, and the tail is ordered. The type of items in
the list must admit an order relation, stated in the definition by `[LT α]`: the type `α`
is an instance of the type class `LT`.

First let's try a naive definition. Two lists are permutations of each other if they
contain the same items, irrespective of order:
-/
def Permutation₁ (as bs : List α) :=
  ∀ a : α, a ∈ as ↔ a ∈ bs

/-
With these definitions we can now specify the sorting function:
-/
def Sort₁ [LT α] (as : List α) :=
  { sas : List α // Ordered₁ sas ∧ Permutation₁ as sas }

/-
`Sort₁` takes as argument a list of items with an order relation,
and returns a list that is an ordered permutation of its input.

There is, unfortunately, a problem with the specification of `Sort₁`: it is not
possible to derive a program that meets the specification. Do you see why?

Consider this clause from the definition of `Ordered₁`:
- `a::b::as => a < b ∧ Ordered₁ (b::as)`.

What happens when the input list is `[2, 2]`? The definition of `Ordered₁` states that two
consecutive items in the list must be related by `<`, but `2 ≮ 2`. The specification does
not accommodate lists with duplicate entries.

Just as there is no guarantee a postulated mathematical theorem is provable,
there is no guarantee a program specification is implementable (they are after
all different expressions of the same concept).

Let's try again. First note the function `numOccurs` (defined in [Util](lib/Util.md)) that counts
the number of occurrences of an item in a list:
-/
#check List.numOccurs

/-
The `Ordered` predicate is largely as before except the comparison operator
is `≤` (with corresponding type class `LE`) rather than `<`:
-/
def Ordered₂ [LE α] : List α → Prop
 | [] | [_] => True
 | a::b::as => a ≤ b ∧ Ordered₂ (b::as)

/-
The `Permutation` predicate cannot simply check for membership, it must ensure
the number of occurrences of any item in one list is the same as the number of
occurrences in the other list.
-/
def Permutation₂ [BEq α] (as bs : List α) :=
  ∀ a : α, as.numOccurs a = bs.numOccurs a

/-
`Sort₂` employs the new `Ordered₂` and `Permutation₂` predicates, but otherwise is
unchanged:
-/
def Sort₂ [BEq α] [LE α] (as : List α) :=
  { sas : List α // Ordered₂ sas ∧ Permutation₂ as sas }

/-
In fact `LE` is insufficient. It only guarantees there is a binary predicate on the type, not
that it is the predicate we normally think of as _less than or equal_. The predicate must be
a partial order, but we won't go into the details here.

The predicate `Ordered₂` is typical of a traditional approach, perhaps with the
exception the result is a `Prop` rather than a `Bool`. Dependently typed
languages such as Lean offer an alternative approach; namely that of _Inductive Predicates_.
An inductive predicate is simply an inductive definition of a proposition as opposed to
an inductive definition of a type (list, tree, etc), and a member of the
inductive proposition is a proof of the proposition. For `Ordered` we could have:
-/
inductive Ordered₃ [LE α] : List α → Prop
  | empty       : Ordered₃ []
  | singleton a : Ordered₃ [a]
  | twoplus a b as (hab : a ≤ b) (hbas : Ordered₃ (b::as)) :
                  Ordered₃ (a::b::as)

/-
The three clauses state:
- `empty` is a proof that the empty list is ordered;
- `singleton a` is a proof that the singleton list containing `a` is ordered;
- `twoplus a b as hab hbas` is a proof that the list `a::b::as` is ordered,
given that `hab` is evidence `a ≤ b` and `hbas` is a proof that `b::as` is ordered.

Note the correspondence between the clauses in the inductive definition of `Ordered₃`
and the recursive definition of `Ordered₂`.

As with programming and proof, there is no single way, or best way, to specify a
program. The activity of specification is an iterative process, as the specification
is refined, and clearer ways of expressing concepts are discovered.

## Exercises

- Specify a function that, given a natural number, returns the prime factors of the number.
Use the `Prime` property from the last exercise.

- Using `Permutation₂`, specify a function that returns all permutations of an input list.

- The Lean standard library, `std4`, defines an inductive proposition `List.Chain'`. Specify
`Sort` using `Chain'`.
-/
#check List.Chain'
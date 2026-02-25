
You may have heard the term algebraic types before, which initially sounds like an advanced concept, that only someone with a PhD in programming languages can understand. Quite the contrary, algebraic types is a very simple and helpful concept about programming in general. Anyone who knows basic algebra could understand what algebraic types are.

In this article I aim to provide an explanation of algebraic types for the working programmer. I intentionally avoid any terminology that a regular programmer may not know about. I hope by the end of the article you know what algebraic types are and can use it in real programming and spot it where it appears.

## Types as Sets

What is a type, really? For instance, when we write `int`, what does it mean? One useful way to think about it is to treat types as sets. In this perspective, every type is treated as a set of possible values that is compatible with the type. For instance, `bool` is a type that has only `true` and `false` values. In OCaml `bool` is defined as:

```ocaml
type bool = true | false
```

In the left hand side we define the type `bool`. The right side provides the possible values, separated with `|`.

For integers, this is `0`, `1` or any other integer value. It's a bit more difficult to define integers directly as a regular type because in this case there are infinitely many values that integer can take. Writing all these is impossible. But assuming it was possible, we could write:

```ocaml
type int = ... | -3 | -2 | -1 | 0 | 1 | 2 | 3 | ...
```

In practice, integer types are usually limited to some finite range (but still too large) but this is not related to what we are discussing here. Strings are very similar to integers from this perspective.

What about `void` type? What are the values that it accepts? In some languages it's not obvious, but we can think `void` as a type with only a single possible value. In OCaml for instance, `unit` corresponds to `void`. It's defined as:

```ocaml
type unit = ()
```

In C, C++ or Java, `void` is treated differently than other types which makes it awkward to use in some cases. If we consider it as just any other type, there is no real need to make an exception for `void`. This simplifies the type system as well as the implementation of the programming language. I will give some examples to this after we understand [Algebraic Types](#algebraic-types-is-not-scary-actually).

Another interesting case is non-termination. What is the type of a while loop that never returns? Well, using the set perspective, if the expression returns no value, maybe it's type is a type which has no possible values? Note that this type is _different_ than `void` because `void` has one value that it can take but this type can take none. Sometimes this type is called `never`, as in it's never possible to have a value of this type. We can also trivially define this type as:

```ocaml
type never
```

Since there is no value for this type, it is _impossible_ to have a value of this type. Thus we can use it as the type of expressions or functions that doesn't terminate. Because, if it would terminate and return a value we would get a type error indicating that the value doesn't conform to the specified type.

## Algebraic Types are Just Elementary School Algebra

Using this view of types as sets of values, it's really easy to understand algebraic types. In fact, it's actually based on the algebra you learned in elementary school!

What is algebra on numbers? It's addition, multiplication, subtraction and division. Algebraic types are exactly that, it's basically _doing algebra over types_. So basically it's addition and multiplication over types.

### Product Types

Let's start with the more familiar one. If you have two types `T1` and `T2`, what other types you can have with it? Well, you can have a value that contains from both of these types, one from `T1` and one from `T2`. Similar to how a `struct` or `class` works in mainstream languages. We could express this in Java as:

```java
class Pair {
    T1 first;
    T2 second;
}
```

In the algebraic type terminology, this is called a _product type_. The reason is simple, when you combine two types, the resulting type contains every value whose parts are the values from the respective types. If the first type has `N` values, and the second has `M` values. Let's assume both to be enum types, with `N` having 2 and `M` having 3 variants. If we create a pair type from `N` and `M`, we could have `6` different values. Because we can choose 2 from `N` and 3 from `M`, which results with `2 * 3 = 6`. Hence, a pair type in the general case has `N * M` many values, hence the term product.

Every mainstream language supports this notion, because it's a very common use case, I am sure that this doesn't need any convincing. However, most languages doesn't support combining two types as a first class construct such as tuple types, therefore one has to explicitly define a new type for every combination. In practice, this lack leads to worse API designs, like the pattern of using pointers/references [^1] to return multiple values or Go's multiple return values [^2], because to return multiple arguments one has to create a custom type. Not having product types forces you to circumvent it with more specialized constructs that creates accidental complexity. Supporting product types as first class (See Rust and OCaml as examples) makes the language simpler and more unified, reducing the cognitive load for the user [^3].

### Sum Types

Now this part is a bit less apparent if you never used a functional language. But it's a really a common use case in programming that, you probably seen a problem before where you could use sum types.

A sum type is a type composed of two other types, where the values can be _either_ from the first type or the second type. For instance if you want to denote a fallible arithmetic operation, where the result is `int` if successful and a `string` containing the error message if not, the type of this result is `int` or `string`.

The name sum comes from the fact that, similar to products, if you create a sum type from types `N` and `M`, you get a type where there are `N + M` different possible values. Because you can have `N` options from the first and `M` option from the second. It's similar to logical or in the sense that, a value of a sum type is actually from the first type _or_ the second type.

Sum types appear commonly in real life. A value that can be `null` is a sum type, usually called `Option` or `Maybe` in programming languages. In OCaml it is defined as:

```ocaml
type a option = Some of a | None
```

The `a` denotes a generic type, if you are familiar with Java, it is equivalent to `Option<A>`. First construct `Some` is the case where a value is present, while `None` corresponds to `null` in imperative languages. This is not just an example, `option` type is very commonly used in  programs written in OCaml and other functional languages. `null` being at the type level prevents many runtime errors and reduces verbosity (you don't have to write `null` checks everywhere).

Another example is modeling errors. In Go, when a function can return an error, it's idiomatic to return it as the second value. By convention, either the first value or the second value is `nil` (Go's `null` value). However, this convention is implicit and in nowhere is enforced. So when you return two values, you have 4 cases, but you actually assume only two cases can happen in practice. If both values are not `null` or `null`, that would violate the assumption. We can summarize it in a table:

|Value 1|Value 2|Assumed|
|-|-|-|
|`present`|`null`|yes|
|`null` | `present` |yes|
|`present`|`present`|no|
|`null`|`null`|no|

The problem is, this invariant is never validated by the type checker and therefore the user has to be aware of the convention, which creates unnecessary cognitive load for the user. For instance, `io.Reader` interface may return `EOF` error _while also returning some data_. This is not what the general Go programmers assume to be the case, since they expect either `err` or `val` to be non-`nil`. This discrepancy causes [real life](https://github.com/golang/go/issues/52577) [bugs](https://www.reddit.com/r/golang/comments/u8wsnq/i_was_using_ioreader_wrongly/) even though [it's documented](https://pkg.go.dev/io#Reader).

Another disadvantage is that the programmer can't know the product is in fact intended to model a sum type unless it's in the documentation or they read the whole code. Both of these create more cognitive load compared to sum type in the signature. Moreover, the lack of sum types cause real life bugs in general, like anything that requires human validation, such as [this one](https://nicolashery.com/decoding-json-sum-types-in-go/#my-first-nil-pointer-panic-in-go-was-due-to-lack-of-sum-types).

Instead, we could simply use a sum type to denote it's _either_ a success with the result value, or an error with the error information. In OCaml, there is `result` type exactly for that:

```ocaml
type (a, b) result = Ok of a | Error of b
```

When we have a value of type `error`, the type checker enforces that only two desired conditions can happen, and the undesired conditions are _impossible_ to represent in code, making the code simpler and less prone to errors.

### Using Algebraic Types in Practice

To demonstrate the practical benefits of algebraic types, lets write an interpreter for arithmetic expressions. We will only have integers and arithmetic operators. We will not go through parsing arithmetic expressions as it's not related to the topic.

The type of expressions follows naturally from the definition:

```ocaml
type expr =
| Number of int
| Add of { left : expr; right: expr }
| Sub of { left : expr; right: expr }
| Mul of { left : expr; right: expr }
| Div of { left : expr; right: expr }
```

The first case denotes integers for the operands. Following cases correspond to each arithmetic operator. For instance, `2 + (3 * 2)` corresponds to:

```ocaml
let e = Add { 
  left = Number 2; 
  right = Mul { 
    left = Number 3; 
    right = Number 2; 
  } 
}
```

To evaluate expressions, we can write a simple evaluator, using pattern matching:

```ocaml
let rec eval (e : expr) : int =
  match e with
  | Number n -> n
  | Add { left; right } ->
    (eval left) + (eval right)
  | Sub { left; right } ->
    (eval left) - (eval right)
  | Mul { left; right } ->
    (eval left) * (eval right)
  | Div { left; right } ->
    (eval left) / (eval right)
```

If you are not familiar with pattern matching, it lets us determine the which variant the value has. The possible variants come from it's type. In this case, from the definition of `expr`, we know it's either a `Number` or one of the 4 operations. For the number case, we can return it directly. In other cases, the `left` and `right` fields have type `expr`, so first we have to recursively evaluate those subterms to get their `int` value. Then we can evaluate the current expression value by using the appropriate operator.

How could you do this without algebraic types? Abstract methods with inheritance can be used to emulate sum types. So we could have an abstract base class `Expr` then extend it for each case:

```java
abstract class Expr { abstract int eval(); }

class Number extends Expr {
    int value;
    int eval() { return value; }
}

class Plus extends Expr {
    Expr left, right;
    int eval() { return left.eval() + right.eval(); }
}

// Rest is omitted
```

The base class `Expr` has a method `eval` which should return the evaluated value of the expression. Each subclass implements it, recursively calling subexpression's `eval` method. In this case, there is no clear definition of the data structure, but it's mixed with the behavior. 

What if we want to interpret the expressions in a different way? Say we just want to convert it to it's written form. For the inheritance based solution, we would have to add a new base method to the class, and then implement it in the subclasses, like `eval`. With algebraic types, we could write another function that performs pattern matching. Something like:

```ocaml
let rec expr_to_string (e : expr) : string =
  match e with
  | Number n -> string_of_int n
  | Add { left; right } ->
    "(" ^ (expr_to_string left) ^ "+" ^ (expr_to_string right) ^ ")"
  | Sub { left; right } ->
    "(" ^ (expr_to_string left) ^ "-" ^ (expr_to_string right) ^ ")"
  | Mul { left; right } ->
    "(" ^ (expr_to_string left) ^ "*" ^ (expr_to_string right) ^ ")"
  | Div { left; right } ->
    "(" ^ (expr_to_string left) ^ "/" ^ (expr_to_string right) ^ ")"
```

I don't know you but I find the latter approach better. Because in the inheritance approach the relevant behavior is far away from each other. When someone wants to understand how string conversion works, they need to jump through every class. Whereas with the pattern matching, the relevant logic stays closer. Another issue is that operations implemented as a method in the class, therefore they have full access to the object's internals. However, those operations should only access the public interface of the objects. 

The abstract method approach is not the only alternative. The Visitor Pattern [^4] exists specifically to model sum types with object hierarchies [^6]. Using visitor pattern, we could have the following implementation:

```java
abstract class Expr { 
  abstract <R> R accept(Visitor<R> visitor);
}

class Number extends Expr {
    int value;
    <R> R accept(Visitor<R> visitor) { return visitor.visit(this); }
}

class Plus extends Expr {
    Expr left, right;
    <R> R accept(Visitor<R> visitor) { return visitor.visit(this); }
}

class Mul extends Expr {
    Expr left, right;
    <R> R accept(Visitor<R> visitor) { return visitor.visit(this); }
}

class Sub extends Expr {
    Expr left, right;
    <R> R accept(Visitor<R> visitor) { return visitor.visit(this); }
}

class Div extends Expr {
    Expr left, right;
    <R> R accept(Visitor<R> visitor) { return visitor.visit(this); }
}

interface Visitor<R> {
  R visit(Number number);
  R visit(Plus plus);
  R visit(Mul mul);
  R visit(Sub sub);
  R visit(Div div);
}

class EvalVisitor implements Visitor<Integer> {
  public Integer visit(Number number) { return number.value; }
  public Integer visit(Plus plus) { return plus.left.accept(this) + plus.right.accept(this); }
  public Integer visit(Mul mul) { return mul.left.accept(this) * mul.right.accept(this); }
  public Integer visit(Sub sub) { return sub.left.accept(this) - sub.right.accept(this); }
  public Integer visit(Div div) { return div.left.accept(this) / div.right.accept(this); }
}
```

It solves the problem of having to add new methods to the base class compared to naive inheritance approach. Also the relevant logic sits inside a single place, in this case the visitor implementation. However, it's a lot more verbose than pattern matching and more difficult to understand. It has more accidental complexity [^5] compared to pattern matching. Essentially visitor pattern is poor man's pattern matching. As Mark Seeman said [^6]:

> That's not to say that these two representations are equal in readability or maintainability. F# and Haskell sum types are declarative types that usually only take up a few lines of code. Visitor, on the other hand, is a small object hierarchy; it's a more verbose way to express the idea that a type is defined by mutually exclusive and heterogeneous cases. I know which of these alternatives I prefer, but if I were caught in an object-oriented code base, it's nice to know that it's still possible to model a domain with algebraic data types. 

## Conclusion

In short, for the most programming tasks you need two fundamental ways to combine types: the product and the sum. With these you can create arbitrary structures that can model real world data. Most languages have a way to express these two constructs, albeit some ways to represent it are more cumbersome such as using inheritance to emulate sum types. Using fundamental concepts you can model things in a simpler way without introducing unnecessary complexity.

## Credits

Thanks [Uğur](https://www.rugu.dev/) for his detailed and valuable feedback on the draft of this article.

[^1]: [How do I return multiple values from a function in C? - Stackoverflow](https://stackoverflow.com/questions/2620146/how-do-i-return-multiple-values-from-a-function-in-c)
[^2]: [Were multiple return values Go's biggest mistake?](https://herecomesthemoon.net/2025/03/multiple-return-values-in-go/)
[^3]: [Cognitive load is what matters](https://minds.md/zakirullin/cognitive)
[^4]: [Visitor Pattern](https://en.wikipedia.org/wiki/Visitor_pattern)
[^5]: [No Silver bullet](https://www.cs.unc.edu/techreports/86-020.pdf)
[^6]: [Visitor is a sum type](https://blog.ploeh.dk/2018/06/25/visitor-as-a-sum-type/)

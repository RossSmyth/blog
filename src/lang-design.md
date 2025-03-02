# Language Design Hot Takes(?)

Programming language design is hard, I think most people know that.
The best way to figure out how to make a successful or useful language is to find a problem people are facing
with the current languages, and try and fix it. Turns out, that can be hard!
What users say they want versus what actually solves their problems can be
two different things. But it is also very important not to infantilize or dismiss
user input completely, which is also common. You need to be able to read user input, and somehow figure out
what the root cause is.

I will try to walk through some features of languages that I think are so valuable that 
pretty much any language without them in 2024 should be mostly dismissed. That is my hot take.
We live in an age where we can do a lot with computers. We deserve good tools to excercise
them. 

## Sane Namespacing

This is one where many languages mess up, sadly. I am talking about it first because of that.
To see what I mean, let us look at an example in C.

```c
#include "header1.h"
#include "header2.h"

void my_func(void) {
  some_func();
}
```

Now, where did the function `some_func()` come from? Who knows? Could be from either header that was included.
This is basically about modules. C devs often use [Hungarian Notation](https://en.wikipedia.org/wiki/Hungarian_notation) to
"fix" this. I think wildcard imports are alright as long as they are explicit, though personally I don't recall
using them. The summary is that it should be clear where items are coming from. 

There is another part of this, which is that namespaces should be lexical. What I mean by that is it should be
clear just from the namespacing where I need to look to find the definitions. This doesn't mean that they are
necessarily a 1:1 namespace to module relationship, in fact I do not think most things should be. But it does
mean that I can easily trace where the declartion is.

To see a counter-example let us look at a C# program:

```C#
using Something.Foo;
```

Now tell me dear reader, where is "Something?" Where is "Foo?" I can not tell you. There may be an assembly called
"Something," or there could be several Something-related assemblies. An example is the "System" namespace, where it
is spread across many assemblies.

## Parameteric Polymorphism

The most common form of this is called "generics," but what I mean is some way to declare a function that
takes in a type parameter, and returns a instance of an item. There are several ways to do this:

1. Duck-typed templates

This is the route that C++ and Zig go. They take in parameters and return items, and type-checking occurs after
the template has been reified. These generally have worse diagnostic output since nothing is checked before
instantiation and higher-level info can be lost, but can be more flexible. Since Zig does not have overloaded
functions, its diagnostic output is generally better than C++.

```zig

fn Adder(comptime T: type) type {
  return struct {
    data: T

    const Self = @This();

    fn init(init: T) Self {
      return .{
        data = init,
      };
    }
    
    fn increment(self: *Self) void {
      self.data + 1;
    }
  };
}

pub fn main() !void {
  // Fine
  var foo = Adder(u32).init(0).increment();

  // Compile failure
  var bar = Adder(void).init().increment();
}

```
(I've not used Zig in years so this may not actually compile)


2. Bounded Polymorphism

I think that is the right name?

This is way most others implement. They allow you to specify a bound upon what types are allowed before
an item is reified. This means that some type-checking can occur before monomorphization. How exactly 
they are implemented generally differ on the compile-time vs. run-time speed
line. On one end you have boxed generics like Java, where everything is boxed and there is only one instance
of the item that was instanced in the build artifact. The other end is full reification, where a new instance
is created for every new value of parameter used. This is used in C++ and Rust. I think .NET generics are
somewhere in the middle.

Not having parametric polymorphism in 2024 is not fun. Even Go eventually added user-declarable generics
recently. Making data structures in C is not fun because this. You either must make God's most 
horrid preprocessor macro that has terrible UX (I did this at first and stopped because of ODR errors),
heap allocate and use void pointers (I cannot do this since I do not have an allocator), or just resign yourself
and copy and paste headers for each type needed and fix up symbols somehow (meeeeee).

 
```C#
public class Adder<T> where T : System.Int64
{
  private T data;

  public Adder(T init) 
  {
    data = init;
  }

  public Increment(void)
  {
    data += 1;
  }
}
```

## 

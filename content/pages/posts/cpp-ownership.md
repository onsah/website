I recently started using C++ at my `$DAY_JOB` and, along with that, decided to study C++ again. I think writing down your understanding is the best way to learn a topic. One part I find that is hard to understand in C++ is how the object ownership model works because it's not a single concept but a collection of a couple of smaller concepts. By ownership I mean creating and destroying objects, giving references to an object, and transferring ownership of an object. There is no one guide that covers everything.

These concepts are very important to write and read modern C++ (though I doubt if C++11 is still considered "modern"). Even if you just want to write C with Classes-style C++, you will probably use standard containers like `std::vector`, which requires an understanding of C++ ownership related features such as RAII, references, and move semantics to use it properly. Without knowing those, you simply can't have the correct memory model for C++, resulting in buggy programs full of undefined behaviors and inefficient programs due to unnecessary copying. By knowing these concepts, you can both avoid introducing bugs due to lack of understanding and reason about programs better.

This writing is my understanding of C++ ownership model. I think it can be useful to you if you have a basic level understanding of C++ and you want to learn more, or you are familiar with C++ but never learned the concepts and terminology formally.
## Who owns the Object?

In C++, every object has an owner, which is responsible for cleaning up the data once it's not used anymore. If you come from garbage collected languages, the concept of ownership may seem strange to you. But consider the following code:
```cpp
char* get_name(File* file);
```

This is a function that returns the file's name as a C-style string. What's not documented though, is who is supposed to deallocate the returned string. In this case there are two possibilities:
1. The function allocates new memory, and the caller must deallocate it once it's no longer being used.
2. `file` has a property that holds the file's name, and the function only returns the address of this property. The caller *must not* deallocate it.

Depending on which one is the case, the caller must act differently. This is because the *owner* of the data is different between these two cases. In the first case, owner is the variable assigned to the function's return value, and in the second, owner is the `file` variable. If the latter is the case, the variable assigned to the return value *borrows* the data owned by `file`.

In a garbage collected language, you don't have this distinction because, in a sense every variable is a borrower, and the owner is the garbage collector (GC). The GC just ensures that the data is allocated as long as there is a reference (borrower) to it. But at the same time every variable can be considered an owner since holding a variable keeps the data alive. C++ doesn't have a garbage collector, but it has a mechanism to automate some parts of object creation and destruction.
## Creating and Destroying Objects
When you declare a variable to an object in C++, it will create the object, and the variable will be the owner of the object. If the object has a destructor (a special function that destroys the resources represented by the object), it's automatically destroyed when the block of the variable ends. This technique of connecting resources to variables is called RAII[^1]. The span that object is alive is called *the lifetime* of the object.

In modern C++, it is advised that you create objects with destructors so the resources are cleaned up automatically at the end of their lifetime. To see why, consider this example:
```cpp
void foo(std::size_t buffer_size) {
  // Allocate some memory
  char* buffer = new char[buffer_size];
  
  int result = 0;
  try {
    while (has_more) {
	  read(buffer.get());
	  result += process(buffer.get());
    }
  } catch (std::exception e) {
    delete buffer;
    throw e;
  }
  delete buffer;
  return result;
}
```

The code essentially reads some data and writes it to `buffer`, and then adds the processed output of the `buffer` into `result`. Assume that `read` may `throw`, which means that it's possible to never execute the `delete` statement before `return`. To handle this case, then we must write a `try catch` block to delete the `buffer` in case an exception occurs and then re`throw` the exception.

Instead of using raw `char*`, we can use an object with a destructor called `unique_ptr`. This class owns a pointer and destroys it once its lifetime ends:
```cpp
void foo(std::size_t buffer_size) {
  // Allocate some memory
  std::unique_ptr<char[]> buffer = std::make_unique<char[]>(buffer_size);
  
  int result = 0;  
  while (has_more) {
    read(buffer.get());
    result += process(buffer.get());
  }
  
  // `s` will be freed before returning
  return result;
}
```
We don't need to write any `free` or `delete` because the `buffer` is a `unique_ptr`[^2]. This is a "smart" pointer type that de-allocates the memory once the block it declared ends (this is related to [lifetime](#lifetime), which I will talk about shortly). Note that even if the body `throw`s, the cleanup process will still work. This may not seem like a big issue in the scale of this code, but in a large function, resource cleanup gets messy real quick. In fact, this is one of the few use cases where it still makes sense to use `goto` in `C` today.

RAII[^1] (Resource Acquisition Is Initialization) basically means constructing a value means creating the resource it represents, and consequently when the value is no longer reachable, destroying the resource. To make it more concrete, consider using a heap memory, but there are other resource types like files, mutex locks etc... In the absence of a garbage collector, one must deallocate every allocated heap memory manually. With RAII one can make it handled automatically.

So RAII is very convenient, but is it magic? It is certainly not. RAII calls the object's destructor function when the object's lifetime ends. So if you hold a reference or pointer to an object that had its lifetime ended, [you are in undefined behavior territory](https://en.cppreference.com/w/cpp/language/reference.html#Dangling_references). So unlike garbage collectors, RAII without lifetime analysis doesn't protect you from accessing dangling references, even though it's still an improvement over manual allocation and deallocation.
### Destructors
Destructors are basically functions that is executed when the object's lifetime ends. They are supposed to clean whatever resources were created in the object's constructor. Notice the "supposed to", because this part depends on the programmer to implement it correctly. For instance, if your class allocates a memory in the constructor and does nothing in the destructor, it will just leak memory. Therefore one must ensure everything is cleaned properly in the destructor of a class.

The name of a destructor function is `~A` where `A` is the class name. When such a function is defined, it is automatically inserted to the end of the scope where a variable is no longer used anymore. To make it more concrete, consider the following mutex class:
```cpp
class RAIIMutex {
private:
  std::mutex& mutex;
public:
  RAIIMutex(std::mutex& mutex): mutex{mutex} {
    mutex.lock();
  }
  
  ~RAIIMutex() {
    mutex.unlock();
  }
}
```

Then we can use it as following:
```cpp
char* global_variable = ...;
std::mutex global_variable_mutex = ...;

void foo() {
  RAIIMutex guard(global_variable_mutex);
  
  // Can access global_variable safely
  process(global_variable);
  
  // Will automatically drop the lock here
}
```

As you see, destructors are used by RAII to deallocate the resource once the variable is no longer accessible, which leads us to the lifetime concept.
## Lifetime
In C++, every object and reference has a lifetime, which means any object or reference has a point in time where its lifetime begins and ends. What does this mean? This may seem like a silly concept if you are used to garbage collected languages, because in those languages you rarely think, "when is this object not usable anymore?". You only create objects, and as long as you refer to an object, it's usable by definition. However, in C++ you *must* think about when an object stops being usable because it's possible that you refer to it through a variable name, pointer or reference, but the object is already destroyed.

Local variables, which are by far the most used variable type in most programs, begin their lifetime in the block they are declared in and end it when the block ends. If we go back to the RAII example, the lifetime of the `buffer` variable starts in the beginning of `foo` (because it's declared in `foo`'s block) and is deallocated at the end of the block, which is the end of `foo`.

There are other types of variables with different lifetime behavior[^3] such as `static` variables, but it's out of scope for this writing.

One important observation is that, if there is an object that is reaching to the end of its lifetime, we can *reuse* its resources for another object since otherwise they will be destroyed anyway. This is essential to understanding [moves](#move).
## Pointers/References
In many cases, you want to pass a variable to another function but don't want to copy the whole data. In this case you need to pass a pointer or reference to that variable. From now on I will only talk about references but almost everything equally applies to pointers as well. Analogous to normal variables, references also have their lifetimes. And intuitively, reference's lifetime must always be equal or smaller than the object's lifetime that reference points to. Otherwise you would be having a reference to an object that is already destroyed and as you may know that is undefined behavior.

A simple way to ensure this is to never store a reference passed to function such that the reference is used after function returns. Let me give an example. Consider:
```cpp
size_t bar(const std::vector<int>& vec) {
  size_t result = 0;
  for (auto i : vec) {
    // Do something with i
  }
  return result;
}
```

This function is totally safe since it only uses `vec` to calculate a result. Once the function returns, the reference doesn't live anywhere else. But consider this:

```cpp
class B {
std::vector<int>& vec;
public:
  void set_vec(std::vector<int>& vec) {
    this->vec = vec;
  }

  size_t bar() {
	  size_t result = 0;
	  for (auto i : vec) {
	    // Do something with i
	  }
	  return result;
  }
}

int main() {
  B b;
  if (some_condition) {
    std::vector<int> vec{1, 2, 3};
    b.set_vec(vec);
  }
  b.bar();
}
```

In this code, `main` creates an instance of `B` and conditionally sets it's reference variable to `vec` inside the `if`. However, then it calls `b.bar`, which refers to `vec` that is already destroyed at the end of the if block. Essentially the problem is that the lifetime of `vec` is limited to the if block but `b` has a larger lifetime which leads to a dangling reference.

In short, always ensure that references point to objects with a large enough lifetime to prevent painful debugging sessions.
## Move
Up until this point, we learned how to create objects, copy them and hold references to them while they are alive. These are enough to write many useful programs, as C++ until C++11 only had these features. But there is one missing piece: transferring resources from one object to another. You can emulate moves with pointers to some degree (since you can just copy a pointer and reassign the old pointer to something else), but there are some things that's not possible to do without moves.

Consider how `std::vector` reallocates it's buffer. When you grow a vector you need to copy the object's from the old buffer to the new buffer. A simplistic implementation would be:
```cpp
template <typename T>
void vector<T>::grow(size_t new_capacity) {
  T* new_buffer = new T[new_capacity];
  for (size_t i = 0; i < this->size; ++i) {
    new_buffer[i] = this->buffer[i];
  }
  T* old_buffer = this->buffer;
  this->buffer = new_buffer;
  this->capacity = new_capacity;
  delete[] new_buffer;
}
```

If you look into the in the `for` loop, you see that we make a *copy assignment* (because the value category of `this->buffer[i]` is `lvalue` but don't worry if you don't know what this means) from the old buffer to the new buffer for each element. This is a cheap operation if the type of the vector is a simple type but if it's holding large heap allocated objects it means every value in vector is *duplicated*. Since the old buffer is immediately deleted after the copy this is really unnecessary. As these objects are going to be destroyed anyway, it would actually not a problem to *steal* the contents of the objects in the old buffer.

You may think, "can't I just `mempcy` the old buffer to new buffer?". It wouldn't work because it would call destructor both in the old and new buffer for every `memcpy`ed object. You can't also zero the old buffer since you don't know if that's a valid object representation. Also it's quite possible that object is self referential. In that case you would end up with a dangling pointer.

This is where the concept of move comes into the picture. By introducing move into C++ we can now steal resources from an object that is about to be destroyed, thus avoiding making unnecessary copies. Using `std::move`, we can rewrite the copy loop as:

```cpp
for (size_t i = 0; i < this->size; ++i) {
    new_buffer[i] = std::move(this->buffer[i]);
}
```

Notice how the only difference is that we call `std::move` with the variable we want to *move from* and assign it's return value to the variable we want to *move to*. With this change the source object's resources will be reused in the new buffer, thus eliminating the unnecessary copying.

We now know how to move objects, so can we just spam `std::move` to any object type to achieve move behavior? The answer is no, unlike [Rust move semantics](https://cel.cs.brown.edu/crp/idioms/constructors/copy_and_move_constructors.html#move-constructors), C++ move is something of a convention than a pure language feature, but there are also few language features playing a role.

One way to understand how something works is to simply look how it's implemented. So let's see, here is an overly simplified example `std::move` implementation:

```cpp
template<class T>
typename T&& move(T& t) {
  return static_cast<T&&>(t);
}
```

Were you expecting something *this* simple? Probably not, but that's essentially what `std::move` is. In itself `std::move` doesn't actually move anything (great naming right?). It's just a glorified cast from an lvalue reference `T&` to an *rvalue reference* `T&&`. Previously, when we only talked about references in general what we actually meant was lvalue references. An rvalue reference is *by convention* a reference to an object that is about to expire, one *can* *steal* resources from it. There is nothing instrintic to the language that makes rvalue references stealing, and lvalue references non-stealing. We can treat them as opposites and write code that way, but that would be working against the whole standard library and overload resolution rules so it doesn't make sense to do.
Existence of rvalue references allows writing overloads that normally copy to instead reuse the resources from the rvalue reference parameter. For example, consider two constructors for `std::string`:

```cpp
std::string(const std::string& other);
std::string(std::string&& other);
```

First constructor takes an lvalue reference, so it will allocate a new buffer and copy the contents from `other`. Since it is only copying it's also `const`. While second constructor takes an rvalue reference, thus can simply assign the buffer from `other` to the new object, and assign `other`'s buffer to `nullptr` (Therefore can't be `const`). When you normally pass an lvalue to a function, the overload with the lvalue reference will be choosen. But if you first call `std::move` then the second constructor will be picked. So that's essentially what `std::move` does, it makes you pick the rvalue reference overload among the other options.
## Conclusion

This was a long one, so if you came this far, thank you! I hope now you have an understanding of the ownership system in C++. Essentially it's bunch of seemingly unrelated features that together forms a coherent (!) system. There is a lot more gritty details about this stuff, but for the most cases you don't need to know that well.

## Further Reading
If you liked what you read and want to dive deeper, I recommend looking into these:
- [https://cbarrete.com/move-from-scratch.html](https://cbarrete.com/move-from-scratch.html)
- [A video about C++ value categories](https://www.youtube.com/watch?v=d5h9xpC9m8I)

[^1]: https://en.cppreference.com/w/cpp/language/raii.html

[^2]: https://en.cppreference.com/w/cpp/memory/unique_ptr.html

[^3]: https://en.cppreference.com/w/c/language/storage_class_specifiers.html

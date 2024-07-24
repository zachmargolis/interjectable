# Interjectable

Interjectable is a really simple Ruby library for dependency injection, designed to make unit testing easier.

## Installation

It's a gem!

```ruby
gem 'interjectable'
```

## Usage

Interjectable has one module (`Interjectable`) and two main methods for defining dependencies,
`inject` and `inject_static`. Use them like so!

```ruby
class MyClass
  include Interjectable

  # defines helper methods on instances that memoize values per instance
  inject(:dependency) { SomeOtherClass.new }
  inject(:other_dependency) { AnotherClass.new }

  # defines helper methods on instances that memoize values statically,
  # shared across all instances
  inject_static(:shared_value) { ENV["SOME_VALUE"] }
end
```

It also includes introspection method `injected_methods(include_super = true)` (both instance and class-level)
to track what dependency methods have been created.

```ruby
MyClass.injected_methods
# => [:injected_methods, :shared_value, :shared_value=]
MyClass.new.injected_methods
# => [:injected_methods, :dependency, :dependency=, :other_dependency, :other_dependency=, :shared_value, :shared_value=]
```

This replaces a pattern we've used before, adding default dependencies in the constructor, or as memoized methods.

```ruby
# OLD WAY, see above
class MyClass
  attr_accessor :dependency

  def initialize(dependency=SomeOtherClass.new)
    @dependency=dependency
  end

  def other_dependency
    @other_dependency ||= AnotherClass.new
  end
end
```

## Dependency Injection + Unit Testing?

> Ok but what the heck is dependency injection and what does it have to do with unit tests?

So in the real world, objects depend on other objects: object A uses object B to parse a file. This is normal. But what about when you want to test object A independently from object B? Object B might depend on objects C, D, E and so on, so the test would become needlessly complex.

For the sake of testing object A, we can stub out object B with something fake. But for normal usage of object A, we want to actually use object B (and all its dependencies). We can accommodate both these use cases with dependency injection!

Let's check it out: we can build a class A that normally references B, but in our test we can safely replace B, and don't even have to require or load B at all!

```ruby
# a.rb
class A
  include Interjectable

  inject(:b) { B.new }
  inject_static(:c) { C.new }

  def read
    b.parse
  end

  def foo
    c.boom
  end
end

# a_spec.rb
require "a"
require "interjectable/rspec"

describe A do
  describe "#read" do
    before do
      # You can use the block form of #test_inject to inject a fake object that references methods on a.
      a.test_inject(:b) { FakeB.new(foo) }

      # You can use the test_inject RSpec helper if you just want to inject an object that doesn't
      # need to reference anything on a.
      test_inject(described_class, :c, instance_double(C, boom: "goat"))
    end

    it "parses from its b, and foos from its c" do
      expect(subject.read).to eq("result")
      expect(subject.foo).to eq("goat")
    end
  end

  # Both Interjectable.test_inject and the RSpec test_inject helper will setup
  # RSpec after hooks to cleanup any test_inject-ed dependencies after the
  # context they are defined in.
  it "doesn't pollute other tests" do
    expect(subject.read).to eq(B.new.parse)
    expect(subject.foo).to eq(C.new.boom)
  end
end
```

> Great, why this library over any other?

Interjectable aims to provide clear defaults for easy debugging.

The other libraries we found used inject/provide setups. That setup is nice because files don't reference each other. However, this can become a headache to debug to actually figure out what is being used where. In our use cases, we use dependency injection for simplified testing, not for hands-free configuration.

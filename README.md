# Interjectable

Interjectable is a really simple Ruby library for dependency injection, designed to make unit testing easier.

## Installation

It's a gem!

```ruby
gem 'interjectable'
```

## Usage

Interjectable has one module (`Interjectable`) and one method (`inject`). Use it like so!

```ruby
class MyClass
  extend Interjectable

  inject(:dependency) { SomeOtherClass.new }
  inject(:other_dependency) { AnotherClass.new }
end
```

This replaces a pattern we've used before, adding default dependencies in the constructor, or as memoized methods.

```ruby
# OLD WAY, see above
class MyClass
  attr_accessor :dependency

  def initialize(dependency=SomeOtherClass.new)
    @dependency=dependency
  end

  def other_depency
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
  extend Interjectable

  inject(:b) { B.new }

  def read
    b.parse
  end
end

# a_spec.rb
require 'a'

describe A do
  describe "#read" do
    before do
      a.b = double("FakeB", parse: 'result')
    end

    it "parses from its b" do
      subject.read.should == 'result'
    end
  end
end
```

> Great, why this library over any other?

Interjectable aims to provide clear defaults for easy debugging.

The other libraries we found used inject/provide setups. That setup is nice because files don't reference each other. However, this can become a headache to debug to actually figure out what is being used where. In our use cases, we use dependency injection for simplified testing, not for hands-free configuration.
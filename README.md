# Injectable

Injectable is a really simple Ruby library for dependency injection.
The goal is to create a small interface for delegating to other objects, and grant the ability to unit test things independently.

## Installation

It's a gem!

```ruby
gem 'injectable'
```

## Usage

Injectable has one module (`Injectable`) and one method, `inject`. Use it like so!

```ruby
class MyClass
  extend Injectable

  inject(:dependency) { SomeOtherClass.new }
end
```

This replaces a pattern we've used before, adding default dependencies in the constructor.

```ruby
# OLD WAY, see above
class MyClass
  attr_accessor :dependency

  def initialize(dependency=SomeOtherClass.new)
    @dependency=dependency
  end
```


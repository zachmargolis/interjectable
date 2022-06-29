# Change Log

# v1.2.0

- Ruby 3.x made it an error to override a class variable in a parent class. There was a bug with `inject_static` where
  if a subclass was the first to call a static dependency, the class variable would only be set on that subclass (and
  children of that subsclass). If the injecting class then called the static dependency, it would override the already
  set child's class variable, which is now an error.

  ```ruby
  class Parent
    include Interjectable
    inject_static(:boom) { "goats" }
  end

  class Child < Parent; end

  Child.boom # => sets Child's @@boom = "goats"
  Parent.boom # => sets Parent's @@boom = "goats" and *clear* Child's @@boom.
  Child.boom # => Error on Ruby 3.x because you are trying to read an overriden class variable.
  ```
    
  Fix: always set the class variable on the class that called `inject_static`.

# v1.1.3

- Fix `test_inject` for sub-sub-classes.

# v1.1.2

- Fix visibility issue with `Module.define_method` for Ruby < 2.5.0.

# v1.1.1

- Fix typo in RSpec helper loading error message

# v1.1.0

- Add another RSpec helper `test_inject` to avoid needing a local variable for
  the setter block to reference. Again, see the [README.md](README.md) for
  usage.

# v1.0.0

- Calling `#inject` or `#inject_static` multiple times is now an error. Use
  `#test_inject` instead.
- Add `#test_inject` rspec helper. See the [README.md](README.md) for usage.

# v0.3.0

- Clear previously set class variables an subsequent calls to `#inject_static`
- Don't include `#inject` and `#inject_static` as instance variables on `include Interjectable`

# v0.2.0

Small feature.

- Added `Interjectable#inject_static` for sharing values across multiple
  instances.

# v0.0.2

Small patch.

- Updated `Interjectable#inject` to only call dependencies once, including
  results with falsy values.

# v0.0.1

Initial release.

- Added `Interjectable#inject`

# Change Log

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

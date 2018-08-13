# Change Log

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

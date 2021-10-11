# frozen_string_literal: true

require 'pry'
require 'rspec'

$LOAD_PATH.unshift(
  File.join(File.dirname(__FILE__), '..', 'lib', 'interjectable')
)

require 'interjectable'
require 'interjectable/rspec'

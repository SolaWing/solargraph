#!/usr/bin/env ruby
# frozen_string_literal: true

Dir.chdir(__dir__) do
  require 'bundler/setup'
  Bundler.require
  Bundler.reset!
end
# sympath will cause require error
$LOAD_PATH.unshift File.realpath File.expand_path 'lib', __dir__
load File.realpath File.expand_path 'bin/solargraph', __dir__

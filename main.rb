#!/usr/bin/env ruby
# frozen_string_literal: true

if defined? Bundler
  # pry invoke editor may inherit old bundle env. it's break solargraph(since not local)..
  # local solargraph should use bin/solargraph directly
  ENV.replace(Bundler.unbundled_env)
  restart = true
end
if restart || ( ENV["solargraph"] != "1" && !(ARGV & %w[socket stdio]).empty? )
  $stderr.puts "restart with global env and jit"
  # seems jit no effect?
  exec({"solargraph" => "1"}, 'ruby', '--jit', __FILE__, *ARGV)
  # never return, re exec
end

Dir.chdir(__dir__) do
  # ensure solargraph deps use the bundle version. but not limit other external gem's version
  require 'bundler/setup'
  Bundler.require
  # NOTE: reset won't reset env，nor $LOAD_PATH
  ENV.replace(Bundler.unbundled_env)
  Bundler.reset!
end
# sympath will cause require error
$LOAD_PATH.unshift File.realpath File.expand_path 'lib', __dir__
load File.realpath File.expand_path 'bin/solargraph', __dir__

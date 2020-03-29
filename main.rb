#!/usr/bin/env ruby
# frozen_string_literal: true

# sympath will cause require error
$LOAD_PATH.unshift File.realpath File.expand_path 'lib', __dir__
load File.realpath File.expand_path 'bin/solargraph', __dir__

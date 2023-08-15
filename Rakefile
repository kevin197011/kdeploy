# frozen_string_literal: true

# Copyright (c) 2023 kk
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

require 'time'

task default: %w[push]

task :push do
  sh 'rubocop -A'
  sh 'git add .'
  sh "git commit -m 'Update #{Time.now}.'"
  sh 'git push origin main'
end

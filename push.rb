# frozen_string_literal: true

# Copyright (c) 2025 kk
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

# Maintainer release helper → rake push (lint, spec, bump, commit version, push).
# Day-to-day: bundle exec rake   # runs spec
abort 'push.rb failed' unless system('bundle', 'exec', 'rake', 'push')

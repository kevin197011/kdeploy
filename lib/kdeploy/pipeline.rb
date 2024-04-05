# frozen_string_literal: true

# Copyright (c) 2024 kk
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

module Kdeploy
  class Pipeline
    attr_reader :steps

    def initialize
      @steps = []
    end

    def step(name, &block)
      @steps << { name: name, action: block }
    end

    def run
      @steps.each_with_index do |step, index|
        puts "Step #{index + 1}: #{step[:name]}"
        instance_eval(&step[:action])
        puts "Step #{index + 1} completed."
        puts '---------------------------------'
      end
      puts 'Pipeline exec completed.'
    end
  end
end

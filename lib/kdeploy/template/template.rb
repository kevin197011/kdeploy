# frozen_string_literal: true

require 'erb'
require 'tempfile'
require 'set'

module Kdeploy
  # ERB template rendering and upload handler
  class Template
    def self.render(template_path, variables = {})
      template_content = File.read(template_path)
      validate_template_variables(template_content, variables)
      context = create_template_context(variables)
      ERB.new(template_content).result(context.instance_eval { binding })
    end

    def self.create_template_context(variables)
      # Use a simple class instead of OpenStruct for better performance
      context_class = Class.new
      variables.each do |key, value|
        context_class.define_method(key) { value }
      end
      context_class.new
    end

    def self.render_and_upload(executor, template_path, destination, variables = {})
      rendered_content = render(template_path, variables)

      # Create temporary file
      temp_file = Tempfile.new('kdeploy')
      begin
        temp_file.write(rendered_content)
        temp_file.close

        # Upload rendered file
        executor.upload(temp_file.path, destination)
      ensure
        temp_file.unlink
      end
    end

    def self.validate_template_variables(template_content, variables)
      required = extract_template_identifiers(template_content)
      return if required.empty?

      provided = variables.keys.to_set(&:to_s)
      missing = required.reject { |name| provided.include?(name) }
      return if missing.empty?

      raise ArgumentError, "Missing template variables: #{missing.sort.join(', ')}"
    end

    def self.extract_template_identifiers(template_content)
      identifiers = template_content.scan(/<%=\s*([a-zA-Z_]\w*)/).flatten
      identifiers.uniq - ruby_keywords
    end

    def self.ruby_keywords
      %w[alias and begin break case class def defined? do else elsif end ensure false for if in module next nil not
         or redo rescue retry return self super then true undef unless until when while yield]
    end
  end
end

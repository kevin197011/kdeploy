# frozen_string_literal: true

require 'erb'
require 'fileutils'

module Kdeploy
  # ERB template management class
  class Template
    attr_reader :path, :content, :variables

    def initialize(template_path, variables = {})
      @path = template_path
      @variables = variables
      @content = load_template
    end

    # Render template with variables
    # @param additional_vars [Hash] Additional variables to merge
    # @return [String] Rendered content
    def render(additional_vars = {})
      all_vars = @variables.merge(additional_vars)

      # Create binding with variables
      template_binding = create_binding(all_vars)

      # Render ERB template
      erb = ERB.new(@content, trim_mode: '-')
      erb.result(template_binding)
    rescue StandardError => e
      raise TemplateError, "Failed to render template #{@path}: #{e.message}"
    end

    # Render and save to file
    # @param output_path [String] Output file path
    # @param additional_vars [Hash] Additional variables
    def render_to_file(output_path, additional_vars = {})
      rendered_content = render(additional_vars)

      # Ensure output directory exists
      FileUtils.mkdir_p(File.dirname(output_path))

      # Write rendered content
      File.write(output_path, rendered_content)

      KdeployLogger.info("Template rendered to: #{output_path}")
      output_path
    end

    # Check if template file exists
    # @return [Boolean] True if template exists
    def exist?
      File.exist?(@path)
    end

    # Get template modification time
    # @return [Time] Template file mtime
    def mtime
      File.mtime(@path) if exist?
    end

    private

    # Load template content from file
    # @return [String] Template content
    def load_template
      raise TemplateError, "Template file not found: #{@path}" unless File.exist?(@path)

      File.read(@path)
    rescue StandardError => e
      raise TemplateError, "Failed to load template #{@path}: #{e.message}"
    end

    # Create binding with variables
    # @param vars [Hash] Variables hash
    # @return [Binding] Binding object with variables
    def create_binding(vars)
      # Create a clean binding
      template_binding = binding

      # Define variables in the binding
      vars.each do |key, value|
        template_binding.local_variable_set(key.to_sym, value)
      end

      # Define helper methods
      template_binding.local_variable_set(:hostname, vars[:hostname] || vars['hostname'])
      template_binding.local_variable_set(:user, vars[:user] || vars['user'])
      template_binding.local_variable_set(:port, vars[:port] || vars['port'])

      template_binding
    end
  end

  # Template manager for handling multiple templates
  class TemplateManager
    attr_reader :template_dir, :global_variables

    def initialize(template_dir = 'templates', global_variables = {})
      @template_dir = template_dir
      @global_variables = global_variables
      @templates = {}
    end

    # Load template by name
    # @param template_name [String] Template name (without .erb extension)
    # @param variables [Hash] Template variables
    # @return [Template] Template object
    def load_template(template_name, variables = {})
      template_path = resolve_template_path(template_name)
      all_variables = @global_variables.merge(variables)

      @templates[template_name] = Template.new(template_path, all_variables)
    end

    # Render template by name
    # @param template_name [String] Template name
    # @param variables [Hash] Additional variables
    # @return [String] Rendered content
    def render(template_name, variables = {})
      template = @templates[template_name] || load_template(template_name, variables)
      template.render(variables)
    end

    # Render template to file
    # @param template_name [String] Template name
    # @param output_path [String] Output file path
    # @param variables [Hash] Additional variables
    # @return [String] Output file path
    def render_to_file(template_name, output_path, variables = {})
      template = @templates[template_name] || load_template(template_name, variables)
      template.render_to_file(output_path, variables)
    end

    # List available templates
    # @return [Array<String>] Template names
    def list_templates
      return [] unless Dir.exist?(@template_dir)

      Dir.glob("#{@template_dir}/**/*.erb").map do |path|
        File.basename(path, '.erb')
      end
    end

    # Set global variables
    # @param variables [Hash] Global variables
    def global_variables=(variables)
      @global_variables.merge!(variables)
    end

    private

    # Resolve template file path
    # @param template_name [String] Template name
    # @return [String] Full template path
    def resolve_template_path(template_name)
      # Add .erb extension if not present
      template_name += '.erb' unless template_name.end_with?('.erb')

      # Try template directory first
      template_path = File.join(@template_dir, template_name)
      return template_path if File.exist?(template_path)

      # Try relative to current directory
      return template_name if File.exist?(template_name)

      # Try absolute path
      return template_name if File.absolute_path?(template_name) && File.exist?(template_name)

      # Default to template directory path (will be checked by Template class)
      template_path
    end
  end

  # Template-related errors
  class TemplateError < StandardError; end
end

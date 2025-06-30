# frozen_string_literal: true

require 'erb'
require 'ostruct'
require 'tempfile'

module Kdeploy
  class Template
    def self.render(template_path, variables = {})
      template_content = File.read(template_path)
      context = OpenStruct.new(variables)
      ERB.new(template_content).result(context.instance_eval { binding })
    end

    def self.render_and_upload(executor, template_path, destination, variables = {})
      rendered_content = render(template_path, variables)

      # 创建临时文件
      temp_file = Tempfile.new('kdeploy')
      begin
        temp_file.write(rendered_content)
        temp_file.close

        # 上传渲染后的文件
        executor.upload(temp_file.path, destination)
      ensure
        temp_file.unlink
      end
    end
  end
end

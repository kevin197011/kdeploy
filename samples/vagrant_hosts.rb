# frozen_string_literal: true

require 'shellwords'

# Vagrant ssh-config helpers for samples/deploy.rb (AVF / VirtualBox).
module VagrantHosts
  module_function

  def ssh_config(vm_name, base_dir = __dir__)
    return nil unless system('which vagrant > /dev/null 2>&1')

    output = `cd #{Shellwords.escape(base_dir)} && vagrant ssh-config #{Shellwords.escape(vm_name)} 2>/dev/null`
    return nil if output.strip.empty?

    port = output[/^\s*Port\s+(\d+)/m, 1]&.to_i
    keys = output.lines.map(&:strip).grep(/^IdentityFile /).map { |l| l.split(/\s+/, 2)[1] }
    key = keys.find { |p| p && File.exist?(File.expand_path(p)) }
    return nil unless port && key

    { port: port, key: File.expand_path(key) }
  end

  def resolve(name, base_dir:, fallback_port:, fallback_key:)
    cfg = ssh_config(name, base_dir)
    port = cfg ? cfg[:port] : fallback_port
    key = cfg ? cfg[:key] : File.expand_path(fallback_key, base_dir)
    [port, key]
  end
end

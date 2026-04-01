# frozen_string_literal: true

UbiCli.on("kc").run_on("upgrade") do
  desc "Upgrade a Kubernetes cluster to the next available minor version"

  banner "ubi kc (location/kc-name | kc-id) upgrade"

  run do |opts, cmd|
    data = sdk_object.upgrade

    fields = %w[id name version display-state].freeze.each(&:freeze)
    keys = underscore_keys(fields)
    body = []

    each_with_dashed(keys) do |key, display_key|
      body << display_key << ": " << data[key].to_s << "\n"
    end

    response(body)
  end
end

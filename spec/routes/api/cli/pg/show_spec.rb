# frozen_string_literal: true

require_relative "../spec_helper"

RSpec.describe Clover, "cli pg show" do
  before do
    expect(Config).to receive(:postgres_service_project_id).and_return(@project.id).at_least(:once)
    @pg = Prog::Postgres::PostgresResourceNexus.assemble(
      project_id: @project.id,
      location_id: Location::HETZNER_FSN1_ID,
      name: "test-pg",
      target_vm_size: "standard-2",
      target_storage_size_gib: 64,
    ).subject
    @ref = [@pg.display_location, @pg.name].join("/")
  end

  it "shows information for PostgreSQL database" do
    expect(Config).to receive(:postgres_service_hostname).and_return("pg.example.com").at_least(:once)
    DnsZone.create(project_id: @project.id, name: "pg.example.com")
    @pg.add_metric_destination(username: "md-user", password: "1", url: "https://md.example.com")
    @pg.add_log_destination(name: "ld-name", host: "logs.example.com", port: 6514)
    @pg.update(root_cert_1: "a", root_cert_2: "b")
    @pg.representative_server.vm.add_vm_storage_volume(boot: false, size_gib: 64, disk_index: 0)
    rules = @pg.pg_firewall_rules
    rules[0].update(description: "my fwr desc")

    expected1 = [
      "id: #{@pg.ubid}\n",
      "name: test-pg\n",
      "state: creating\n",
      "location: eu-central-h1\n",
      "vm-size: standard-2\n",
      "target-vm-size: standard-2\n",
      "storage-size-gib: 64\n",
      "target-storage-size-gib: 64\n",
      "version: 17\n",
      "target-version: 17\n",
      "ha-type: none\n",
      "flavor: standard\n",
      "connection-string: postgres://postgres:#{@pg.superuser_password}@test-pg.#{@pg.ubid}.pg.example.com:5432/postgres?channel_binding=require\n",
      "primary: true\n",
      "earliest-restore-time: \n",
      "maintenance-window-start-at: \n",
      "read-replica: false\n",
      "parent: \n",
      "tags:\n",
      "firewall-rules:\n",
      "  1: #{rules[0].ubid}  0.0.0.0/0  5432  my fwr desc\n",
      "  2: #{rules[1].ubid}  0.0.0.0/0  6432  \n",
      "  3: #{rules[2].ubid}  ::/0  5432  \n",
      "  4: #{rules[3].ubid}  ::/0  6432  \n",
      "metric-destinations:\n",
      "  1: #{@pg.metric_destinations[0].ubid}  md-user  https://md.example.com\n",
      "log-destinations:\n",
      "  1: #{@pg.log_destinations[0].ubid}  ld-name  logs.example.com  6514\n",
      "read-replicas:\n",
      "ca-certificates:\n",
      "a\n",
      "b\n",
    ].join
    expect(cli(%W[pg #{@ref} show])).to eq expected1

    @pg.update(parent_id: @pg.id)
    expected2 = [
      "id: #{@pg.ubid}\n",
      "name: test-pg\n",
      "state: creating\n",
      "location: eu-central-h1\n",
      "vm-size: standard-2\n",
      "target-vm-size: standard-2\n",
      "storage-size-gib: 64\n",
      "target-storage-size-gib: 64\n",
      "version: 17\n",
      "target-version: 17\n",
      "ha-type: none\n",
      "flavor: standard\n",
      "connection-string: postgres://postgres:#{@pg.superuser_password}@test-pg.#{@pg.ubid}.pg.example.com:5432/postgres?channel_binding=require\n",
      "primary: true\n",
      "earliest-restore-time: \n",
      "maintenance-window-start-at: \n",
      "read-replica: true\n",
      "parent: eu-central-h1/test-pg\n",
      "tags:\n",
      "firewall-rules:\n",
      "  1: #{rules[0].ubid}  0.0.0.0/0  5432  my fwr desc\n",
      "  2: #{rules[1].ubid}  0.0.0.0/0  6432  \n",
      "  3: #{rules[2].ubid}  ::/0  5432  \n",
      "  4: #{rules[3].ubid}  ::/0  6432  \n",
      "metric-destinations:\n",
      "  1: #{@pg.metric_destinations[0].ubid}  md-user  https://md.example.com\n",
      "log-destinations:\n",
      "  1: #{@pg.log_destinations[0].ubid}  ld-name  logs.example.com  6514\n",
      "read-replicas:\n",
      "  eu-central-h1/test-pg\n",
      "ca-certificates:\n",
      "a\n",
      "b\n",
    ].join
    expect(cli(%W[pg #{@ref} show])).to eq expected2
  end

  it "-f option controls which fields are shown for the PostgreSQL database" do
    expect(cli(%W[pg #{@ref} show -f id,name])).to eq <<~END
      id: #{@pg.ubid}
      name: test-pg
    END
  end
end

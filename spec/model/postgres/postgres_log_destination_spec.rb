# frozen_string_literal: true

require_relative "../spec_helper"

RSpec.describe PostgresLogDestination do
  subject(:ld) {
    described_class.create(
      postgres_resource_id: pg.id,
      name: "graylog",
      host: "logs.example.com",
      port: 6514,
    )
  }

  let(:project) { Project.create(name: "test") }
  let(:pg) { create_postgres_resource(project:, location_id: Location.first.id) }

  describe "#structured_data" do
    it "returns nil when not set" do
      expect(ld.structured_data).to be_nil
    end

    it "returns parsed hash when set" do
      sd = {"honeybadger@61642" => {"api_key" => "secret"}}
      ld.update(structured_data: sd)
      expect(ld.reload.structured_data).to eq(sd)
    end
  end

  describe "#structured_data=" do
    it "stores nil when assigned nil" do
      ld.structured_data = nil
      ld.save_changes
      expect(ld.reload.structured_data).to be_nil
    end

    it "stores hash as JSON" do
      sd = {"logdna@48950" => {"api_key" => "abc"}}
      ld.structured_data = sd
      ld.save_changes
      expect(ld.reload.structured_data).to eq(sd)
    end

    it "stores a pre-serialized JSON string directly" do
      sd = {"logdna@48950" => {"api_key" => "abc"}}
      ld.structured_data = sd.to_json
      ld.save_changes
      expect(ld.reload.structured_data).to eq(sd)
    end
  end
end

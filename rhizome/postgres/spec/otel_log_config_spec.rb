# frozen_string_literal: true

require_relative "../lib/otel_log_config"

RSpec.describe OtelLogConfig do
  let(:instance) { "pg1abc2def3" }
  let(:server_role) { "primary" }
  let(:log_dir) { "/dat/17/data/pg_log" }
  let(:log_destinations) { [] }
  let(:config) { described_class.new(instance: instance, server_role: server_role, log_dir: log_dir, log_destinations: log_destinations) }

  describe "#to_config" do
    subject(:yaml) { config.to_config }

    it "includes health_check and file_storage extensions" do
      expect(yaml).to include("health_check:")
      expect(yaml).to include("file_storage/state:")
    end

    it "configures the pglog filelog receiver with the correct log dir" do
      expect(yaml).to include('- "/dat/17/data/pg_log/postgresql-*.json"')
    end

    it "tags pglog events with instance and server_role" do
      expect(yaml).to include('value: "pg1abc2def3"').at_least(:twice)
      expect(yaml).to include('value: "primary"').at_least(:twice)
    end

    it "sets hostname to the instance ubid in the pglog receiver" do
      expect(yaml).to include("field: attributes.hostname")
    end

    it "configures the journald receiver" do
      expect(yaml).to include("journald:")
    end

    it "filters journal to postgres-related units" do
      expect(yaml).to include('startsWith "postgresql@"')
      expect(yaml).to include('startsWith "pgbouncer@"')
      expect(yaml).to include('startsWith "upgrade_postgres"')
    end

    it "marks journal streams correctly" do
      expect(yaml).to include("mark_postgres_stream")
      expect(yaml).to include("mark_pgbouncer_stream")
      expect(yaml).to include("mark_upgrade_stream")
    end

    it "includes a batch processor" do
      expect(yaml).to include("batch:")
    end

    it "lists health_check and file_storage in service extensions" do
      expect(yaml).to include("extensions: [health_check, file_storage/state]")
    end

    context "with no destinations" do
      let(:log_destinations) { [] }

      it "produces no exporters" do
        expect(yaml).not_to include("syslog/dest")
      end

      it "produces no transform processors" do
        expect(yaml).not_to include("transform/dest")
      end

      it "produces no pipelines" do
        expect(yaml).not_to include("logs/pglog/dest")
      end
    end

    context "with one destination" do
      let(:log_destinations) do
        [{host: "logs.example.com", port: 6514, application_name: "myapp", structured_data: nil}]
      end

      it "creates a transform processor for the destination" do
        expect(yaml).to include("transform/dest0:")
      end

      it "sets appname from application_name" do
        expect(yaml).to include('set(log.attributes["appname"], "myapp")')
      end

      it "creates a syslog exporter for the destination" do
        expect(yaml).to include("syslog/dest0:")
        expect(yaml).to include('endpoint: "logs.example.com"')
        expect(yaml).to include("port: 6514")
      end

      it "uses TCP with RFC 5424" do
        expect(yaml).to include("network: tcp")
        expect(yaml).to include("protocol: rfc5424")
      end

      it "enables TLS" do
        expect(yaml).to include("tls:")
        expect(yaml).to include("insecure: false")
      end

      it "creates pglog and journal pipelines for the destination" do
        expect(yaml).to include("logs/pglog/dest0:")
        expect(yaml).to include("logs/journal/dest0:")
      end

      it "wires the pipeline correctly" do
        expect(yaml).to include("receivers: [filelog/pglog]")
        expect(yaml).to include("receivers: [journald]")
        expect(yaml).to include("processors: [transform/dest0, batch]")
        expect(yaml).to include("exporters: [syslog/dest0]")
      end

      it "produces no structured_data statements when structured_data is nil" do
        expect(yaml).not_to include('attributes["structured_data"]')
      end
    end

    context "with structured_data" do
      let(:log_destinations) do
        [{
          host: "logs.example.com",
          port: 6514,
          application_name: "myapp",
          structured_data: {
            "honeybadger@61642": {api_key: "secret", env: "prod"},
          },
        }]
      end

      it "emits structured_data set statements in the transform processor" do
        expect(yaml).to include('attributes["structured_data"]["honeybadger@61642"]["api_key"], "secret"')
        expect(yaml).to include('attributes["structured_data"]["honeybadger@61642"]["env"], "prod"')
      end
    end

    context "with multiple destinations" do
      let(:log_destinations) do
        [
          {host: "logs1.example.com", port: 6514, application_name: "app1", structured_data: nil},
          {host: "logs2.example.com", port: 6515, application_name: "app2", structured_data: nil},
        ]
      end

      it "creates a separate exporter for each destination" do
        expect(yaml).to include("syslog/dest0:")
        expect(yaml).to include("syslog/dest1:")
      end

      it "uses the correct host and port for each destination" do
        expect(yaml).to include('endpoint: "logs1.example.com"')
        expect(yaml).to include("port: 6514")
        expect(yaml).to include('endpoint: "logs2.example.com"')
        expect(yaml).to include("port: 6515")
      end

      it "creates a separate transform processor for each destination" do
        expect(yaml).to include("transform/dest0:")
        expect(yaml).to include("transform/dest1:")
      end

      it "sets appname per destination" do
        expect(yaml).to include('set(log.attributes["appname"], "app1")')
        expect(yaml).to include('set(log.attributes["appname"], "app2")')
      end

      it "creates pglog and journal pipelines for each destination" do
        expect(yaml).to include("logs/pglog/dest0:")
        expect(yaml).to include("logs/pglog/dest1:")
        expect(yaml).to include("logs/journal/dest0:")
        expect(yaml).to include("logs/journal/dest1:")
      end
    end

    context "with application_name containing double quotes" do
      let(:log_destinations) do
        [{host: "logs.example.com", port: 6514, application_name: 'my"app', structured_data: nil}]
      end

      it "escapes double quotes in application_name" do
        expect(yaml).to include('set(log.attributes["appname"], "my\\"app")')
      end
    end
  end
end

# frozen_string_literal: true

# Copyright (C) 2016-Present Pivotal Software, Inc. All rights reserved.
# This program and the accompanying materials are made available under the terms of the under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

require 'spec_helper'
require 'tempfile'

RSpec.describe 'recreate-all-service-instances config' do
  let(:renderer) do
    merged_context = BoshEmulator.director_merge(
      YAML.load_file(manifest_file.path),
      'recreate-all-service-instances',
      [broker_link]
    )
    Bosh::Template::Renderer.new(context: merged_context.to_json)
  end

  let(:rendered_template) do
    renderer.render('jobs/recreate-all-service-instances/templates/config.yml.erb')
  end

  let(:broker_link) do
    {
      'broker' => {
        'instances' => [
          {
            'address' => '123.456.789.101'
          }
        ],
        'properties' => {
          'username' => "%username'\"t:%!",
          'password' => "%password'\"t:%!",
          'port' => 8080,
        }
      }
    }
  end

  let(:config) { YAML.safe_load(rendered_template) }

  let(:manifest_file) { File.open 'spec/fixtures/recreate_all_minimal.yml' }

  context 'with no service instances api specified' do
    let(:manifest_file) { File.open 'spec/fixtures/recreate_all_minimal.yml' }

    it 'is not empty' do
      expect(config).not_to be_empty
    end

    it 'sets broker_api.url' do
      expect(config.fetch('broker_api').fetch('url')).to eq('http://123.456.789.101:8080')
    end

    it 'sets correct broker api authentication' do
      basic_auth_block = config.fetch('broker_api').fetch('authentication').fetch('basic')
      expect(basic_auth_block.fetch('username')).to eq("%username'\"t:%!")
      expect(basic_auth_block.fetch('password')).to eq("%password'\"t:%!")
    end

    it 'sets service_instances_api.url' do
      expect(config.fetch('service_instances_api').fetch('url')).to eq('http://123.456.789.101:8080/mgmt/service_instances')
    end

    it 'sets correct service instances api authentication' do
      basic_auth_block = config.fetch('service_instances_api').fetch('authentication').fetch('basic')
      expect(basic_auth_block.fetch('username')).to eq("%username'\"t:%!")
      expect(basic_auth_block.fetch('password')).to eq("%password'\"t:%!")
    end
  end

  context 'with service instances api specified' do
    let(:manifest_file) { File.open 'spec/fixtures/recreate_all_with_service_instances_api.yml' }
    let(:siapi_root_ca_cert) {false}
    let(:broker_link) do
      bl = {
        'broker' => {
          'instances' => [
            {
              'address' => '123.456.789.101'
            }
          ],
          'properties' => {
            'username' => "%username'\"t:%!",
            'password' => "%password'\"t:%!",
            'port' => 8080,
            'service_instances_api' => {
              'authentication' => {
                'basic' => {
                  'username' => "myname",
                  'password' => "supersecret"               
                }
              },
              'url' => 'http://example.org/give-me/some-services',
            }
          }
        }
      }
      if siapi_root_ca_cert
        bl['broker']['properties']['service_instances_api']['root_ca_cert'] = siapi_root_ca_cert
      end
      bl
    end
    
    it 'is not empty' do
      expect(config).not_to be_empty
    end

    it 'sets broker_api.url' do
      expect(config.fetch('broker_api').fetch('url')).to eq('http://123.456.789.101:8080')
    end

    it 'sets correct broker api authentication' do
      basic_auth_block = config.fetch('broker_api').fetch('authentication').fetch('basic')
      expect(basic_auth_block.fetch('username')).to eq("%username'\"t:%!")
      expect(basic_auth_block.fetch('password')).to eq("%password'\"t:%!")
    end

    it 'sets service_instances_api.url' do
      expect(config.fetch('service_instances_api').fetch('url')).to eq('http://example.org/give-me/some-services')
    end

    it 'sets correct service instances api authentication' do
      basic_auth_block = config.fetch('service_instances_api').fetch('authentication').fetch('basic')
      expect(basic_auth_block.fetch('username')).to eq('myname')
      expect(basic_auth_block.fetch('password')).to eq('supersecret')
    end

    it 'doesnt set root_ca_cert' do
      expect(config.fetch('service_instances_api').key?('root_ca_cert')).to be_falsey
    end

    context 'and root_ca_cert provided' do
      let(:siapi_root_ca_cert) do
        '-----BEGIN CERTIFICATE-----
          MostCERTainlyACert
          -----END CERTIFICATE-----
        '
      end  
      
      it 'sets correct root_ca_cert' do
        expect(config.fetch('service_instances_api').fetch('root_ca_cert')).to eq('-----BEGIN CERTIFICATE-----
          MostCERTainlyACert
          -----END CERTIFICATE-----
        ')
      end
    end
  end

  context 'with polling interval provided' do
    let(:manifest_file) { File.open 'spec/fixtures/recreate_all_with_polling_interval.yml' }

    it 'sets polling interval to 101' do
      expect(config.fetch('polling_interval')).to eq(101)
    end
  end

  context 'without polling interval provided' do
    let(:manifest_file) { File.open 'spec/fixtures/recreate_all_minimal.yml' }

    it 'sets polling interval to the default' do
      expect(config.fetch('polling_interval')).to eq(60)
    end
  end

  context 'with attempt interval provided' do
    let(:manifest_file) { File.open 'spec/fixtures/recreate_all_with_attempt_interval.yml' }

    it 'sets polling interval to 36' do
      expect(config.fetch('attempt_interval')).to eq(36)
    end
  end

  context 'without attempt interval provided' do
    let(:manifest_file) { File.open 'spec/fixtures/recreate_all_minimal.yml' }

    it 'sets attempt interval to the default' do
      expect(config.fetch('attempt_interval')).to eq(60)
    end
  end

  context 'with attempt limit provided' do
    let(:manifest_file) { File.open 'spec/fixtures/recreate_all_with_attempt_limit.yml' }

    it 'sets attempt limit to 42' do
      expect(config.fetch('attempt_limit')).to eq(42)
    end
  end

  context 'without attempt limit provided' do
    let(:manifest_file) { File.open 'spec/fixtures/recreate_all_minimal.yml' }

    it 'sets attempt limit to the default' do
      expect(config.fetch('attempt_limit')).to eq(5)
    end
  end

  context 'with an attempt limit less or equal zero' do
    let(:manifest_file) { File.open 'spec/fixtures/recreate_all_invalid_attempt_limit.yml' }

    it 'fails' do
      expect do
        rendered_template
      end.to raise_error(RuntimeError, 'Invalid recreate_all_service_instances.attempt_limit - must be greater or equal 1')
    end
  end

  context 'without request timeout provided' do
    let(:manifest_file) { File.open 'spec/fixtures/recreate_all_minimal.yml' }

    it 'sets request timeout to 120' do
      expect(config.fetch('request_timeout')).to eq(120)
    end
  end

  context 'with request timeout provided' do
    let(:manifest_file) { File.open 'spec/fixtures/recreate_all_with_request_timeout.yml' }

    it 'sets request timeout to the provided value' do
      expect(config.fetch('request_timeout')).to eq(300)
    end
  end

  it 'configures canary and in-flight properties to default values' do
    expect(config.fetch('max_in_flight')).to eq(1)
    expect(config.fetch('canaries')).to eq(0)
  end

end

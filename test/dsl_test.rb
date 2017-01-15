require_relative './test_helper'

class DslTest < Minitest::Test

  def test_defining
    # Create the base network configuration
    definition = Dsl.define(name: :test) do
      # VPC
      vpc(:vpc) do
        tags [tag(:name, 'vpc')]
        cidr_block '10.0.0.0/16'
        dns_support true
        dns_hostnames true
      end
      # Each VPC needs an internet gateway for internet bound traffic
      internet_gateway(:gw) do
        tags [tag(:name, 'gw')]
        vpc refs[:vpc][:id]
      end
      network_interface(:n) do
        tags [tag(:name, 'n')]
        description 'abc'
        security_groups ['sg1', 'sg2', refs[:sg1][:id]]
        subnet refs[:public][:id]
      end
      # Instance to act as a NAT
      instance(:i) do
        tags [tag(:name, 'i')]
        availability_zone 'us-east-1a'
        userdata 'abc'
        image_id 'abc'
        key_name 'k1'
        subnet_id refs[:public][:id]
        instance_type 't2.micro'
        iam_instance_profile 'iam1'
        snapshot_device_mapping(:'/dev/sda') do
          tags [tag(:name, 's')]
          snapshot 'abc'
        end
        ebs_device_mapping(:'/dev/sdb') do
          tags [tag(:name, 'e')]
          size 150
        end
        ephemeral_device_mapping(:'/dev/sdf') do
          tags [tag(:name, 'i')]
          virtual_name "ephemeral0"
        end
      end
      # Route tables
      route_table(:route_table) do
        tags [tag(:name, 'route table')]
        vpc refs[:vpc][:id]
        route(:r1) do
          cidr_block '0.0.0.0/0'
          gateway refs[:gw][:id]
        end
        route(:r2) do
          cidr_block '0.0.0.0/0'
          instance refs[:i][:id]
        end
        route(:r3) do
          cidr_block '0.0.0.0/0'
          nat refs[:n][:id]
        end
        route(:r4) do
          cidr_block '0.0.0.0/0'
          network_interface refs[:n][:id]
        end
      end
      # Private subnet
      subnet(:private) do
        tags [tag(:name, 'private')]
        cidr_block '10.0.0.0/24'
        public_ip false
        availability_zone 'us-west-2a'
        vpc refs[:vpc][:id]
        route_table refs[:route_table][:id]
      end
      # Public subnet
      subnet(:public) do
        tags [tag(:name, 'public')]
        cidr_block '10.0.1.0/24'
        public_ip true
        availability_zone 'us-west-2b'
        vpc refs[:vpc][:id]
        route_table refs[:route_table][:id]
      end
      # Security groups
      security_group(:sg1) do
        tags [tag(:key, 'value')]
        vpc refs[:vpc][:id]
        description 'test sg1'
        ingress :i1 do
          security_groups [refs[:sg2][:id], refs[:sg1][:id]]
          cidr_blocks [cidr_block('0.0.0.0/0')]
        end
        egress :e1 do
          security_groups [refs[:sg2][:id], refs[:sg1][:id]]
          cidr_blocks [cidr_block('0.0.0.0/0')]
        end
      end
      security_group(:sg2) do
        tags [tag(:key, 'value')]
        vpc refs[:vpc][:id]
        description 'test sg2'
        ingress(:i1) do
          security_groups [refs[:sg2][:id], refs[:sg1][:id]]
          cidr_blocks [cidr_block('0.0.0.0/0')]
        end
        egress(:e1) do
          security_groups [refs[:sg2][:id], refs[:sg1][:id]]
          cidr_blocks [cidr_block('0.0.0.0/0')]
        end
      end
    end
    executor = Dsl::Executors::BasicExecutor.new(
      definition: definition, 
      backend: (backend = Dsl::InMemoryBackend),
      validators: [Dsl::Validators::ReferenceValidator.new],
      sorter: Dsl::Sorters::TopologicalSorter.new,
      matcher: Dsl::Matchers::BasicMatcher.new(backend: backend),
      differ: Dsl::Differs::BasicDiffer.new
    )
    executor.execute!
  end

end

module Dsl

  ##
  # {
  #    "Type" : "AWS::EC2::Instance",
  #    "Properties" : {
  #       "Affinity" : String,
  #       "AvailabilityZone" : String,
  #       "EbsOptimized" : Boolean,
  #       "IamInstanceProfile" : String,
  #       "ImageId" : String,
  #       "InstanceInitiatedShutdownBehavior" : String,
  #       "InstanceType" : String,
  #       "KeyName" : String,
  #       "Monitoring" : Boolean,
  #       "BlockDeviceMappings" : [ EC2 Block Device Mapping, ... ],
  #       "SecurityGroupIds" : [ String, ... ],
  #       "SourceDestCheck" : Boolean,
  #       "SubnetId" : String,
  #       "Tenancy" : String,
  #       "UserData" : String,
  #       "Volumes" : [ EC2 MountPoint, ... ],
  #    }
  # }

  class Instance < Common::Resource

    ##
    # List of valid instance types.
    
    InstanceTypes = %w{
      t1.micro m1.small m1.medium m1.large m1.xlarge 
      m3.medium m3.large m3.xlarge m3.2xlarge m4.large m4.xlarge m4.2xlarge 
      m4.4xlarge m4.10xlarge t2.micro t2.small t2.medium t2.large 
      m2.xlarge m2.2xlarge m2.4xlarge cr1.8xlarge i2.xlarge i2.2xlarge 
      i2.4xlarge i2.8xlarge hi1.4xlarge hs1.8xlarge c1.medium c1.xlarge 
      c3.large c3.xlarge c3.2xlarge c3.4xlarge c3.8xlarge c4.large c4.xlarge 
      c4.2xlarge c4.4xlarge c4.8xlarge cc1.4xlarge cc2.8xlarge g2.2xlarge 
      cg1.4xlarge r3.large r3.xlarge r3.2xlarge r3.4xlarge r3.8xlarge d2.xlarge 
      d2.2xlarge d2.4xlarge d2.8xlarge
    }

    ##
    # List of availability regions.
    
    AvailabilityRegions = %w{
      ap-south-1 eu-west-2 eu-west-1 ap-northeast-2 ap-northeast-1 sa-east-1 ca-central-1
      ap-southeast-1 ap-southeast-2 eu-central-1 us-east-1 us-east-2 us-west-1 us-west-2
    }

    ##
    # List of availability zones.

    AvailabilityZones = %w{
      ap-south-1a ap-south-1b eu-west-2a eu-west-2b eu-west-1a eu-west-1b eu-west-1c 
      ap-northeast-2a ap-northeast-2c ap-northeast-1a ap-northeast-1b ap-northeast-1c 
      sa-east-1a sa-east-1b sa-east-1c ca-central-1a ca-central-1b ap-southeast-1a 
      ap-southeast-1b ap-southeast-2a ap-southeast-2b ap-southeast-2c eu-central-1a 
      eu-central-1b us-east-1a us-east-1b us-east-1c us-east-1d us-east-1e us-east-2a 
      us-east-2b us-east-2c us-west-1a us-west-1c us-west-2a us-west-2b us-west-2c
    }

    Affinity = %w{default host}

    define_keyword(
      :affinity, validation: ->(s) { Utils.one_of?(s, *Affinity) },
      required: false, default: Affinity[0],
      properties: [Common::KeywordProperties::Immutable]
    )

    define_keyword(
      :availability_zone, 
      validation: ->(s) {
        AvailabilityRegions.any? {|r| s[r]} && AvailabilityZones.include?(s)
      },
      properties: [Common::KeywordProperties::Immutable]
    )

    define_keyword(
      :ebs_optimized, validation: Utils.method(:boolean?),
      required: false, default: false,
      properties: [Common::KeywordProperties::Immutable]
    )

    define_keyword(
      :iam_instance_profile, validation: Utils.method(:string_or_ref?),
      properties: [Common::KeywordProperties::Immutable]
    )

    define_keyword(
      :image_id, validation: Utils.method(:string?),
      properties: [Common::KeywordProperties::Immutable]
    )

    ShutdownBehavior = %w{terminate stop}

    define_keyword(
      :shutdown_behavior, 
      validation: ->(s) { Utils.one_of?(s, *ShutdownBehavior) },
      required: false, default: ShutdownBehavior[0],
      properties: [Common::KeywordProperties::Immutable]
    )

    define_keyword(
      :instance_type, validation: ->(s) { InstanceTypes.include?(s) },
      properties: [Common::KeywordProperties::Immutable]
    )

    define_keyword(
      :key_name, validation: Utils.method(:string_or_ref?),
      properties: [Common::KeywordProperties::Immutable]
    )

    define_keyword(
      :monitoring, validation: Utils.method(:boolean?),
      required: false, default: false,
      properties: [Common::KeywordProperties::Mutable]
    )

    define_keyword(
      :source_destination_check, validation: Utils.method(:boolean?),
      required: false, default: true,
      properties: [Common::KeywordProperties::Mutable]
    )

    define_keyword(
      :subnet_id, validation: Utils.method(:string_or_ref?),
      properties: [Common::KeywordProperties::Immutable]
    )

    Tenancy = %w{default dedicated host}

    define_keyword(
      :tenancy, 
      validation: ->(s) { Utils.one_of?(s, *Tenancy) },
      required: false, default: Tenancy[0],
      properties: [Common::KeywordProperties::Immutable]
    )

    define_keyword(
      :userdata, validation: Utils.method(:string?),
      properties: [Common::KeywordProperties::Immutable]
    )

    ##
    # Snapshot attachment.
    
    class SnapshotDevice < Common::Resource

      define_keyword(
        :snapshot,
        validation: Utils.method(:string_or_ref?),
        properties: [Common::KeywordProperties::Immutable]
      )

      def validate!
        super
        unless self[:name] =~ /\/dev\/sd/
          raise StandardError, "Name must be of the form /dev/sd?: #{name}, #{self}."
        end
      end

    end

    ##
    # EBS attachment.
    
    class EbsDevice < Common::Resource

      EbsTypes = %w{gp2 io1 st1 sc1}

      define_keyword(
        :type,
        validation: ->(s) { Utils.one_of?(s, *EbsTypes) },
        required: false,
        default: EbsTypes[0],
        properties: [Common::KeywordProperties::Immutable]
      )

      define_keyword(
        :size,
        validation: Utils.method(:int?),
        properties: [Common::KeywordProperties::Immutable]
      )

      def validate!
        super
        unless self[:name] =~ /\/dev\/sd/
          raise StandardError, "Name must be of the form /dev/sd?: #{name}, #{self}."
        end
      end

    end

    ##
    # Ephemeral instance store attachment.
    
    class EphemeralDevice < Common::Resource
      
      EphemeralNames = (0..10).map {|i| "ephemeral#{i}"}

      define_keyword(
        :virtual_name,
        validation: ->(s) { Utils.one_of?(s, *EphemeralNames) },
        properties: [Common::KeywordProperties::Immutable]
      )

      def validate!
        super
        unless self[:name] =~/\/dev\/sd/
          raise StandardError, "Name must be of the form /dev/sd?: #{name}, #{self}."
        end
      end

    end

    define_collection_keyword(
      :snapshot_device_mapping,
      storage: ->(_) { @snapshot_device_mappings ||= {} },
      context: SnapshotDevice,
      required: false,
      properties: [Common::KeywordProperties::Immutable]
    )

    define_collection_keyword(
      :ebs_device_mapping,
      storage: ->(_) { @ebs_device_mappings ||= {} },
      context: EbsDevice,
      required: false,
      properties: [Common::KeywordProperties::Immutable]
    )

    define_collection_keyword(
      :ephemeral_device_mapping,
      storage: ->(_) { @ephemeral_device_mappings ||= {} },
      context: EphemeralDevice,
      required: false,
      properties: [Common::KeywordProperties::Immutable]
    )

  end

end

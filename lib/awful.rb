require "awful/version"

require 'aws-sdk'
require 'thor'
require 'yaml'

module Awful

  def ec2
    @ec2 ||= Aws::EC2::Client.new
  end

  def autoscaling
    @autoscaling ||= Aws::AutoScaling::Client.new
  end

  def elb
    @elb ||= Aws::ElasticLoadBalancing::Client.new
  end

  def symbolize_keys(thing)
    if thing.is_a?(Hash)
      Hash[ thing.map { |k,v| [ k.to_sym, symbolize_keys(v) ] } ]
    elsif thing.respond_to?(:map)
      thing.map { |v| symbolize_keys(v) }
    else
      thing
    end
  end

  def stringify_keys(thing)
    if thing.is_a?(Hash)
      Hash[ thing.map { |k,v| [ k.to_s, stringify_keys(v) ] } ]
    elsif thing.respond_to?(:map)
      thing.map { |v| stringify_keys(v) }
    else
      thing
    end
  end

  def load_cfg(options = {})
    cfg = $stdin.tty? ? {} : symbolize_keys(YAML.load($stdin.read))
    cfg.merge(symbolize_keys(options.reject{ |_,v| v.nil? }))
  end

  def only_keys_matching(hash, keylist)
    hash.select do |key,_|
      keylist.include?(key)
    end
  end

  def remove_empty_strings(hash)
    hash.reject do |_,value|
      value.respond_to?(:empty?) and value.empty?
    end
  end

  def tag_name(thing)
    tn = thing.tags.find { |tag| tag.key == 'Name' }
    tn && tn.value
  end

  ## return id for instance by name
  def find_instance(name)
    if name .nil?
      nil?
    elsif name.match(/^i-[\d[a-f]]{8}$/)
      name
    else
      ec2.describe_instances.map(&:reservations).flatten.map(&:instances).flatten.find do |instance|
        tag_name(instance) == name
      end.instance_id
    end
  end

  ## return id for subnet by name
  def find_subnet(name)
    if name.match(/^subnet-[\d[a-f]]{8}$/)
      name
    else
      ec2.describe_subnets.map(&:subnets).flatten.find do |subnet|
        tag_name(subnet) == name
      end.subnet_id
    end
  end

end
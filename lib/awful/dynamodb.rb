module Awful

  class DynamoDB < Cli

    desc 'ls [PATTERN]', 'list dynamodb tables [matching PATTERN]'
    method_option :long, aliases: '-l', default: false, desc: 'Long listing'
    def ls(name = /./)
      tables = dynamodb.list_tables.table_names.select do |table|
        table.match(name)
      end

      if options[:long]
        tables.map do |table|
          dynamodb.describe_table(table_name: table).table
        end.tap do |list|
          print_table list.map { |t| [ t.table_name, t.table_status, t.item_count, t.table_size_bytes, t.creation_date_time ] }
        end
      else
        tables.tap { |t| puts t }
      end
    end

    desc 'dump NAME', 'dump table with name'
    def dump(name)
      dynamodb.describe_table(table_name: name).table.tap do |table|
        puts YAML.dump(stringify_keys(table.to_hash))
      end
    end

    desc 'scan NAME', 'scan table with NAME'
    def scan(name, start_key = nil)
      r = dynamodb.scan(table_name: name, exclusive_start_key: start_key) #.items.tap{ |x| p x.count }.tap do |table|
      puts r.items.map { |item| JSON.generate(item) }.join("\n")
      if r.last_evaluated_key # recurse if more data to get
        scan(name, r.last_evaluated_key)
      end
    end

    desc 'create NAME', 'create table with NAME'
    def create(name, file = nil)
      opt = load_cfg(options, file)
      params = only_keys_matching(opt, %i[attribute_definitions key_schema])
      params[:table_name] = name
      params[:provisioned_throughput] = only_keys_matching(opt[:provisioned_throughput], %i[read_capacity_units write_capacity_units])
      params[:local_secondary_indexes] = opt[:local_secondary_indexes].map do |lsi|
        only_keys_matching(lsi, %i[index_name key_schema projection])
      end
      params[:global_secondary_indexes] = opt[:global_secondary_indexes].map do |gsi|
        only_keys_matching(gsi, %i[index_name key_schema projection]).tap do |g|
          if gsi[:provisioned_throughput]
            g[:provisioned_throughput] = only_keys_matching(gsi[:provisioned_throughput], %i[read_capacity_units write_capacity_units])
          end
        end
      end
      dynamodb.create_table(params)
    end

  end

end
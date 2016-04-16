module Awful
  module Short
    def sqs(*args)
      Awful::SQS.new.invoke(*args)
    end
  end

  class SQS < Cli
    no_commands do
      def sqs
        @sqs ||= Aws::SQS::Client.new
      end

      def is_url?(str)
        str =~ /\A#{URI::regexp}\z/
      end
    end

    desc 'ls [PATTERN]', 'list subnets [with any tags matching PATTERN]'
    method_option :long, aliases: '-l', default: false, desc: 'Long listing'
    def ls(prefix = nil)
      queues = sqs.list_queues(queue_name_prefix: prefix).queue_urls
      attr = %w[QueueArn ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible LastModifiedTimestamp]
      if options[:long]
        queues.map do |queue|
          sqs.get_queue_attributes(queue_url: queue, attribute_names: attr).attributes
        end.tap do |list|
          print_table list.map { |q|
            [
              q['QueueArn'].split(':').last,
              q['ApproximateNumberOfMessages'],
              q['ApproximateNumberOfMessagesNotVisible'],
              Time.at(q['LastModifiedTimestamp'].to_i)
            ]
          }
        end
      else
        queues.map { |q| q.split('/').last }.tap(&method(:puts))
      end
    end

    desc 'dump NAME_OR_URL ...', 'get attributes for queues by queue name or url'
    def dump(*names)
      names.map do |name|
        sqs.get_queue_attributes(queue_url: queue_url(name), attribute_names: %w[All]).attributes
      end.tap do |queues|
        queues.each do |queue|
          puts YAML.dump(stringify_keys(queue))
        end
      end
    end

    desc 'send NAME_OR_URL MSG', 'send message to queue'
    def send(name, msg)
      sqs.send_message(queue_url: queue_url(name), message_body: msg)
    end
  end
end